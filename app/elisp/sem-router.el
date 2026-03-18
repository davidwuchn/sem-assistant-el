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

(defun sem-router--with-tasks-write-lock (headline callback retry-count)
  "Execute CALLBACK with tasks.org write lock held.
If lock is held, re-schedules with 0.5s delay up to 10 retries.
After 10 retries, routes to DLQ via sem-core-log-error.
HEADLINE is the headline plist for error logging.
RETRY-COUNT is the current retry attempt number."
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
          (sem-router--mark-processed (plist-get headline :hash)))
      ;; Schedule retry
      (run-with-timer sem-router--write-retry-delay nil
                      (lambda ()
                        (sem-router--with-tasks-write-lock headline callback (1+ retry-count)))))))

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
      (sem-core-log "router" "INBOX-ITEM" "SKIP" "inbox-mobile.org does not exist")
      (cl-return-from sem-router--parse-headlines nil))

    (let ((headlines '()))
      (with-temp-buffer
        (insert-file-contents sem-router-inbox-file)
        (org-mode)
        (let ((ast (org-element-parse-buffer)))
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
                (push (list :title title
                            :tags tags
                            :body body
                            :link link
                            :point begin
                            :hash hash)
                      headlines))))))

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

(defun sem-router--route-to-task-llm (headline callback)
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
        ;; sem-security-sanitize-for-llm returns (sanitized-text . blocks-alist)
        (when body
          (require 'sem-security)
          (let ((sanitize-result (sem-security-sanitize-for-llm body)))
            (setq sanitized-body (car sanitize-result))
            (setq security-blocks (cdr sanitize-result))))

        ;; Build the LLM prompt for task processing
        ;; Read OUTPUT_LANGUAGE at call time (not load time) with default "English"
        (let* ((output-language (or (getenv "OUTPUT_LANGUAGE") "English"))
               (language-instruction (format "\n\nOUTPUT LANGUAGE: Write your entire response in %s. Do not use any other language." output-language))
               (system-prompt (concat "You are a Task Management assistant. Your ONLY task is to output a valid Org-mode TODO entry based on the provided task description.\n\n"
                                      sem-prompts-org-mode-cheat-sheet
                                      "\n\n=== REQUIRED OUTPUT FORMAT ===\n"
                                      "Your output MUST follow this exact structure:\n\n"
                                      "* TODO <Cleaned Task Title>\n"
                                      ":PROPERTIES:\n"
                                      ":ID: <injected-id-value>\n"
                                      ":FILETAGS: :<one-of:work:family:routine:opensource>:\n"
                                      ":END:\n"
                                      "<Brief one-line description or notes>\n"
                                      "<Optional: SCHEDULED: <YYYY-MM-DD Day>>\n"
                                      "<Optional: DEADLINE: <YYYY-MM-DD Day>>\n"
                                      "<Optional: PRIORITY: [A/B/C]>\n\n"
                                      "RULES:\n"
                                      "1. :FILETAGS: MUST be exactly one of: :work:, :family:, :routine:, or :opensource:\n"
                                      "2. :ID: MUST be the EXACT value provided in the template below - do not generate, modify, or substitute it\n"
                                      "3. Output ONLY the Org entry - no explanations, no markdown wrappers\n"
                                      "4. Clean up the task title to be concise and actionable\n\n"
                                      "CRITICAL: Use EXACTLY the :ID: value provided in the template below. Do not generate, modify, or substitute it."
                                      language-instruction))
               (user-prompt (concat
                             (format "Convert this task headline into a structured Org TODO entry:

HEADLINE: * %s %s"
                                     title
                                     (if tags
                                         (format ":%s:" (string-join tags ":"))
                                       ""))
                             (when sanitized-body
                               (format "\n\nBODY:\n%s" sanitized-body))
                             (format "\n\nUse this EXACT :ID: value in your output: %s
\nGenerate the complete Org TODO entry following the required format above."
                                     injected-id))))

          ;; Call sem-llm-request with callback
          (require 'sem-llm)
          (sem-llm-request user-prompt system-prompt
                           (lambda (response info context)
                             "Callback for sem-llm-request.
Validates the LLM response and writes to tasks.org with mutex lock."
                             (let ((headline-hash (plist-get context :hash))
                                   (headline-title (plist-get context :title))
                                   (injected-uuid (plist-get context :injected-id))
                                   (stored-security-blocks (plist-get context :security-blocks))
                                   (restored-response response)
                                   (success nil)
                                   (headline-context context))
                               ;; Restore security blocks if they were stored
                               (when stored-security-blocks
                                 (require 'sem-security)
                                 (setq restored-response
                                       (sem-security-restore-from-llm response stored-security-blocks)))
                               (if (and restored-response (not (string-empty-p restored-response)))
                                   ;; Validate and process response
                                   (if (sem-router--validate-task-response restored-response injected-uuid)
                                       ;; Valid response - write to tasks.org with lock
                                       (sem-router--with-tasks-write-lock
                                        headline-context
                                        (lambda ()
                                          (if (sem-router--write-task-to-file restored-response)
                                              (progn
                                                (sem-core-log "router" "INBOX-ITEM" "OK"
                                                              (format "Task written to tasks.org: %s" headline-title)
                                                              nil)
                                                (sem-router--mark-processed headline-hash)
                                                (setq success t))
                                            (progn
                                              (sem-core-log-error "router" "INBOX-ITEM"
                                                                  "Failed to write task to file"
                                                                  headline-title
                                                                  restored-response)
                                              (setq success nil))))
                                        0)
                                     ;; Malformed output - send to DLQ
                                     (progn
                                       (sem-core-log-error "router" "INBOX-ITEM"
                                                           "Malformed LLM output for task (UUID mismatch or missing)"
                                                           headline-title
                                                           restored-response)
                                       (sem-router--mark-processed headline-hash)
                                       (setq success t)))
                                 ;; API error - do NOT mark as processed (retry)
                                 (progn
                                   (sem-core-log "router" "INBOX-ITEM" "RETRY"
                                                 (format "LLM API error: %s" (plist-get info :error))
                                                 nil)
                                   (setq success nil)))
                               ;; Call the completion callback
                               (when callback
                                 (funcall callback success context))))
                           (list :hash hash :title title :headline headline :injected-id injected-id :security-blocks security-blocks)))

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
     nil)))

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

(defun sem-router--write-task-to-file (response)
  "Validate and write task RESPONSE to tasks.org.

Normalizes the tag (substitutes :routine: if absent/invalid).
Creates tasks.org if it doesn't exist.
Appends the task entry to the file.

Returns t on success, nil on failure."
  (condition-case err
      (let* ((normalized (sem-router--validate-and-normalize-tag response))
             (tasks-file sem-router-tasks-file))

        ;; Create file if it doesn't exist
        (unless (file-exists-p tasks-file)
          (make-directory (file-name-directory tasks-file) t)
          (with-temp-file tasks-file
            (insert "* Tasks\n")))

        ;; Append task to file
        (with-temp-buffer
          (when (file-exists-p tasks-file)
            (insert-file-contents tasks-file))
          (goto-char (point-max))
          (insert "\n" normalized "\n")
          (write-region (point-min) (point-max) tasks-file nil 'silent))

        t)
    (error
     (sem-core-log-error "router" "INBOX-ITEM"
                         (format "Failed to write task: %s" (error-message-string err))
                         response
                         nil)
     nil)))

;;; Main Processing Entry Point

(defun sem-router-process-inbox ()
  "Process all unprocessed headlines from inbox-mobile.org.
Routes each headline to the appropriate handler:
- @link or URL headlines -> sem-url-capture-process
- @task headlines -> LLM task generation
- Unknown tags -> skip with log

This is called by sem-core-process-inbox."
  (cl-block sem-router-process-inbox
    (condition-case err
        (let ((headlines (sem-router--parse-headlines))
              (processed-count 0)
              (skipped-count 0)
              (error-count 0))

          (unless headlines
            (cl-return-from sem-router-process-inbox nil))

          (dolist (headline headlines)
            (let ((hash (plist-get headline :hash))
                  (title (plist-get headline :title)))

              ;; Skip if already processed
              (if (sem-router--is-processed hash)
                  (progn
                    (setq skipped-count (1+ skipped-count)))
                ;; Route based on tag/type
                (let ((url (sem-router--is-link-headline headline)))
                  (cond
                   ;; Link headline -> URL capture (async)
                   (url
                    (sem-url-capture-process
                     url
                     (lambda (filepath context)
                       "Callback for async URL capture.
Handles success, retry, and DLQ escalation."
                       (if filepath
                           ;; Success - mark processed and increment count
                           (progn
                             (sem-core--clear-retry hash)
                             (sem-router--mark-processed hash)
                             (setq processed-count (1+ processed-count))
                             (message "SEM: URL captured: %s -> %s" url filepath))
                         ;; Failure - implement bounded retry
                         (let ((retry-count (sem-core--increment-retry hash)))
                           (if (>= retry-count 3)
                               ;; Max retries reached - move to DLQ
                               (progn
                                 (sem-core--mark-dlq hash title nil)
                                 (message "SEM: URL capture failed after 3 retries, moved to DLQ: %s" url))
                             ;; Will retry on next cron cycle
                             (message "SEM: URL capture failed (attempt %d/3), will retry: %s" retry-count url)))))))
                   ;; Task headline -> LLM task generation (async)
                   ((sem-router--is-task-headline headline)
                    (sem-router--route-to-task-llm
                     headline
                     (lambda (success context)
                       "Callback for async task LLM processing."
                       (if success
                           (message "SEM: Task LLM processed: %s" (plist-get context :title))
                         (message "SEM: Task LLM failed: %s" (plist-get context :title)))))
                    ;; Note: Async processing - counts will be inaccurate in summary
                    (setq processed-count (1+ processed-count)))
                   ;; Unknown - skip
                   (t
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
