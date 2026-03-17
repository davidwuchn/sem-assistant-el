;;; sem-router.el --- Inbox routing and cursor tracking -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; This module parses headlines from inbox-mobile.org and routes them
;; to the appropriate handler (url-capture or LLM task generation).
;; It also manages cursor tracking via content hashes.

;;; Code:

(require 'org)
(require 'sem-core)

;;; Constants

(defconst sem-router-inbox-file "/data/inbox-mobile.org"
  "Path to the inbox file to process.")

(defconst sem-router-tasks-file "/data/tasks.org"
  "Path to the tasks file where processed @task headlines are written.")

(defconst sem-router-task-tags '("work" "family" "routine" "opensource")
  "Allowed tags for task headlines. Must be one of these values.")

;;; Headline Parsing

(defun sem-router--parse-headlines ()
  "Parse all headlines from inbox-mobile.org.
Returns a list of headline plists with :title, :tags, :link, :point, :hash."
  (cl-block sem-router--parse-headlines
    (unless (file-exists-p sem-router-inbox-file)
      (sem-core-log "router" "INBOX-ITEM" "SKIP" "inbox-mobile.org does not exist")
      (cl-return-from sem-router--parse-headlines nil))

    (let ((headlines '()))
      (with-temp-buffer
        (insert-file-contents sem-router-inbox-file)
        (goto-char (point-min))

        (while (re-search-forward "^\\*+ " nil t)
          (let* ((start (match-beginning 0))
                 (headline-start (match-end 0))  ; Position after "* "
                 (line (buffer-substring-no-properties
                        (line-beginning-position) (line-end-position)))
                 (title (string-trim (substring line (- headline-start (line-beginning-position)))))
                 (tags (save-excursion
                         (when (re-search-forward ":\\([[:word:]:]+\\):" (line-end-position) t)
                           (split-string (match-string 1) ":" t))))
                 (link (when (string-match-p "^https?://" title)
                         (substring-no-properties title)))
                 (hash (secure-hash 'sha256 (concat title "|" (or (string-join tags ":") "")))))

            (push (list :title title
                        :tags tags
                        :link link
                        :point start
                        :hash hash)
                  headlines))))

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

HEADLINE is the headline plist with :title, :tags, :hash, etc.
CALLBACK is a function of (success context) called when processing completes.
  - SUCCESS is t if task was processed (including DLQ), nil for retry.
  - CONTEXT contains :hash, :title, and other metadata.

The LLM is prompted to return a valid Org TODO entry with:
- Cleaned title
- Optional DEADLINE/SCHEDULED/PRIORITY
- One-line description
- :PROPERTIES: drawer with :ID: (org-id)
- :FILETAGS: set to one of the allowed tags

The Elisp layer validates the tag and substitutes :routine: if absent or invalid.
Uses sem-llm-request for consistent retry/DLQ handling.

Returns immediately (async). The CALLBACK is invoked when complete."
  (condition-case err
      (let* ((title (plist-get headline :title))
             (hash (plist-get headline :hash))
             (tags (plist-get headline :tags)))

        ;; Build the LLM prompt for task processing
        (let* ((system-prompt "You are a Task Management assistant. Your ONLY task is to output a valid Org-mode TODO entry based on the provided task description.

CRITICAL REQUIREMENT: YOU MUST USE STRICT ORG-MODE SYNTAX.

=== ORG-MODE SYNTAX CHEAT SHEET ===
- Headings: Use asterisks `* TODO Heading` (NEVER use `# Heading`).
- Bold: `*bold text*` (NEVER use `**bold**`).
- Italic: `/italic text/` (NEVER use `*italic*` or `_italic_`).
- Inline code: `=code=` or `~verbatim~` (NEVER use backticks).

=== REQUIRED OUTPUT FORMAT ===
Your output MUST follow this exact structure:

* TODO <Cleaned Task Title>
:PROPERTIES:
:ID: <generate-a-valid-org-id-uuid>
:FILETAGS: :<one-of:work:family:routine:opensource>:
:END:
<Brief one-line description or notes>
<Optional: SCHEDULED: <YYYY-MM-DD Day>>
<Optional: DEADLINE: <YYYY-MM-DD Day>>
<Optional: PRIORITY: [A/B/C]>

RULES:
1. :FILETAGS: MUST be exactly one of: :work:, :family:, :routine:, or :opensource:
2. :ID: MUST be a valid UUID format (e.g., 550e8400-e29b-41d4-a716-446655440000)
3. Output ONLY the Org entry - no explanations, no markdown wrappers
4. Clean up the task title to be concise and actionable")
               (user-prompt (format "Convert this task headline into a structured Org TODO entry:

HEADLINE: * %s %s

Generate the complete Org TODO entry following the required format above."
                                    title
                                    (if tags
                                        (format ":%s:" (string-join tags ":"))
                                      ""))))

          ;; Call sem-llm-request with callback
          (require 'sem-llm)
          (sem-llm-request user-prompt system-prompt
                           (lambda (response info context)
                             "Callback for sem-llm-request.
Validates the LLM response and writes to tasks.org."
                             (let ((headline-hash (plist-get context :hash))
                                   (headline-title (plist-get context :title))
                                   (success nil))
                               (if (and response (not (string-empty-p response)))
                                   ;; Validate and process response
                                   (if (sem-router--validate-task-response response)
                                       ;; Valid response - write to tasks.org
                                       (if (sem-router--write-task-to-file response)
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
                                                               response)
                                           (setq success nil)))
                                     ;; Malformed output - send to DLQ
                                     (progn
                                       (sem-core-log-error "router" "INBOX-ITEM"
                                                           "Malformed LLM output for task"
                                                           headline-title
                                                           response)
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
                           (list :hash hash :title title :headline headline)))

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

(defun sem-router--validate-task-response (response)
  "Validate LLM RESPONSE for task processing.

Checks for required elements:
- :PROPERTIES: drawer
- :ID: field
- :FILETAGS: field with valid tag

Returns t if valid, nil if malformed."
  (when (and response (not (string-empty-p response)))
    (with-temp-buffer
      (insert response)
      (goto-char (point-min))
      (let ((has-properties (re-search-forward "^:PROPERTIES:" nil t))
            (has-id (re-search-forward "^:ID:" nil t))
            (has-filetags (progn
                            (goto-char (point-min))
                            (re-search-forward "^:FILETAGS:" nil t)))
            (valid-tag nil))
        ;; Check for valid tag
        (goto-char (point-min))
        (when (re-search-forward "^:FILETAGS:[ \t]*:\\([[:word:]]+\\):" nil t)
          (let ((tag (match-string 1)))
            (setq valid-tag (member tag sem-router-task-tags))))
        (and has-properties has-id has-filetags valid-tag)))))

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
            ;; Invalid tag - substitute with routine
            (goto-char (point-min))
            (re-search-forward "^:FILETAGS:[ \t]*:[[:word:]]+:" nil t)
            (replace-match ":FILETAGS: :routine:")
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
