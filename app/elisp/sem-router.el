;;; sem-router.el --- Inbox routing and cursor tracking -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; This module parses headlines from inbox-mobile.org and routes them
;; to the appropriate handler (url-capture or LLM task generation).
;; It also manages cursor tracking via content hashes.

;;; Code:

(require 'org)
(require 'sem-core)
(require 'sem-prompts)

;;; Constants

(defconst sem-router-inbox-file "/data/inbox-mobile.org"
  "Path to the inbox file to process.")

(defconst sem-router-tasks-file "/data/tasks.org"
  "Path to the tasks file where processed @task headlines are written.")

(defconst sem-router-task-tags '("work" "family" "routine" "opensource")
  "Allowed tags for task headlines. Must be one of these values.")

;;; Mutex for tasks.org writes

(defvar sem-router--tasks-write-lock nil
  "Boolean flag to serialize concurrent writes to tasks.org.
When non-nil, another callback is currently writing to tasks.org.
Each callback must acquire this lock before writing and release after.
Lock is never held across retries - each attempt acquires/releases independently.")

(defvar sem-router--max-write-retries 10
  "Maximum number of retry attempts for tasks.org write lock.")

(defvar sem-router--write-retry-delay 0.5
  "Delay in seconds between retries for tasks.org write lock.")

(defun sem-router--acquire-tasks-write-lock ()
  "Attempt to acquire the tasks.org write lock.
Returns t if lock acquired, nil if already held."
  (if sem-router--tasks-write-lock
      nil
    (setq sem-router--tasks-write-lock t)
    t))

(defun sem-router--release-tasks-write-lock ()
  "Release the tasks.org write lock.
Always sets the lock to nil."
  (setq sem-router--tasks-write-lock nil))

(defun sem-router--with-tasks-write-lock (headline callback retry-count &optional dlq-callback batch-id)
  "Execute CALLBACK with tasks.org write lock held.
If lock is held, re-schedules with 0.5s delay up to 10 retries.
After 10 retries, routes to DLQ via sem-core-log-error.
HEADLINE is the headline plist for error logging.
RETRY-COUNT is the current retry attempt number.
DLQ-CALLBACK is an optional function called when lock contention hits DLQ.
BATCH-ID is the dispatch batch id used for stale-safe retries."
  (if (sem-router--acquire-tasks-write-lock)
      ;; Lock acquired - execute callback with unwind-protect
      (unwind-protect
          (funcall callback)
        (sem-router--release-tasks-write-lock))
    ;; Lock held - retry or DLQ
    (if (>= retry-count sem-router--max-write-retries)
        ;; Max retries reached - route to DLQ
        (progn
          (sem-core-log-error "router" "INBOX-ITEM"
                              (format "Tasks.org write failed after %d retries (lock contention)"
                                      sem-router--max-write-retries)
                              (plist-get headline :title)
                              nil)
          ;; Mark as processed to prevent infinite retry
          (sem-router--mark-processed (plist-get headline :hash))
          (when dlq-callback
            (funcall dlq-callback)))
      ;; Schedule retry
      (run-with-timer sem-router--write-retry-delay nil
                      (lambda ()
                        (sem-router--with-tasks-write-lock
                         headline callback (1+ retry-count) dlq-callback batch-id))))))

;;; Headline Parsing

(defun sem-router--extract-headline-body (headline-element)
  "Extract body text from HEADLINE-ELEMENT.
Returns the concatenated text of all non-headline child elements,
or nil if no body content exists. Nested sub-headlines are excluded."
  (let ((contents-begin (org-element-property :contents-begin headline-element))
        (contents-end (org-element-property :contents-end headline-element))
        (body-text nil))
    (when (and contents-begin contents-end (> contents-end contents-begin))
      ;; Extract text between contents-begin and contents-end
      ;; but stop at any nested headline
      (setq body-text
            (save-excursion
              (save-restriction
                (narrow-to-region contents-begin contents-end)
                (goto-char (point-min))
                ;; Skip any nested headlines at the start
                (while (and (not (eobp)) (looking-at "^\\*+"))
                  (forward-line 1))
                ;; If we're not at end, extract the body
                (if (eobp)
                    nil
                  (let ((start (point))
                        (end (point-max)))
                    ;; Find where nested headline starts (if any)
                    (when (re-search-forward "^\\*+" nil t)
                      (setq end (match-beginning 0)))
                    (string-trim (buffer-substring-no-properties start end))))))))
    (if (and body-text (not (string-empty-p body-text)))
        body-text
      nil)))

(defun sem-router--parse-headlines ()
  "Parse all headlines from inbox-mobile.org using org-element.
Returns a list of headline plists with :title, :tags, :body, :link, :point, :hash."
  (cl-block sem-router--parse-headlines
    (unless (file-exists-p sem-router-inbox-file)
      (message "SEM: sem-router--parse-headlines: file does not exist: %s" sem-router-inbox-file)
      (sem-core-log "router" "INBOX-ITEM" "SKIP" "inbox-mobile.org does not exist")
      (cl-return-from sem-router--parse-headlines nil))

    (message "SEM: sem-router--parse-headlines: parsing %s" sem-router-inbox-file)
    (let ((headlines '()))
      (with-temp-buffer
        (insert-file-contents sem-router-inbox-file)
        (message "SEM: sem-router--parse-headlines: buffer has %d chars, first 100: %s"
                 (point-max)
                 (buffer-substring-no-properties
                  (point-min)
                  (min (point-max) (+ (point-min) 100))))
        (org-mode)
        (let ((ast (org-element-parse-buffer)))
          (message "SEM: sem-router--parse-headlines: AST root type: %s" (org-element-type ast))
          (org-element-map ast 'headline
            (lambda (headline-element)
              (let* ((begin (org-element-property :begin headline-element))
                     (title (org-element-property :raw-value headline-element))
                     (tags (org-element-property :tags headline-element))
                     (body (sem-router--extract-headline-body headline-element))
                     (link (when (string-match-p "^https?://" title)
                             (substring-no-properties title)))
                     (tags-str (if tags (string-join tags " ") ""))
                     (body-str (or body ""))
                     (hash (secure-hash 'sha256
                                        (concat title "|" tags-str "|" body-str))))
                (message "SEM:   parsed headline: %s | tags: %s | hash: %.8s..." title tags-str hash)
                (push (list :title title
                            :tags tags
                            :body body
                            :link link
                            :point begin
                            :hash hash)
                      headlines))))))

      (message "SEM: sem-router--parse-headlines: found %d headlines" (length headlines))
      (nreverse headlines))))

;;; Tag Detection

(defun sem-router--is-link-headline (headline)
  "Check if HEADLINE is a link headline (has @link tag or URL as title).
Returns the URL if it's a link headline, nil otherwise."
  (let ((tags (plist-get headline :tags))
        (link (plist-get headline :link))
        (title (plist-get headline :title)))
    (cond
     ;; Check for @link tag - return link if available, otherwise check title
     ((member "link" tags)
      (or link (when (string-match-p "^https?://" title) title)))
     ;; Check if title is a URL (no @link tag needed)
     ((string-match-p "^https?://" title) title)
     (t nil))))

(defun sem-router--is-task-headline (headline)
  "Check if HEADLINE is a task headline (has @task tag).
Returns non-nil if it's a task headline."
  (member "task" (plist-get headline :tags)))

;;; Cursor Tracking

(defun sem-router--is-processed (hash)
  "Check if a headline with HASH is already processed."
  (sem-core--is-processed hash))

(defun sem-router--mark-processed (hash)
  "Mark a headline with HASH as processed."
  (sem-core--mark-processed hash))

;;; Routing Logic

(defun sem-router--route-to-url-capture (url headline)
  "Route a link headline to URL capture pipeline.

URL is the link to capture.
HEADLINE is the headline plist.

Returns the saved filepath on success, nil on failure."
  (require 'sem-url-capture)
  (condition-case err
      (let ((result (sem-url-capture-process url)))
        (if result
            (sem-core-log "router" "URL-CAPTURE" "OK"
                          (format "URL captured: %s -> %s" url result)
                          nil)
          (sem-core-log "router" "URL-CAPTURE" "FAIL"
                        (format "URL capture failed: %s" url)
                        nil))
        result)
    (error
     (sem-core-log-error "router" "URL-CAPTURE"
                         (error-message-string err)
                         url
                         nil)
     nil)))

(defun sem-router--build-task-llm-prompts (title tags sanitized-body injected-id)
  "Build Pass 1 USER and SYSTEM prompts for task normalization.

TITLE is the headline title string.
TAGS is the headline tag list.
SANITIZED-BODY is optional task body text after security masking.
INJECTED-ID is the pre-generated UUID string to embed verbatim.

Returns a plist with keys :user-prompt and :system-prompt."
  (let* ((output-language (or (getenv "OUTPUT_LANGUAGE") "English"))
         (current-datetime (format-time-string "%Y-%m-%dT%H:%M:%SZ" (current-time) t))
         (language-instruction (format "\n\nOUTPUT LANGUAGE: Write your entire response in %s. Do not use any other language."
                                       output-language))
         (rules-text (if (fboundp 'sem-rules-read)
                         (or (sem-rules-read) "")
                       ""))
         (rules-section (if (string-empty-p rules-text)
                            ""
                          (format "\n\n=== USER SCHEDULING RULES ===\n%s\n" rules-text)))
         (system-prompt
          (replace-regexp-in-string
           "%%CHEAT_SHEET%%" sem-prompts-org-mode-cheat-sheet
           (replace-regexp-in-string
            "%%RULES%%" rules-section
            (replace-regexp-in-string
             "%%LANGUAGE%%" language-instruction
             sem-prompts-pass1-system-template t t) t t)))
         (user-prompt
          (concat
           (format "Convert this task headline into a structured Org TODO entry:

HEADLINE: * %s %s"
                   title
                   (if tags
                       (format ":%s:" (string-join tags ":"))
                     ""))
           (format "\nCURRENT DATETIME (UTC): %s" current-datetime)
           (when sanitized-body
             (format "\n\nBODY:\n%s" sanitized-body))
           (format "\n\nUse this EXACT :ID: value in your output: %s
\nGenerate the complete Org TODO entry following the required format above."
                   injected-id))))
    (list :user-prompt user-prompt :system-prompt system-prompt)))

(defun sem-router--route-to-task-llm (headline callback &optional batch-id)
  "Route a task headline to LLM for task generation.

HEADLINE is the headline plist with :title, :tags, :body, :hash, etc.
CALLBACK is a function of (success context) called when processing completes.
  - SUCCESS is t if task was processed (including DLQ), nil for retry.
  - CONTEXT contains :hash, :title, and other metadata.

The LLM is prompted to return a valid Org TODO entry with:
- Cleaned title
- Optional DEADLINE/SCHEDULED/PRIORITY
- One-line description
- :PROPERTIES: drawer with :ID: (pre-generated UUID injected into prompt)
- :FILETAGS: set to one of the allowed tags

If the headline has a non-nil :body, it is sanitized with
`sem-security-sanitize-for-llm` before sending to the LLM, and the
response is restored with `sem-security-restore-from-llm` before validation.

The Elisp layer pre-generates the UUID via org-id-new and injects it into
the prompt. The LLM must use the provided ID verbatim. The response is
validated to ensure the ID matches exactly.

Uses sem-llm-request for consistent retry/DLQ handling.

Returns immediately (async). The CALLBACK is invoked when complete."
  (let ((dispatch-batch-id (or batch-id sem-core--batch-id)))
    (condition-case err
      (let* ((title (plist-get headline :title))
             (hash (plist-get headline :hash))
             (tags (plist-get headline :tags))
             (body (plist-get headline :body))
             ;; Pre-generate UUID for injection and validation
             (injected-id (org-id-new))
             ;; Sanitize body if present
             (security-blocks nil)
             (sanitized-body nil))

        ;; Sanitize body content if present
        ;; sem-security-sanitize-for-llm returns (tokenized-text blocks-alist position-info-alist)
        (when body
          (require 'sem-security)
          (let ((sanitize-result (sem-security-sanitize-for-llm body)))
            (setq sanitized-body (car sanitize-result))
            (setq security-blocks (cadr sanitize-result))))

        ;; Build prompts for task processing
        (let* ((prompt-pair (sem-router--build-task-llm-prompts title tags sanitized-body injected-id))
               (user-prompt (plist-get prompt-pair :user-prompt))
               (system-prompt (plist-get prompt-pair :system-prompt)))

          ;; Call sem-llm-request with callback
          (require 'sem-llm)
          (sem-llm-request user-prompt system-prompt
                           (lambda (response info context)
                             "Callback for sem-llm-request.
Validates the LLM response and writes to tasks.org with mutex lock."
                              (let ((headline-hash (plist-get context :hash))
                                    (headline-title (plist-get context :title))
                                    (injected-uuid (plist-get context :injected-id))
                                    (callback-batch-id (plist-get context :batch-id))
                                    (stored-security-blocks (plist-get context :security-blocks))
                                    (restored-response response)
                                    (success nil)
                                    (headline-context context))
                                (if (/= callback-batch-id sem-core--batch-id)
                                    (progn
                                      (sem-core-log "router" "INBOX-ITEM" "SKIP"
                                                    (format "Ignoring stale task callback: callback-batch=%d active-batch=%d title=%s"
                                                            callback-batch-id sem-core--batch-id headline-title)
                                                    nil)
                                      (when (fboundp 'sem-core--batch-barrier-check)
                                        (sem-core--batch-barrier-check callback-batch-id)))
                                  (progn
                                    ;; Restore security blocks if they were stored
                                    (when stored-security-blocks
                                      (require 'sem-security)
                                      (setq restored-response
                                            (sem-security-restore-from-llm response stored-security-blocks)))
                                    (if (and restored-response (not (string-empty-p restored-response)))
                                        ;; Validate and process response
                                        (if (sem-router--validate-task-response restored-response injected-uuid)
                                            ;; Valid response - normalize title then write to temp file.
                                            (let ((normalized-response
                                                   (sem-router--normalize-task-title-lowercase restored-response)))
                                              (sem-router--with-tasks-write-lock
                                               (plist-get context :headline)
                                               (lambda ()
                                                 (if (sem-router--write-task-to-file normalized-response
                                                                                     (sem-router--temp-file-path callback-batch-id)
                                                                                     callback-batch-id)
                                                     (progn
                                                       (sem-core-log "router" "INBOX-ITEM" "OK"
                                                                     (format "Task written to temp file: %s" headline-title)
                                                                     nil)
                                                       (sem-router--mark-processed headline-hash)
                                                       (setq headline-context (plist-put headline-context :security-blocks nil))
                                                       (setq success t))
                                                   (progn
                                                     (sem-core-log-error "router" "INBOX-ITEM"
                                                                         "Failed to write task to temp file"
                                                                         headline-title
                                                                         normalized-response)
                                                     (setq success nil)))
                                                 (when callback
                                                   (funcall callback success headline-context)))
                                               0
                                               (lambda ()
                                                 ;; Lock contention DLQ path counts as processed.
                                                 (when callback
                                                   (funcall callback t headline-context)))
                                               callback-batch-id))
                                          ;; Malformed output - send to DLQ
                                          (progn
                                            (sem-core-log-error "router" "INBOX-ITEM"
                                                                "Malformed LLM output for task (UUID mismatch or missing)"
                                                                headline-title
                                                                restored-response)
                                            (sem-router--mark-processed headline-hash)
                                            (setq headline-context (plist-put headline-context :security-blocks nil))
                                            (setq success t)))
                                      ;; API error - do NOT mark as processed (retry)
                                      (progn
                                        (sem-core-log "router" "INBOX-ITEM" "RETRY"
                                                      (format "LLM API error: %s" (plist-get info :error))
                                                      nil)
                                        (setq success nil)))
                                    ;; Call the completion callback for non-write paths.
                                    (unless (and restored-response
                                                 (not (string-empty-p restored-response))
                                                 (sem-router--validate-task-response restored-response injected-uuid))
                                      (when callback
                                        (funcall callback success headline-context)))))))
                             (list :hash hash
                                   :title title
                                   :headline headline
                                   :injected-id injected-id
                                   :batch-id dispatch-batch-id
                                   :security-blocks security-blocks)
                             'weak))

        ;; Return immediately - processing continues asynchronously
        t)
    (error
     (sem-core-log-error "router" "INBOX-ITEM"
                         (error-message-string err)
                         (plist-get headline :title)
                         nil)
     ;; Call callback with failure
     (when callback
       (funcall callback nil (list :hash (plist-get headline :hash)
                                   :title (plist-get headline :title))))
      nil))))

(defun sem-router--validate-task-response (response injected-id)
  "Validate LLM RESPONSE for task processing.

INJECTED-ID is the UUID that was pre-generated and injected into the prompt.
The response must contain this exact ID in the :ID: field.

Checks for required elements:
- :PROPERTIES: drawer
- :ID: field with exact match to INJECTED-ID
- :FILETAGS: field with valid tag

Returns t if valid, nil if malformed or UUID mismatch."
  (when (and response (not (string-empty-p response)) injected-id)
    (with-temp-buffer
      (insert response)
      (goto-char (point-min))
      (let ((has-properties (re-search-forward "^:PROPERTIES:" nil t))
            (has-id nil)
            (id-matches nil)
            (has-filetags (progn
                            (goto-char (point-min))
                            (re-search-forward "^:FILETAGS:" nil t)))
            (valid-tag nil))
        ;; Extract and validate ID using exact string match
        (goto-char (point-min))
        (when (re-search-forward "^:ID:[ \t]*\\([^[:space:]]+\\)" nil t)
          (setq has-id t)
          (let ((extracted-id (match-string 1)))
            ;; Exact string match comparison as per spec
            (setq id-matches (string= extracted-id injected-id))))
        ;; Check for valid tag
        (goto-char (point-min))
        (when (re-search-forward "^:FILETAGS:[ \t]*:\\([[:word:]]+\\):" nil t)
          (let ((tag (match-string 1)))
            (setq valid-tag (member tag sem-router-task-tags))))
        ;; All checks must pass including UUID match
        (and has-properties has-id has-filetags valid-tag id-matches)))))

(defun sem-router--validate-and-normalize-tag (response)
  "Validate and normalize the :FILETAGS: tag in RESPONSE.

If tag is absent or invalid, adds/substitutes :routine:.
Returns the normalized response string."
  (with-temp-buffer
    (insert response)
    (goto-char (point-min))
    (if (re-search-forward "^:FILETAGS:[ \t]*:\\([[:word:]]+\\):" nil t)
        ;; Tag exists - check if valid
        (let ((tag (match-string 1)))
          (if (member tag sem-router-task-tags)
              response
            ;; Invalid tag - substitute with routine (replace entire line)
            (goto-char (point-min))
            (when (re-search-forward "^:FILETAGS:[ \t]*:[^:]+:" nil t)
              (replace-match ":FILETAGS: :routine:"))
            (buffer-string)))
      ;; No tag found - add :routine: before :END:
      (goto-char (point-min))
      (when (re-search-forward "^:PROPERTIES:" nil t)
        (forward-line 1)
        (when (re-search-forward "^:END:" nil t)
          (beginning-of-line)
          (insert ":FILETAGS: :routine:\n")))
      (buffer-string))))

(defun sem-router--normalize-todo-headline (response)
  "Normalize first Org headline in RESPONSE to use canonical TODO form.

Ensures the first headline uses `* TODO <title>` ordering, removing misplaced
`TODO` tokens and priority tokens from the title area. If no headline is found,
returns RESPONSE unchanged."
  (with-temp-buffer
    (insert response)
    (goto-char (point-min))
    (when (re-search-forward "^\\(\\*+\\)[ \t]*\\(.*\\)$" nil t)
      (let* ((line-start (match-beginning 0))
             (line-end (match-end 0))
             (stars (match-string 1))
             (rest (match-string 2))
             (cleaned-title
              (string-trim
               (replace-regexp-in-string
                "[ \t]+" " "
                (replace-regexp-in-string "\\_<TODO\\_>" " " rest))))
             (title (if (string-empty-p cleaned-title)
                        "Task"
                      cleaned-title)))
        (delete-region line-start line-end)
        (goto-char line-start)
        (insert (format "%s TODO %s" stars title))))
    (buffer-string)))

(defun sem-router--normalize-task-title-lowercase (response)
  "Lowercase the first TODO headline title in RESPONSE.

Only the title text after the TODO keyword and optional priority marker is
lowercased. Non-title content remains unchanged."
  (with-temp-buffer
    (insert response)
    (goto-char (point-min))
    (when (re-search-forward
           "^\\(\\*+[ \t]+TODO\\(?:[ \t]+\\[#\\([A-Za-z]\\)\\]\\)?[ \t]+\\)\\(.*\\)$"
           nil t)
      (let ((line-start (match-beginning 0))
            (line-end (match-end 0))
            (headline-prefix (match-string 1))
            (headline-title (match-string 3)))
        (delete-region line-start line-end)
        (goto-char line-start)
        (insert (concat headline-prefix (downcase headline-title)))))
    (buffer-string)))

(defun sem-router--validate-and-normalize-priority (response)
  "Validate and normalize headline priority token in RESPONSE.

If priority is absent, inserts fallback `[#C]`. If priority is invalid,
replaces it with `[#C]`. Returns normalized response string."
  (with-temp-buffer
    (insert response)
    (goto-char (point-min))
    (when (re-search-forward "^\\(\\*+[ \t]+TODO\\)\\(.*\\)$" nil t)
      (let* ((line-start (match-beginning 0))
             (line-end (match-end 0))
             (todo-prefix (match-string 1))
             (headline-rest (match-string 2))
             (scan-start 0)
             (has-a nil)
             (has-b nil)
             (has-c nil)
             normalized-priority
             cleaned-rest)
        (while (string-match "\\[#\\([A-Za-z]\\)\\]" headline-rest scan-start)
          (let ((priority (upcase (match-string 1 headline-rest))))
            (cond
             ((string= priority "A") (setq has-a t))
             ((string= priority "B") (setq has-b t))
             ((string= priority "C") (setq has-c t))))
          (setq scan-start (match-end 0)))

        (setq normalized-priority
              (cond
               (has-a "[#A]")
               (has-b "[#B]")
               (has-c "[#C]")
               (t "[#C]")))

        (setq cleaned-rest
              (string-trim
               (replace-regexp-in-string
                "[ \t]+" " "
                (replace-regexp-in-string "[ \t]*\\[#\\([A-Za-z]\\)\\][ \t]*" " " headline-rest))))

        (delete-region line-start line-end)
        (goto-char line-start)
        (insert
         (if (string-empty-p cleaned-rest)
             (format "%s %s" todo-prefix normalized-priority)
           (format "%s %s %s" todo-prefix normalized-priority cleaned-rest)))))
    (buffer-string)))

(defun sem-router--normalize-scheduled-duration (response)
  "Normalize SCHEDULED duration in RESPONSE when end time is absent.

When SCHEDULED has a start time but no end time, inject a 30-minute end time.
Unsupported or already-ranged SCHEDULED lines are preserved unchanged."
  (with-temp-buffer
    (insert response)
    (goto-char (point-min))
    (when (re-search-forward "^SCHEDULED:[ \t]*<\\([^>]+\\)>" nil t)
      (let ((timestamp-content (match-string 1))
            (line-start (match-beginning 0))
            (line-end (match-end 0)))
        (when (and (not (string-match-p "[0-9]\\{2\\}:[0-9]\\{2\\}-[0-9]\\{2\\}:[0-9]\\{2\\}" timestamp-content))
                   (string-match
                    "^\\([0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\)\\(?:[ \t]+\\([A-Za-z]\\{3\\}\\)\\)?[ \t]+\\([0-9]\\{2\\}\\):\\([0-9]\\{2\\}\\)$"
                    timestamp-content))
          (let* ((date-part (match-string 1 timestamp-content))
                 (day-part (match-string 2 timestamp-content))
                 (start-hour (string-to-number (match-string 3 timestamp-content)))
                 (start-minute (string-to-number (match-string 4 timestamp-content)))
                 (year (string-to-number (substring date-part 0 4)))
                 (month (string-to-number (substring date-part 5 7)))
                 (day (string-to-number (substring date-part 8 10)))
                 (start-time (encode-time 0 start-minute start-hour day month year t))
                 (end-time (time-add start-time (seconds-to-time (* 30 60))))
                 (end-hour (format-time-string "%H" end-time t))
                 (end-minute (format-time-string "%M" end-time t))
                 (normalized-content
                  (if day-part
                      (format "%s %s %02d:%02d-%s:%s"
                              date-part day-part start-hour start-minute end-hour end-minute)
                    (format "%s %02d:%02d-%s:%s"
                            date-part start-hour start-minute end-hour end-minute))))
            (delete-region line-start line-end)
            (goto-char line-start)
            (insert (format "SCHEDULED: <%s>" normalized-content))))))
    (buffer-string)))

(defun sem-router--normalize-task-response (response)
  "Apply all task-response normalization rules to RESPONSE.

Normalizes tag, priority, and scheduled duration fallbacks before planner input.
Returns normalized response string."
  (let* ((headline-normalized (sem-router--normalize-todo-headline response))
         (tag-normalized (sem-router--validate-and-normalize-tag headline-normalized))
         (priority-normalized (sem-router--validate-and-normalize-priority tag-normalized))
         (schedule-normalized (sem-router--normalize-scheduled-duration priority-normalized)))
    schedule-normalized))

(defun sem-router--temp-file-path (&optional batch-id)
  "Compute the temp file path for a batch.
BATCH-ID is the batch identifier. Defaults to sem-core--batch-id.
Returns /tmp/data/tasks-tmp-{batch-id}.org"
  (let ((id (or batch-id sem-core--batch-id 0)))
    (format "/tmp/data/tasks-tmp-%d.org" id)))

(defun sem-router--temp-file-batch-id (temp-file)
  "Extract batch id from TEMP-FILE path.
Returns integer batch id or nil when TEMP-FILE is not a batch temp path."
  (when (and (stringp temp-file)
             (string-match "tasks-tmp-\\([0-9]+\\)\\.org\\'" temp-file))
    (string-to-number (match-string 1 temp-file))))

(defun sem-router--write-task-to-file (response &optional temp-file expected-batch-id)
  "Validate and write task RESPONSE to tasks.org or TEMP-FILE.

If TEMP-FILE is provided, writes to that file instead of tasks.org.
When EXPECTED-BATCH-ID is non-nil, TEMP-FILE must match that batch id.
Normalizes tag, priority fallback, and schedule duration fallback.
Creates the target file if it doesn't exist.
Appends the task entry to the file.

Returns t on success, nil on failure."
  (condition-case err
      (let* ((normalized (sem-router--normalize-task-response response))
             (target-file (or temp-file sem-router-tasks-file))
             (target-batch-id (and temp-file (sem-router--temp-file-batch-id temp-file))))

        (when (and temp-file expected-batch-id (/= expected-batch-id (or target-batch-id -1)))
          (sem-core-log "router" "INBOX-ITEM" "SKIP"
                        (format "Dropped stale temp write: expected-batch=%d target-file=%s"
                                expected-batch-id temp-file)
                        nil)
          (cl-return-from sem-router--write-task-to-file nil))

        ;; Create file if it doesn't exist
        (unless (file-exists-p target-file)
          (make-directory (file-name-directory target-file) t)
          (with-temp-file target-file
            (unless temp-file
              (insert "* Tasks\n"))))

        ;; Append task to file
        (with-temp-buffer
          (when (file-exists-p target-file)
            (insert-file-contents target-file))
          (goto-char (point-max))
          (insert "\n" normalized "\n")
          (write-region (point-min) (point-max) target-file nil 'silent))

        t)
    (error
     (sem-core-log-error "router" "INBOX-ITEM"
                         (format "Failed to write task: %s" (error-message-string err))
                         response
                         nil)
     nil)))

;;; Main Processing Entry Point

(defun sem-router-process-inbox (&optional batch-id)
  "Process all unprocessed headlines from inbox-mobile.org.
Routes each headline to the appropriate handler:
- @link or URL headlines -> sem-url-capture-process
- @task headlines -> LLM task generation
- Unknown tags -> skip with log

This is called by sem-core-process-inbox."
  (cl-block sem-router-process-inbox
    (condition-case err
        (let ((headlines (sem-router--parse-headlines))
              (dispatch-batch-id (or batch-id sem-core--batch-id))
              (processed-count 0)
              (skipped-count 0)
              (error-count 0))

          (message "SEM: sem-router-process-inbox: found %d headlines" (length headlines))
          (unless headlines
            (message "SEM: sem-router-process-inbox: no headlines, returning nil")
            (cl-return-from sem-router-process-inbox nil))

          (message "SEM: Processing %d headlines..." (length headlines))

          (dolist (headline headlines)
            (let ((hash (plist-get headline :hash))
                  (title (plist-get headline :title)))

              (message "SEM: Headline: %s | tags: %s" title (plist-get headline :tags))
              (if (sem-router--is-processed hash)
                  (progn
                    (message "SEM: Already processed, skipping: %s" title)
                    (setq skipped-count (1+ skipped-count)))
                ;; Route based on tag/type
                (let ((url (sem-router--is-link-headline headline)))
                  (cond
                   ;; Link headline -> URL capture (async)
                    (url
                     (message "SEM: Routing to URL capture: %s" url)
                     (setq sem-core--pending-callbacks (1+ sem-core--pending-callbacks))
                      (sem-url-capture-process
                       url
                        (lambda (filepath context)
                          "Callback for async URL capture.
Handles success, retry, and DLQ escalation."
                          (if (/= dispatch-batch-id sem-core--batch-id)
                              (sem-core-log "router" "INBOX-ITEM" "SKIP"
                                            (format "Ignoring stale URL callback: callback-batch=%d active-batch=%d url=%s"
                                                    dispatch-batch-id sem-core--batch-id url)
                                            nil)
                            (if filepath
                                ;; Success - mark processed and increment count
                                (progn
                                  (sem-core--clear-retry hash)
                                  (sem-router--mark-processed hash)
                                  (setq processed-count (1+ processed-count))
                                  (message "SEM: URL captured: %s -> %s" url filepath))
                              ;; Failure - implement bounded retry
                              (let ((failure-kind (plist-get context :failure-kind))
                                    (retry-count (sem-core--increment-retry hash)))
                                (when (eq failure-kind 'timeout)
                                  (sem-core-log "router" "URL-CAPTURE" "FAIL"
                                                (format "URL capture timeout (attempt %d/3): %s"
                                                        retry-count url)
                                                nil))
                                (if (>= retry-count 3)
                                    ;; Max retries reached - move to DLQ
                                    (progn
                                      (sem-core--mark-dlq hash title nil)
                                      (message "SEM: URL capture failed after 3 retries, moved to DLQ: %s" url))
                                  ;; Will retry on next cron cycle
                                  (message "SEM: URL capture failed (attempt %d/3), will retry: %s" retry-count url)))))
                          (when (fboundp 'sem-core--batch-barrier-check)
                            (sem-core--batch-barrier-check dispatch-batch-id)))))
                    ;; Task headline -> LLM task generation (async)
                    ((sem-router--is-task-headline headline)
                     (message "SEM: Routing to LLM task generation: %s" title)
                     (setq sem-core--pending-callbacks (1+ sem-core--pending-callbacks))
                      (sem-router--route-to-task-llm
                       headline
                       (lambda (success context)
                         "Callback for async task LLM processing."
                         (let ((callback-batch-id (or (plist-get context :batch-id) dispatch-batch-id)))
                           (if (/= callback-batch-id sem-core--batch-id)
                               (sem-core-log "router" "INBOX-ITEM" "SKIP"
                                             (format "Ignoring stale task completion callback: callback-batch=%d active-batch=%d title=%s"
                                                     callback-batch-id sem-core--batch-id
                                                     (plist-get context :title))
                                             nil)
                             (if success
                                 (message "SEM: Task LLM processed: %s" (plist-get context :title))
                               (message "SEM: Task LLM failed: %s" (plist-get context :title))))
                           (when (fboundp 'sem-core--batch-barrier-check)
                             (sem-core--batch-barrier-check callback-batch-id))))
                       dispatch-batch-id)
                      (setq processed-count (1+ processed-count)))
                   ;; Unknown - skip
                   (t
                    (message "SEM: No routing rule matched, skipping: %s" title)
                    (sem-core-log "router" "INBOX-ITEM" "SKIP"
                                  (format "Unknown tag, skipping: %s" title)
                                  nil)
                    (setq skipped-count (1+ skipped-count))
                    ;; Mark as processed to avoid infinite loop
                    (sem-router--mark-processed hash)))))))

          (sem-core-log "router" "INBOX-ITEM" "OK"
                        (format "Processed=%d, Skipped=%d, Errors=%d"
                                processed-count skipped-count error-count)
                        nil)
          (message "SEM: Inbox processing complete: %d processed, %d skipped, %d errors"
                   processed-count skipped-count error-count))
      (error
       (sem-core-log-error "router" "INBOX-ITEM"
                           (error-message-string err)
                           nil
                           nil)
       (message "SEM: Router error: %s" (error-message-string err))))))

(provide 'sem-router)
;;; sem-router.el ends here
