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

(defconst sem-planner-tasks-file "/data/tasks.org"
  "Path to the tasks file.")

(defvar sem-planner--max-retries 3
  "Maximum number of retries for LLM planning call.")

(defvar sem-planner--retry-delays [1 2 4]
  "Delays between retries in seconds.")

(defconst sem-planner-fixed-schedule-exception-title
  "Process quarterly financial reports"
  "Task title that must keep its existing fixed schedule in Pass 2.")

(defun sem-planner--temp-file-path ()
  "Compute the temp file path for the current batch.
Returns /tmp/data/tasks-tmp-{batch-id}.org"
  (format "/tmp/data/tasks-tmp-%d.org" sem-core--batch-id))

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

(defun sem-planner--read-temp-file ()
  "Read the batch temp file and return its contents as a string.
Returns nil if file doesn't exist or is empty."
  (let ((file (sem-planner--temp-file-path)))
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (goto-char (point-min))
        (when (re-search-forward "[^[:space:]]" nil t)
           (goto-char (point-min))
           (string-trim (buffer-string)))))))

(defun sem-planner--format-runtime-iso (time)
  "Format TIME as an ISO 8601 UTC datetime string."
  (format-time-string "%Y-%m-%dT%H:%M:%SZ" time t))

(defun sem-planner--fixed-schedule-task-ids (temp-tasks)
  "Return alist of fixed-schedule IDs and original timestamps from TEMP-TASKS.
Each element is (ID . TIMESTAMP) for tasks matching
`sem-planner-fixed-schedule-exception-title'."
  (if (string-empty-p temp-tasks)
      '()
    (with-temp-buffer
      (insert temp-tasks)
      (let ((fixed '()))
        (goto-char (point-min))
        (while (re-search-forward
                "^\\*+\\s-+TODO\\s-+\\(.+?\\)\\(?:\\s-+:[^\n]+:\\)?\\s-*$"
                nil t)
          (let* ((title (string-trim (match-string 1)))
                 (section-start (point))
                 (section-end (or (save-excursion
                                    (when (re-search-forward "^\\*+\\s-+" nil t)
                                      (match-beginning 0)))
                                  (point-max)))
                 (id nil)
                 (scheduled nil))
            (save-excursion
              (goto-char section-start)
              (when (re-search-forward "^[ \t]*:ID:[ \t]*\\([^ \t\n]+\\)" section-end t)
                (setq id (match-string 1)))
              (goto-char section-start)
              (when (re-search-forward "^[ \t]*SCHEDULED:[ \t]*\\(<[^>]+>\\)" section-end t)
                (setq scheduled (match-string 1))))
            (when (and id
                       scheduled
                       (string= title sem-planner-fixed-schedule-exception-title))
              (push (cons id scheduled) fixed))
            (goto-char section-end)))
        (nreverse fixed)))))

(defun sem-planner--anonymize-temp-tasks (temp-tasks)
  "Anonymize TEMP_TASKS for Pass 2 LLM.
Strips task bodies, returns only ID + TAG + existing SCHEDULED (or unscheduled).
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
                 (title (org-element-property :raw-value headline))
                 (tags (org-element-property :tags headline))
                 (tag-str (if tags (car tags) "routine"))
                 (scheduled (org-element-property :SCHEDULED headline))
                 (sched-str (if scheduled
                                (format "SCHEDULED: %s"
                                         (org-element-interpret-data scheduled))
                              "(unscheduled)"))
                 (fixed-exception
                  (if (string= title sem-planner-fixed-schedule-exception-title)
                      " | FIXED_SCHEDULE_EXCEPTION:true"
                    "")))
            (when id
              (push (format "- ID: %s | TAG:%s | %s%s"
                            id tag-str sched-str fixed-exception)
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
    (with-temp-buffer
      (insert response)
      (goto-char (point-min))
      (while (re-search-forward "ID:\\s-*\\([a-f0-9-]+\\)\\s-*|" nil t)
        (let ((id (match-string 1))
              (scheduled nil))
          (when (re-search-forward "SCHEDULED:\\s-*\\(<[^>]+>\\)" nil t)
            (setq scheduled (match-string 1)))
          (push (cons id scheduled) decisions))))
    (nreverse decisions)))

(defun sem-planner--merge-scheduling-into-tasks (temp-tasks decisions)
  "Merge scheduling DECISIONS into TEMP_TASKS.
DECISIONS is alist of (id . scheduled-timestamp).
For each decision, find matching task by ID and inject SCHEDULED line.
Returns modified temp-tasks string with scheduling injected."
  (when (string-empty-p temp-tasks)
    (cl-return-from sem-planner--merge-scheduling-into-tasks temp-tasks))
  (let ((fixed-schedules (sem-planner--fixed-schedule-task-ids temp-tasks)))
    (with-temp-buffer
      (insert temp-tasks)
      (goto-char (point-min))
      (dolist (decision decisions)
        (let ((id (car decision))
              (scheduled (cdr decision)))
          (when (and scheduled (not (assoc id fixed-schedules)))
            (when (re-search-forward (format "ID:[ \t]*%s[ \t]*\n[ \t]*:END:"
                                            (regexp-quote id))
                                    nil t)
              (goto-char (match-end 0))
              (insert "\nSCHEDULED: " scheduled)))))
      (buffer-string))))

(defun sem-planner--append-merged-to-tasks-org (merged-tasks)
  "Atomically append MERGED-TASKS to tasks.org.
Appends \\n + merged-tasks to existing tasks.org content."
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
          (insert "\n" merged-tasks "\n"))
        (rename-file tmp-file tasks-file t)
        t)
    (error
     (sem-core-log-error "planner" "INBOX-ITEM"
                         (format "Atomic append failed: %s" (error-message-string err))
                         merged-tasks nil)
     nil)))

(defun sem-planner--anonymize-tasks ()
  "Read tasks.org and anonymize tasks to time blocks.
Returns a string with one line per task in format:
YYYY-MM-DD HH:MM-HH:MM busy PRIORITY:{A|B|C} TAG:{tag}
Strips titles and IDs, preserves time+priority+tag."
  (let ((tasks-file sem-planner-tasks-file)
        (anonymized '()))
    (when (file-exists-p tasks-file)
      (with-temp-buffer
        (insert-file-contents tasks-file)
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

(defun sem-planner--build-pass2-prompt
    (anonymized-temp anonymized-schedule rules-text runtime-now runtime-min-start)
  "Build the Pass 2 prompt for task planning.
ANONYMIZED_TEMP is the anonymized temp tasks (ID + TAG + SCHEDULED only).
ANONYMIZED_SCHEDULE is the existing schedule context.
RULES_TEXT is the user scheduling rules.
RUNTIME-NOW is the current run datetime and RUNTIME-MIN-START is RUNTIME-NOW + 1h."
  (let ((output-language (or (getenv "OUTPUT_LANGUAGE") "English")))
    (concat
     "You are a Task Scheduling assistant.\n\n"
     (format "OUTPUT LANGUAGE: Write your entire response in %s.\n\n" output-language)
     "=== RUNTIME SCHEDULING BOUNDS (UTC) ===\n"
     (format "runtime_now: %s\n" runtime-now)
     (format "runtime_min_start: %s\n" runtime-min-start)
     "Rules:\n"
     "- For every task except the fixed-schedule exception, SCHEDULED MUST be strictly greater than runtime_min_start.\n"
     "- Strictly greater means SCHEDULED equal to runtime_min_start is NOT allowed.\n"
     (format "- For task '%s', preserve the exact existing SCHEDULED timestamp unchanged.\n\n"
             sem-planner-fixed-schedule-exception-title)
     "=== USER SCHEDULING RULES ===\n"
     (if (string-empty-p rules-text)
         "(No rules specified)\n"
       (concat rules-text "\n"))
     "\n=== EXISTING SCHEDULE ===\n"
     (if (string-empty-p anonymized-schedule)
         "(No existing tasks)\n"
       (concat anonymized-schedule "\n"))
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

(defun sem-planner--delete-temp-file ()
  "Delete the batch temp file if it exists."
  (let ((file (sem-planner--temp-file-path)))
    (when (file-exists-p file)
      (delete-file file)
      (sem-core-log "planner" "INBOX-ITEM" "OK" (format "Deleted temp file: %s" file) nil))))

(defun sem-planner--fallback-to-pass1 ()
  "Fallback: copy Pass 1 temp file content to tasks.org."
  (condition-case err
      (let ((temp-tasks (sem-planner--read-temp-file)))
        (when temp-tasks
          (sem-core-log "planner" "INBOX-ITEM" "OK" "Fallback: using Pass 1 timing" nil)
          (sem-planner--atomic-tasks-org-update temp-tasks)
          (sem-planner--delete-temp-file)
          t))
    (error
     (sem-core-log-error "planner" "INBOX-ITEM"
                          (format "Fallback failed: %s" (error-message-string err))
                          nil nil)
     nil)))

(defun sem-planner-run-planning-step ()
  "Execute the Pass 2 planning step."
  (condition-case err
      (let ((temp-tasks (sem-planner--read-temp-file)))
        (if (not temp-tasks)
            (progn
              (sem-core-log "planner" "INBOX-ITEM" "OK" "No tasks, skipping planning" nil)
              (message "SEM: No tasks in temp file, skipping planning"))
          (sem-core-log "planner" "INBOX-ITEM" "OK" "Starting planning step" nil)
          (message "SEM: Starting planning step")
          (let* ((anonymized-existing (sem-planner--anonymize-tasks))
                 (anonymized-temp (sem-planner--anonymize-temp-tasks temp-tasks))
                 (rules-text (or (sem-rules-read) ""))
                 (runtime-now-time (current-time))
                 (runtime-min-start-time (time-add runtime-now-time (seconds-to-time 3600)))
                 (runtime-now (sem-planner--format-runtime-iso runtime-now-time))
                 (runtime-min-start (sem-planner--format-runtime-iso runtime-min-start-time)))
            (sem-planner--run-with-retry
             rules-text anonymized-existing anonymized-temp runtime-now runtime-min-start
               (lambda (success response)
                (if success
                    (progn
                      (sem-core-log "planner" "INBOX-ITEM" "OK" "Planning successful" nil)
                      (message "SEM: Planning successful")
                      (when (sem-planner--validate-planned-tasks response)
                        (let* ((decisions (sem-planner--parse-scheduling-decisions response))
                               (merged (sem-planner--merge-scheduling-into-tasks temp-tasks decisions)))
                          (sem-planner--append-merged-to-tasks-org merged)))
                      (sem-planner--delete-temp-file))
                  (progn
                   (sem-core-log-error "planner" "INBOX-ITEM"
                                       "Planning failed after all retries, using fallback"
                                       temp-tasks nil)
                   (message "SEM: Planning failed, using fallback")
                   (sem-planner--fallback-to-pass1)))))))
    (error
     (sem-core-log-error "planner" "INBOX-ITEM"
                         (format "Planning step error: %s" (error-message-string err))
                         nil nil)
     (message "SEM: Planning step error: %s" (error-message-string err))
     (sem-planner--fallback-to-pass1)))))

(defun sem-planner--run-with-retry
    (rules-text anonymized-schedule temp-tasks runtime-now runtime-min-start callback)
  "Run the planning LLM call with exponential backoff retry."
  (let ((retry-count 0)
        (user-prompt
         (sem-planner--build-pass2-prompt
          temp-tasks anonymized-schedule rules-text runtime-now runtime-min-start))
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
                 nil)))
      (attempt))))

(provide 'sem-planner)
;;; sem-planner.el ends here
