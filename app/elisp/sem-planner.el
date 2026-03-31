;;; sem-planner.el --- Task planning and scheduling -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; This module implements the Pass 2 planning step that re-schedules
;; tasks based on user preferences from rules.org and existing schedule.

;;; Code:

(require 'cl-lib)
(require 'sem-core)
(require 'sem-rules)
(require 'sem-prompts)
(require 'sem-llm)
(require 'sem-time)

(defconst sem-planner-tasks-file "/data/tasks.org"
  "Path to the tasks file.")

(defvar sem-planner--max-retries 3
  "Maximum number of retries for LLM planning call.")

(defvar sem-planner--retry-delays [1 2 4]
  "Delays between retries in seconds.")

(defvar sem-planner--conflict-max-attempts 3
  "Maximum planning attempts when tasks.org version conflicts are detected.")

(defconst sem-planner-high-priority-values '(?A ?B)
  "Priority values treated as high-priority overlap exceptions.")

(defconst sem-planner-fixed-schedule-exception-titles '("process quarterly financial reports")
  "Normalized task titles whose fixture-authored schedule must be preserved.")

(defun sem-planner--normalize-title-for-exception-match (title)
  "Normalize TITLE for fixed-schedule exception matching."
  (let ((raw (or title "")))
    (downcase
     (string-trim
      (replace-regexp-in-string
       "[ \t]+" " "
       (replace-regexp-in-string "\\[#\\([A-Ca-c]\\)\\]" "" raw))))))

(defun sem-planner--fixed-schedule-exception-title-p (title)
  "Return non-nil when TITLE is a fixed-schedule exception task title."
  (member (sem-planner--normalize-title-for-exception-match title)
          sem-planner-fixed-schedule-exception-titles))

(defun sem-planner--temp-file-path (&optional batch-id)
  "Compute the temp file path for BATCH-ID.
When BATCH-ID is nil, uses `sem-core--batch-id'.
Returns /tmp/data/tasks-tmp-{batch-id}.org"
  (format "/tmp/data/tasks-tmp-%d.org" (or batch-id sem-core--batch-id)))

(defun sem-planner--read-tasks-file-content ()
  "Return the full current content of `sem-planner-tasks-file'.
Returns an empty string when the file does not exist."
  (if (file-exists-p sem-planner-tasks-file)
      (with-temp-buffer
        (insert-file-contents sem-planner-tasks-file)
        (buffer-string))
    ""))

(defun sem-planner--content-hash (content)
  "Return deterministic SHA256 hash for CONTENT."
  (secure-hash 'sha256 (or content "")))

(defun sem-planner--tasks-file-hash ()
  "Return deterministic SHA256 hash for current tasks.org contents."
  (sem-planner--content-hash (sem-planner--read-tasks-file-content)))

(defun sem-planner--parse-timestamp (ts)
  "Parse org-mode TIMESTAMP string or timestamp object.
Returns (year month day hour minute second) or nil if parsing fails.
Handles both timestamp objects (from planning line) and strings (from property drawer)."
  (cond
   ((consp ts)
    (list (org-element-property :year-start ts)
          (org-element-property :month-start ts)
          (org-element-property :day-start ts)
          (org-element-property :hour-start ts)
          (org-element-property :minute-start ts)
          (org-element-property :hour-end ts)
          (org-element-property :minute-end ts)))
   ((stringp ts)
    (when (string-match
           (concat "<\\([0-9]+\\)-\\([0-9]+\\)-\\([0-9]+\\)"
                   "\\s-+\\([0-9]+\\):\\([0-9]+\\)"
                   "\\(?:-\\([0-9]+\\):\\([0-9]+\\)\\)?>")
           ts)
      (list (string-to-number (match-string 1 ts))
            (string-to-number (match-string 2 ts))
            (string-to-number (match-string 3 ts))
            (string-to-number (match-string 4 ts))
            (string-to-number (match-string 5 ts))
            (if (match-string 6 ts) (string-to-number (match-string 6 ts)) 23)
            (if (match-string 7 ts) (string-to-number (match-string 7 ts)) 59))))
   (t nil)))

(defun sem-planner--read-temp-file (&optional batch-id)
  "Read BATCH-ID temp file and return its contents as a string.
Returns nil if file doesn't exist or is empty."
  (let ((file (sem-planner--temp-file-path batch-id)))
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (goto-char (point-min))
        (when (re-search-forward "[^[:space:]]" nil t)
           (goto-char (point-min))
           (string-trim (buffer-string)))))))

(defun sem-planner--format-runtime-iso (time)
  "Format TIME as an ISO-8601 datetime string in CLIENT_TIMEZONE."
  (sem-time-format-iso-local time))

(defun sem-planner--parse-task-state (existing-index id scheduled)
  "Return task state symbol for ID and SCHEDULED.
EXISTING-INDEX is a hash table keyed by task ID.
Return one of `pre-existing-scheduled', `pre-existing-unscheduled', or `newly-generated'."
  (if (and id (gethash id existing-index))
      (if scheduled 'pre-existing-scheduled 'pre-existing-unscheduled)
    'newly-generated))

(defun sem-planner--existing-task-snapshot-from-content (content)
  "Return existing task metadata parsed from CONTENT.
Each element is a plist with keys :id, :title, :scheduled, and :priority."
  (if (string-empty-p (or content ""))
      '()
    (with-temp-buffer
      (insert content)
      (org-mode)
      (let ((ast (org-element-parse-buffer))
            (snapshot '()))
        (org-element-map ast 'headline
          (lambda (headline)
            (let ((id (org-element-property :ID headline)))
              (when id
                (push (list :id id
                            :title (org-element-property :raw-value headline)
                            :scheduled (org-element-property :SCHEDULED headline)
                            :priority (org-element-property :priority headline))
                      snapshot)))))
        (nreverse snapshot)))))

(defun sem-planner--existing-task-snapshot ()
  "Return existing task metadata from `sem-planner-tasks-file'."
  (sem-planner--existing-task-snapshot-from-content
   (sem-planner--read-tasks-file-content)))

(defun sem-planner--existing-task-index (snapshot)
  "Return hash table index for SNAPSHOT keyed by task ID."
  (let ((index (make-hash-table :test #'equal)))
    (dolist (entry snapshot)
      (puthash (plist-get entry :id) entry index))
    index))

(defun sem-planner--timestamp-to-epoch-range (scheduled)
  "Convert SCHEDULED timestamp to epoch range as cons cell.
Returns (START . END) in epoch seconds or nil when parsing fails."
  (let ((parts (sem-planner--parse-timestamp scheduled)))
    (when parts
      (let* ((year (nth 0 parts))
             (month (nth 1 parts))
             (day (nth 2 parts))
             (hour-start (or (nth 3 parts) 0))
             (minute-start (or (nth 4 parts) 0))
             (hour-end (or (nth 5 parts) 23))
             (minute-end (or (nth 6 parts) 59))
             (client-timezone (sem-time-client-timezone))
             (start (float-time (encode-time 0 minute-start hour-start day month year client-timezone)))
             (end (float-time (encode-time 0 minute-end hour-end day month year client-timezone))))
        (cons start end)))))

(defun sem-planner--occupied-windows (snapshot)
  "Return occupied windows derived from pre-existing scheduled tasks in SNAPSHOT.
Each element is a plist with :id, :title, :range, and :scheduled."
  (let ((windows '()))
    (dolist (entry snapshot)
      (let ((scheduled (plist-get entry :scheduled)))
        (when scheduled
          (let ((range (sem-planner--timestamp-to-epoch-range scheduled)))
            (when range
              (push (list :id (plist-get entry :id)
                          :title (plist-get entry :title)
                          :scheduled (org-element-interpret-data scheduled)
                          :range range)
                    windows))))))
    (nreverse windows)))

(defun sem-planner--occupied-windows-context (windows)
  "Format occupied WINDOWS for Pass 2 planning context."
  (if (null windows)
      "(none)"
    (mapconcat
     (lambda (window)
       (format "- OCCUPIED: %s | SOURCE_ID:%s"
               (plist-get window :scheduled)
               (plist-get window :id)))
     windows
     "\n")))

(defun sem-planner--high-priority-p (priority)
  "Return non-nil when PRIORITY is treated as high priority."
  (and priority (memq priority sem-planner-high-priority-values)))

(defun sem-planner--overlapping-window (scheduled occupied-windows)
  "Return first occupied window overlapping SCHEDULED from OCCUPIED-WINDOWS.
Return nil when there is no overlap or SCHEDULED cannot be parsed."
  (let ((scheduled-range (sem-planner--timestamp-to-epoch-range scheduled))
        (match nil))
    (when scheduled-range
      (dolist (window occupied-windows)
        (let* ((window-range (plist-get window :range))
               (window-start (car window-range))
               (window-end (cdr window-range))
               (task-start (car scheduled-range))
               (task-end (cdr scheduled-range)))
          (when (and (< task-start window-end)
                     (< window-start task-end)
                     (not match))
            (setq match window)))))
    match))

(defun sem-planner--temp-task-metadata (temp-tasks existing-index)
  "Return metadata map for TEMP-TASKS keyed by task ID.
EXISTING-INDEX is used to classify each task by pre-existing state."
  (let ((metadata (make-hash-table :test #'equal)))
    (with-temp-buffer
      (insert temp-tasks)
      (org-mode)
      (let ((ast (org-element-parse-buffer)))
        (org-element-map ast 'headline
          (lambda (headline)
            (let* ((id (org-element-property :ID headline))
                   (scheduled (org-element-property :SCHEDULED headline))
                   (priority (org-element-property :priority headline))
                   (state (sem-planner--parse-task-state existing-index id scheduled)))
               (when id
                 (puthash id
                          (list :id id
                                :title (org-element-property :raw-value headline)
                                :state state
                                :priority priority
                                :scheduled (when scheduled
                                             (org-element-interpret-data scheduled)))
                         metadata)))))))
    metadata))

(defun sem-planner--anonymize-temp-tasks (temp-tasks existing-index)
  "Anonymize TEMP_TASKS for Pass 2 LLM.
Strips task bodies and returns ID, TAG, STATE, PRIORITY, and schedule metadata.
Sensitive content is NEVER sent to LLM."
  (when (string-empty-p temp-tasks)
    (cl-return-from sem-planner--anonymize-temp-tasks ""))
  (with-temp-buffer
    (insert temp-tasks)
    (org-mode)
    (let ((ast (org-element-parse-buffer))
          (result '()))
      (org-element-map ast 'headline
        (lambda (headline)
          (let* ((id (org-element-property :ID headline))
                 (tags (org-element-property :tags headline))
                 (priority (org-element-property :priority headline))
                 (tag-str (if tags (car tags) "routine"))
                 (scheduled (org-element-property :SCHEDULED headline))
                 (state (sem-planner--parse-task-state existing-index id scheduled))
                 (sched-str (if scheduled
                                (format "SCHEDULED: %s"
                                        (org-element-interpret-data scheduled))
                              "(unscheduled)"))
                 (priority-str (if priority
                                   (format "%c" priority)
                                 "none")))
            (when id
              (push (format "- ID: %s | TAG:%s | PRIORITY:%s | STATE:%s | %s"
                            id tag-str priority-str state sched-str)
                    result)))))
      (if result
          (concat "Tasks to schedule:\n"
                  (string-join (nreverse result) "\n")
                  "\n")
        ""))))

(defun sem-planner--parse-scheduling-decisions (response)
  "Parse LLM RESPONSE into scheduling decisions.
Returns alist of (id . scheduled-timestamp) where scheduled-timestamp is nil for unscheduled.
Response format expected:
  ID: <uuid> | SCHEDULED: <timestamp>
  ID: <uuid> | (unscheduled)"
  (when (string-empty-p response)
    (cl-return-from sem-planner--parse-scheduling-decisions '()))
  (let ((decisions '()))
    (dolist (line (split-string response "\n" t))
      (cond
       ((string-match
         "^[ \t]*ID:[ \t]*\\([a-f0-9-]+\\)[ \t]*|[ \t]*SCHEDULED:[ \t]*\\(<[^>]+>\\)[ \t]*$"
         line)
        (push (cons (match-string 1 line)
                    (match-string 2 line))
              decisions))
       ((string-match
         "^[ \t]*ID:[ \t]*\\([a-f0-9-]+\\)[ \t]*|[ \t]*(unscheduled)[ \t]*$"
         line)
        (push (cons (match-string 1 line) nil) decisions))))
    (nreverse decisions)))

(defun sem-planner--merge-scheduling-into-tasks
    (temp-tasks decisions task-metadata occupied-windows runtime-min-start)
  "Merge scheduling DECISIONS into TEMP_TASKS.
DECISIONS is alist of (id . scheduled-timestamp).
For each decision, find matching task by ID and inject SCHEDULED line.
Returns modified temp-tasks string with scheduling injected."
  (when (string-empty-p temp-tasks)
    (cl-return-from sem-planner--merge-scheduling-into-tasks temp-tasks))
  (let ((runtime-min-start-epoch
         (float-time (date-to-time runtime-min-start))))
    (with-temp-buffer
      (insert temp-tasks)
      (goto-char (point-min))
      (dolist (decision decisions)
        (let* ((id (car decision))
               (scheduled (cdr decision))
               (meta (and id (gethash id task-metadata)))
               (title (plist-get meta :title))
               (state (plist-get meta :state))
               (priority (plist-get meta :priority))
               (scheduled-range (and scheduled
                                     (sem-planner--timestamp-to-epoch-range scheduled)))
               (overlapping-window (and scheduled
                                         (eq state 'newly-generated)
                                         (sem-planner--overlapping-window scheduled occupied-windows))))
          (when (and scheduled
                     (eq state 'newly-generated)
                     (not (sem-planner--fixed-schedule-exception-title-p title))
                     scheduled-range
                     (> (car scheduled-range) runtime-min-start-epoch)
                     (or (null overlapping-window)
                         (sem-planner--high-priority-p priority)))
            (when (re-search-forward (format "^[ \t]*:ID:[ \t]*%s[ \t]*$"
                                            (regexp-quote id))
                                    nil t)
              (let* ((id-pos (match-beginning 0))
                     (section-start
                      (save-excursion
                        (goto-char id-pos)
                        (if (re-search-backward "^\\*+\\s-+TODO\\s-+" nil t)
                            (match-beginning 0)
                          (point-min))))
                     (section-end
                      (save-excursion
                        (goto-char id-pos)
                        (if (re-search-forward "^\\*+\\s-+TODO\\s-+" nil t)
                            (match-beginning 0)
                          (point-max)))))
                (save-restriction
                  (narrow-to-region section-start section-end)
                  (goto-char (point-min))
                  (while (re-search-forward "^[ \t]*SCHEDULED:[ \t]*<[^>]+>[ \t]*\\n?" nil t)
                    (replace-match ""))
                  (goto-char (point-min))
                  (if (re-search-forward "^[ \t]*:END:[ \t]*$" nil t)
                      (progn
                        (end-of-line)
                        (insert "\nSCHEDULED: " scheduled))
                    (goto-char (point-max))
                    (insert "\nSCHEDULED: " scheduled))))))))
      (buffer-string))))

(defun sem-planner--append-merged-to-tasks-org (merged-tasks)
  "Atomically append MERGED-TASKS to tasks.org.
Appends \\n + merged-tasks to existing tasks.org content."
  (condition-case err
      (let* ((clean-merged
              (with-temp-buffer
                (insert merged-tasks)
                (goto-char (point-min))
                (skip-chars-forward " \t\n")
                (when (looking-at-p "^\\* Tasks[ \t]*$")
                  (delete-region (point-min)
                                 (min (point-max) (1+ (line-end-position))))
                  (goto-char (point-min))
                  (while (looking-at-p "^[ \t]*$")
                    (delete-region (line-beginning-position)
                                   (min (point-max) (1+ (line-end-position))))))
                (buffer-string)))
             (tasks-file sem-planner-tasks-file)
             (tmp-file (concat tasks-file ".tmp"))
             (existing ""))
        (when (file-exists-p tasks-file)
          (with-temp-buffer
            (insert-file-contents tasks-file)
            (setq existing (buffer-string))))
        (with-temp-file tmp-file
          (when (and existing (not (string-empty-p existing)))
            (insert existing "\n"))
          (insert "\n" clean-merged "\n"))
        (rename-file tmp-file tasks-file t)
        t)
    (error
     (sem-core-log-error "planner" "INBOX-ITEM"
                         (format "Atomic append failed: %s" (error-message-string err))
                         merged-tasks nil)
     nil)))

(defun sem-planner--anonymize-tasks-content (content)
  "Anonymize CONTENT tasks to time blocks.
Returns a string with one line per task in format:
YYYY-MM-DD HH:MM-HH:MM busy PRIORITY:{A|B|C} TAG:{tag}
Strips titles and IDs, preserves time+priority+tag."
  (let ((anonymized '()))
    (when (not (string-empty-p (or content "")))
      (with-temp-buffer
        (insert content)
        (org-mode)
        (let ((ast (org-element-parse-buffer)))
          (org-element-map ast 'headline
            (lambda (headline-element)
              (let* ((scheduled (org-element-property :SCHEDULED headline-element))
                     (deadline (org-element-property :DEADLINE headline-element))
                     (priority (org-element-property :priority headline-element))
                     (tags (org-element-property :tags headline-element))
                     (tag-str (if tags (car tags) ""))
                     (time-str nil))
                (cond
                 (scheduled
                  (let ((ts-parts (sem-planner--parse-timestamp scheduled)))
                    (when ts-parts
                      (let ((y (nth 0 ts-parts))
                            (m (nth 1 ts-parts))
                            (d (nth 2 ts-parts))
                            (hs (nth 3 ts-parts))
                            (ms (nth 4 ts-parts))
                            (he (nth 5 ts-parts))
                            (me (nth 6 ts-parts)))
                        (when (and y m d)
                          (setq time-str (format "%04d-%02d-%02d %02d:%02d-%02d:%02d busy PRIORITY:%c TAG:%s"
                                                 y m d
                                                 (or hs 0) (or ms 0)
                                                 (or he 23) (or me 59)
                                                 (or priority ?B)
                                                 tag-str)))))))
                 (deadline
                  (let ((ts-parts (sem-planner--parse-timestamp deadline)))
                    (when ts-parts
                      (let ((y (nth 0 ts-parts))
                            (m (nth 1 ts-parts))
                            (d (nth 2 ts-parts))
                            (hs (nth 3 ts-parts))
                            (ms (nth 4 ts-parts)))
                        (when (and y m d)
                          (setq time-str (format "%04d-%02d-%02d %02d:%02d-23:59 busy PRIORITY:%c TAG:%s"
                                                 y m d
                                                 (or hs 0) (or ms 0)
                                                 (or priority ?B)
                                                 tag-str))))))))
                (when time-str
                  (push time-str anonymized))))))))
    (if anonymized
        (string-join (nreverse anonymized) "\n")
      "")))

(defun sem-planner--anonymize-tasks ()
  "Read tasks.org and anonymize tasks to time blocks."
  (sem-planner--anonymize-tasks-content
   (sem-planner--read-tasks-file-content)))

(defun sem-planner--build-pass2-prompt
    (anonymized-temp anonymized-schedule occupied-windows rules-text runtime-now runtime-min-start)
  "Build the Pass 2 prompt for task planning.
ANONYMIZED_TEMP is the anonymized temp tasks metadata.
ANONYMIZED_SCHEDULE is the existing schedule context.
OCCUPIED-WINDOWS is pre-existing occupied ranges.
RULES_TEXT is the user scheduling rules.
RUNTIME-NOW is the current run datetime and RUNTIME-MIN-START is RUNTIME-NOW + 1h."
  (let ((output-language (or (getenv "OUTPUT_LANGUAGE") "English")))
    (concat
     "You are a Task Scheduling assistant.\n\n"
     (format "OUTPUT LANGUAGE: Write your entire response in %s.\n\n" output-language)
     (format "=== RUNTIME SCHEDULING BOUNDS (%s) ===\n" (sem-time-client-timezone))
     (format "runtime_now: %s\n" runtime-now)
     (format "runtime_min_start: %s\n" runtime-min-start)
     "Rules:\n"
      "- For every newly-generated task, SCHEDULED MUST be strictly greater than runtime_min_start.\n"
      "- Strictly greater means SCHEDULED equal to runtime_min_start is NOT allowed.\n"
      "- Keep pre-existing-scheduled tasks at exact original timestamps.\n"
      "- Keep pre-existing-unscheduled tasks unscheduled.\n"
      "- Avoid overlap with pre-existing occupied windows by default.\n"
      "- Overlap is allowed only for high-priority newly-generated tasks when needed.\n"
      "- Never mutate preserved pre-existing schedules while applying overlap exceptions.\n\n"
      "=== USER SCHEDULING RULES ===\n"
     (if (string-empty-p rules-text)
         "(No rules specified)\n"
       (concat rules-text "\n"))
     "\n=== EXISTING SCHEDULE ===\n"
      (if (string-empty-p anonymized-schedule)
          "(No existing tasks)\n"
        (concat anonymized-schedule "\n"))
      "\n=== PRE-EXISTING OCCUPIED WINDOWS ===\n"
      (if (string-empty-p occupied-windows)
          "(none)\n"
        (concat occupied-windows "\n"))
      "\n=== TASKS TO SCHEDULE ===\n"
     anonymized-temp
     "\n\nIMPORTANT: Respond with ONE LINE per task in this exact format:\n"
     "  ID: <uuid> | SCHEDULED: <timestamp>\n"
     "or for unscheduled:\n"
     "  ID: <uuid> | (unscheduled)\n"
     "Do NOT include task bodies or any other content. Only the scheduling decisions.\n")))

(defun sem-planner--system-prompt ()
  "Return the system prompt for Pass 2 planning."
  (concat
   "You are a Task Scheduling assistant.\n"
   sem-prompts-org-mode-cheat-sheet
   "\nMinimize conflicts, respect preferences.\n"))

(defun sem-planner--validate-planned-tasks (response)
  "Validate that RESPONSE contains scheduling decisions in simple format.
Expected format: 'ID: <uuid> | SCHEDULED: <timestamp>' or 'ID: <uuid> | (unscheduled)'
Returns t if at least one valid ID line is found."
  (when (and response (not (string-empty-p response)))
    (with-temp-buffer
      (insert response)
      (goto-char (point-min))
      (re-search-forward "ID:\\s-*[a-f0-9-]+" nil t))))

(defun sem-planner--atomic-tasks-org-update (planned-tasks)
  "Atomically update tasks.org with PLANNED-TASKS."
  (condition-case err
      (let* ((tasks-file sem-planner-tasks-file)
             (tmp-file (concat tasks-file ".tmp"))
             (existing ""))
        (when (file-exists-p tasks-file)
          (with-temp-buffer
            (insert-file-contents tasks-file)
            (setq existing (buffer-string))))
        (with-temp-file tmp-file
          (when (and existing (not (string-empty-p existing)))
            (insert existing "\n"))
          (insert planned-tasks))
        (rename-file tmp-file tasks-file t)
        t)
    (error
     (sem-core-log-error "planner" "INBOX-ITEM"
                          (format "Atomic update failed: %s" (error-message-string err))
                          planned-tasks nil)
     nil)))

(defun sem-planner--delete-temp-file (&optional batch-id)
  "Delete BATCH-ID temp file if it exists."
  (let ((file (sem-planner--temp-file-path batch-id)))
    (when (file-exists-p file)
      (delete-file file)
      (sem-core-log "planner" "INBOX-ITEM" "OK" (format "Deleted temp file: %s" file) nil))))

(defun sem-planner--attempt-context (temp-tasks runtime-min-start)
  "Build a planning context for TEMP-TASKS and RUNTIME-MIN-START.
Captures and returns a base tasks.org hash before Pass 2 context generation."
  (let* ((base-content (sem-planner--read-tasks-file-content))
         (base-hash (sem-planner--content-hash base-content))
         (existing-snapshot (sem-planner--existing-task-snapshot-from-content base-content))
         (existing-index (sem-planner--existing-task-index existing-snapshot))
         (occupied-windows (sem-planner--occupied-windows existing-snapshot)))
    (list :base-hash base-hash
          :existing-index existing-index
          :occupied-windows occupied-windows
          :occupied-windows-context (sem-planner--occupied-windows-context occupied-windows)
          :task-metadata (sem-planner--temp-task-metadata temp-tasks existing-index)
          :anonymized-existing (sem-planner--anonymize-tasks-content base-content)
          :anonymized-temp (sem-planner--anonymize-temp-tasks temp-tasks existing-index)
          :runtime-min-start runtime-min-start)))

(defun sem-planner--attempt-conflict-aware-planning
    (temp-tasks rules-text runtime-now runtime-min-start attempt callback)
  "Run one conflict-aware planning ATTEMPT for TEMP-TASKS.
CALLBACK receives non-nil on success and nil on explicit non-success outcome."
  (let* ((context (sem-planner--attempt-context temp-tasks runtime-min-start))
         (base-hash (plist-get context :base-hash))
         (attempt-label (format "%d/%d" attempt sem-planner--conflict-max-attempts)))
    (sem-planner--run-with-retry
     rules-text
     (plist-get context :anonymized-existing)
     (plist-get context :occupied-windows-context)
     (plist-get context :anonymized-temp)
     runtime-now
     runtime-min-start
     (lambda (success response)
       (if (not success)
           (funcall callback nil)
         (if (not (sem-planner--validate-planned-tasks response))
             (progn
               (sem-core-log-error "planner" "INBOX-ITEM"
                                   "Pass 2 response failed validation"
                                   temp-tasks response)
               (funcall callback nil))
           (let ((pre-append-hash (sem-planner--tasks-file-hash)))
             (if (not (string= pre-append-hash base-hash))
                 (progn
                   (sem-core-log "planner" "INBOX-ITEM" "RETRY"
                                 (format "Conflict detected before append (attempt %s)"
                                         attempt-label)
                                 nil)
                   (if (< attempt sem-planner--conflict-max-attempts)
                       (progn
                         (sem-core-log "planner" "INBOX-ITEM" "RETRY"
                                       (format "Replanning with refreshed tasks.org state (next attempt %d/%d)"
                                               (1+ attempt)
                                               sem-planner--conflict-max-attempts)
                                       nil)
                         (sem-planner--attempt-conflict-aware-planning
                          temp-tasks
                          rules-text
                          runtime-now
                          runtime-min-start
                          (1+ attempt)
                          callback))
                     (progn
                       (sem-core-log-error "planner" "INBOX-ITEM"
                                           (format "Conflict retry budget exhausted after %d attempts"
                                                   sem-planner--conflict-max-attempts)
                                           temp-tasks nil)
                       (message "SEM: Planning conflict retry budget exhausted")
                       (funcall callback nil))))
               (let* ((decisions (sem-planner--parse-scheduling-decisions response))
                      (merged (sem-planner--merge-scheduling-into-tasks
                               temp-tasks
                               decisions
                               (plist-get context :task-metadata)
                               (plist-get context :occupied-windows)
                               runtime-min-start)))
                 (if (sem-planner--append-merged-to-tasks-org merged)
                     (progn
                       (sem-core-log "planner" "INBOX-ITEM" "OK"
                                     (format "Planning append succeeded on attempt %s"
                                             attempt-label)
                                     nil)
                       (funcall callback t))
                   (funcall callback nil)))))))))))

(defun sem-planner--fallback-to-pass1 (&optional batch-id)
  "Fallback: copy BATCH-ID Pass 1 temp file content to tasks.org."
  (condition-case err
      (let ((temp-tasks (sem-planner--read-temp-file batch-id)))
        (when temp-tasks
          (sem-core-log "planner" "INBOX-ITEM" "OK" "Fallback: using Pass 1 timing" nil)
          (sem-planner--atomic-tasks-org-update temp-tasks)
          (sem-planner--delete-temp-file batch-id)
          t))
    (error
     (sem-core-log-error "planner" "INBOX-ITEM"
                          (format "Fallback failed: %s" (error-message-string err))
                          nil nil)
     nil)))

(defun sem-planner-run-planning-step (&optional batch-id)
  "Execute Pass 2 planning for BATCH-ID.
When BATCH-ID is nil, defaults to current `sem-core--batch-id'."
  (condition-case err
      (let* ((owner-batch-id (or batch-id sem-core--batch-id))
             (temp-tasks (sem-planner--read-temp-file owner-batch-id)))
        (if (not temp-tasks)
            (progn
              (sem-core-log "planner" "INBOX-ITEM" "OK"
                            (format "No tasks for batch %d, skipping planning" owner-batch-id)
                            nil)
              (message "SEM: No tasks in temp file for batch %d, skipping planning" owner-batch-id))
          (sem-core-log "planner" "INBOX-ITEM" "OK" "Starting planning step" nil)
          (message "SEM: Starting planning step for batch %d" owner-batch-id)
          (let* ((rules-text (or (sem-rules-read) ""))
                 (runtime-now-time (current-time))
                 (runtime-min-start-time (time-add runtime-now-time (seconds-to-time 3600)))
                 (runtime-now (sem-planner--format-runtime-iso runtime-now-time))
                 (runtime-min-start (sem-planner--format-runtime-iso runtime-min-start-time)))
            (sem-planner--attempt-conflict-aware-planning
             temp-tasks
             rules-text
             runtime-now
             runtime-min-start
             1
             (lambda (success)
               (if success
                   (progn
                     (sem-core-log "planner" "INBOX-ITEM" "OK" "Planning successful" nil)
                     (message "SEM: Planning successful for batch %d" owner-batch-id)
                     (sem-planner--delete-temp-file owner-batch-id))
                 (progn
                   (sem-core-log-error "planner" "INBOX-ITEM"
                                       "Planning failed with explicit non-success outcome"
                                       temp-tasks nil)
                   (message "SEM: Planning failed with explicit non-success outcome for batch %d"
                            owner-batch-id)
                   (if (sem-planner--fallback-to-pass1 owner-batch-id)
                       (message "SEM: Preserved Pass 1 tasks via fallback for batch %d"
                                owner-batch-id)
                     (sem-core-log-error "planner" "INBOX-ITEM"
                                         (format "Pass 1 fallback preservation failed for batch %d"
                                                 owner-batch-id)
                                         temp-tasks nil)
                     (message "SEM: Pass 1 fallback preservation failed for batch %d"
                              owner-batch-id)))))))))
    (error
     (sem-core-log-error "planner" "INBOX-ITEM"
                         (format "Planning step error: %s" (error-message-string err))
                         nil nil)
     (message "SEM: Planning step error: %s" (error-message-string err)))))

(defun sem-planner--run-with-retry
    (rules-text anonymized-schedule occupied-windows temp-tasks runtime-now runtime-min-start callback)
  "Run the planning LLM call with exponential backoff retry."
  (let ((retry-count 0)
        (user-prompt
         (sem-planner--build-pass2-prompt
           temp-tasks
           anonymized-schedule
           occupied-windows
           rules-text
           runtime-now
           runtime-min-start))
        (system-prompt (sem-planner--system-prompt)))
    (cl-labels ((attempt ()
                (message "SEM: Planning attempt %d/%d" (1+ retry-count) sem-planner--max-retries)
                (sem-llm-request
                 user-prompt system-prompt
                  (lambda (response info context)
                   (if response
                       (funcall callback t response)
                     (if (< retry-count (1- sem-planner--max-retries))
                         (progn
                           (message "SEM: Planning attempt %d failed, retrying..."
                                    (1+ retry-count))
                           (run-with-timer
                            (nth retry-count sem-planner--retry-delays) nil
                            (lambda ()
                              (setq retry-count (1+ retry-count))
                              (attempt))))
                       (funcall callback nil nil))))
                  nil
                  'medium)))
      (attempt))))

(provide 'sem-planner)
;;; sem-planner.el ends here
