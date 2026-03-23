;;; sem-core.el --- Core logging and inbox processing functions -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; This module provides the core logging infrastructure and inbox processing
;; entry points for the SEM Assistant daemon.
;;
;; All other modules depend on this module being loaded first.

;;; Code:

(require 'org)
(require 'cl-lib)

;;; Constants

(defconst sem-core-log-file "/data/sem-log.org"
  "Path to the structured log file.")

(defconst sem-core-errors-file "/data/errors.org"
  "Path to the errors Dead Letter Queue file.")

(defconst sem-core-cursor-file "/data/.sem-cursor.el"
  "Path to the cursor tracking file for processed headlines.")

(defconst sem-core-retries-file "/data/.sem-retries.el"
  "Path to the retry tracking file for failed LLM requests.")

(defconst sem-core-inbox-file "/data/inbox-mobile.org"
  "Path to the inbox file synced by Orgzly.")

;;; Structured Logging

(defun sem-core--ensure-log-headings ()
  "Ensure the log file has the required heading structure.
Creates /data/sem-log.org with year/month headings as needed.
Returns t on success, nil on failure."
  (condition-case _err
      (progn
        (let* ((now (current-time))
               (year (format-time-string "%Y" now))
               (month (format-time-string "%m" now))
               (month-name (format-time-string "%B" now))
               (day (format-time-string "%Y-%m-%d" now))
               (log-file sem-core-log-file))

          ;; Ensure directory exists
          (make-directory (file-name-directory log-file) t)

          ;; Create or open log file
          (unless (file-exists-p log-file)
            (with-temp-file log-file
              (insert "* " year "\n")))

          ;; Read current content
          (with-temp-buffer
            (insert-file-contents log-file)

            ;; Check/create year heading
            (goto-char (point-min))
            (unless (re-search-forward (format "^\\* %s$" year) nil t)
              (goto-char (point-max))
              (insert "* " year "\n"))

            ;; Check/create month heading
            (goto-char (point-min))
            (unless (re-search-forward (format "^\\*\\* %s (%s)$" month month-name) nil t)
              (goto-char (point-max))
              (insert "** " month " (" month-name ")\n"))

            ;; Check/create day heading
            (goto-char (point-min))
            (unless (re-search-forward (format "^\\*\\*\\* %s" day) nil t)
              (goto-char (point-max))
              (insert "*** " day "\n"))

            ;; Write back
            (write-region (point-min) (point-max) log-file nil 'silent)))
        t)
    (error nil)))  ; Silently fail on read-only filesystems

(defun sem-core-log (module event-type status message &optional tokens)
  "Write a structured log entry to `sem-core-log-file'.

MODULE is one of: core, router, rss, url-capture, security, llm, elfeed, purge, init.
EVENT-TYPE is one of: INBOX-ITEM, URL-CAPTURE, RSS-DIGEST, ARXIV-DIGEST, ELFEED-UPDATE, PURGE, STARTUP, ERROR.
STATUS is one of: OK, RETRY, DLQ, SKIP, FAIL.
MESSAGE is a free-form string (max 200 chars, no newlines).
TOKENS is optional approximate input character count divided by 4.

Format: - [HH:MM:SS] [MODULE] [EVENT-TYPE] [STATUS] tokens=NNN | message"
  (cl-block sem-core-log
    (ignore-errors
      ;; Check if log file initialized successfully before proceeding
      (let ((ensure-result (sem-core--ensure-log-headings)))
        (unless ensure-result
          (cl-return-from sem-core-log nil)))

      (let* ((now (current-time))
               (timestamp (format-time-string "%H:%M:%S" now))
               (day (format-time-string "%Y-%m-%d" now))
               (log-file sem-core-log-file)
               (tokens-str (if tokens (format " tokens=%d |" tokens) " |"))
               ;; Truncate message to 200 chars and remove newlines
               (clean-message (substring (replace-regexp-in-string "\n" " " (or message "")) 0 (min 200 (length (or message ""))))))

          (with-temp-buffer
            (insert-file-contents log-file)

            ;; Find the day heading and append log entry
            (goto-char (point-min))
            (if (re-search-forward (format "^\\*\\*\\* %s$" day) nil t)
                (progn
                  (end-of-line)
                  (insert "\n- [" timestamp "] [" module "] [" event-type "] [" status "]" tokens-str " " clean-message))
              ;; Day heading not found, create it under the month
              (goto-char (point-max))
              (insert "*** " day "\n")
              (insert "- [" timestamp "] [" module "] [" event-type "] [" status "]" tokens-str " " clean-message))

            (write-region (point-min) (point-max) log-file nil 'silent))))))
  ; Never crash on logging errors

(defun sem-core-log-error (module event-type error-msg input &optional raw-output)
  "Append an error entry to both `sem-core-log-file' and `sem-core-errors-file'.

MODULE, EVENT-TYPE as in `sem-core-log'.
ERROR-MSG is the error description.
INPUT is the original input text or URL that caused the failure.
RAW-OUTPUT is the raw LLM response, or nil if LLM was not called.

This calls `sem-core-log' with STATUS=FAIL or STATUS=DLQ, and appends
detailed error info to errors.org."
  (condition-case _err
      (progn
        ;; Log to sem-log.org with FAIL status
        (sem-core-log module event-type (if raw-output "DLQ" "FAIL") (or error-msg "Unknown error") nil)

        ;; Append to errors.org
        (let* ((now (current-time))
               (timestamp (format-time-string "%Y-%m-%d %H:%M:%S" now))
               (errors-file sem-core-errors-file)
               (created (format-time-string "[%Y-%m-%d %H:%M:%S]" now)))

          (make-directory (file-name-directory errors-file) t)

          (with-temp-buffer
            (when (file-exists-p errors-file)
              (insert-file-contents errors-file))

            ;; Insert error entry
            (goto-char (point-max))
            (insert (format "* [%s] [%s] [%s] FAIL\n" timestamp module event-type))
            (insert ":PROPERTIES:\n")
            (insert ":CREATED: " created "\n")
            (insert ":END:\n")
            (insert "Error: " (or error-msg "Unknown error") "\n\n")
            (insert "** Input\n")
            (insert (or input "N/A") "\n\n")
            (insert "** Raw LLM Output\n")
            (insert (or raw-output "N/A") "\n\n")

            (write-region (point-min) (point-max) errors-file nil 'silent))))
    (t nil)))  ; Never crash on logging errors

;;; Messages Persistence

(defvar sem-core--last-flush-date ""
  "Date of the last message buffer flush (YYYY-MM-DD format).
Used to detect date rollover for daily log rotation.
Initial value is empty string to force first flush to detect as new day.
Module-level variable that resets on daemon restart.")

(defvar sem-core--batch-id 0
  "Monotonically increasing batch ID for inbox processing.
Incremented at the start of each cron-triggered inbox processing run.
Not incremented during planning phase - creates implicit lock.")

(defvar sem-core--pending-callbacks 0
  "Counter for pending async callbacks in the current batch.
Incremented when a callback is registered, decremented when it completes.
When it reaches 0, the batch barrier fires and planning step is triggered.")

(defvar sem-core--batch-start-time nil
  "Time when the current batch started.
Used for the 30-minute watchdog timeout.
Nil when no batch is in progress.")

(defvar sem-core--batch-watchdog-timer nil
  "Timer for the batch watchdog.
Cancels the previous timer before setting a new one.")

(defun sem-core--batch-barrier-check ()
  "Check if batch is complete and fire planning step if needed.
Called after each callback completes. Decrements pending-callbacks counter.
When counter reaches 0, invokes the planning step synchronously.
Also fires synchronously if counter starts at 0 (no items case)."
  (when (> sem-core--pending-callbacks 0)
    (setq sem-core--pending-callbacks (1- sem-core--pending-callbacks)))
  (sem-core-log "core" "INBOX-ITEM" "OK"
                (format "Batch barrier check: pending=%d" sem-core--pending-callbacks)
                nil)
  (when (= sem-core--pending-callbacks 0)
    (sem-core--cancel-batch-watchdog)
    (message "SEM: Batch complete, firing planning step")
    (when (fboundp 'sem-planner-run-planning-step)
      (sem-planner-run-planning-step))))

(defun sem-core--batch-watchdog-fired ()
  "Watchdog callback - fires planning step if barrier hasn't fired.
Called by the watchdog timer after 30 minutes from batch start.
Checks if pending-callbacks is still > 0, then fires planning step."
  (condition-case err
      (progn
        (message "SEM: Batch watchdog fired")
        (sem-core-log "core" "INBOX-ITEM" "OK" "Batch watchdog fired" nil)
        (setq sem-core--pending-callbacks 0)
        (when (fboundp 'sem-planner-run-planning-step)
          (sem-planner-run-planning-step)))
    (error
     (message "SEM: Watchdog error: %s" (error-message-string err)))))

(defun sem-core--start-batch-watchdog ()
  "Start or reset the batch watchdog timer.
The watchdog fires after 30 minutes if the barrier hasn't fired.
Cancels any existing watchdog before starting a new one."
  (setq sem-core--batch-start-time (current-time))
  (when sem-core--batch-watchdog-timer
    (cancel-timer sem-core--batch-watchdog-timer))
  (setq sem-core--batch-watchdog-timer
        (run-with-timer (* 30 60) nil #'sem-core--batch-watchdog-fired))
  (message "SEM: Batch watchdog started (30 min timeout)"))

(defun sem-core--cancel-batch-watchdog ()
  "Cancel the batch watchdog timer if running."
  (when sem-core--batch-watchdog-timer
    (cancel-timer sem-core--batch-watchdog-timer)
    (setq sem-core--batch-watchdog-timer nil)
    (message "SEM: Batch watchdog cancelled")))

(defun sem-core--flush-messages-daily ()
  "Append *Messages* buffer content to daily log file.
Writes to /var/log/sem/messages-YYYY-MM-DD.log.
On date rollover, erases the *Messages* buffer before writing to prevent
old content from bleeding into the new day's file.
Called via post-command-hook after every emacsclient invocation.
Wrapped in condition-case to never crash the daemon."
  (condition-case _err
      (let* ((now (current-time))
             ;; Use UTC time consistent with existing code
             (today (format-time-string "%Y-%m-%d" now t))
             (log-dir "/var/log/sem")
             (log-path (format "%s/messages-%s.log" log-dir today)))

        ;; Check for date rollover - if new day, erase buffer first
        (when (and (not (string-empty-p sem-core--last-flush-date))
                   (not (string= today sem-core--last-flush-date)))
          ;; Date has changed - erase *Messages* buffer before writing
          (with-current-buffer "*Messages*"
            (erase-buffer)))

        ;; Get current buffer content (may be empty after erase)
        (let ((content (with-current-buffer "*Messages*"
                         (buffer-string))))

          ;; Ensure log directory exists
          (make-directory log-dir t)

          ;; Write content in append mode (t = append)
          (write-region content nil log-path t 'silent))

        ;; Update last flush date after successful write
        (setq sem-core--last-flush-date today))
    (error nil)))

;;; Cursor Tracking

(defun sem-core--read-cursor ()
  "Read the cursor file and return an alist of headline hashes.
Returns nil if file doesn't exist or is empty."
  (let ((cursor-file sem-core-cursor-file))
    (if (file-exists-p cursor-file)
        (with-temp-buffer
          (insert-file-contents cursor-file)
          (goto-char (point-min))
          (condition-case nil
              (let ((content (read (current-buffer))))
                (when (listp content)
                  (cl-remove-if-not (lambda (entry)
                                      (and (consp entry) (stringp (car entry))))
                                    content)))
            (end-of-file nil)
            (error nil)))
      nil)))

(defun sem-core--write-cursor (cursor-alist)
  "Write CURSOR-ALIST to the cursor file.
Uses atomic write via temp file and rename."
  (let* ((cursor-file sem-core-cursor-file)
         (tmp-file (concat cursor-file ".tmp")))
    (make-directory (file-name-directory cursor-file) t)
    (with-temp-file tmp-file
      (insert "(")
      (dolist (entry cursor-alist)
        (insert "\n  (\"" (car entry) "\" . t)"))
      (insert "\n)\n"))
    (rename-file tmp-file cursor-file t)))

(defun sem-core--compute-headline-hash (headline)
  "Compute a content hash for HEADLINE.
Uses the headline title and properties for deterministic hashing."
  (let ((title (or (plist-get headline :title) ""))
        (tags (or (string-join (plist-get headline :tags) ":") "")))
    (secure-hash 'sha256 (concat title "|" tags))))

(defun sem-core--mark-processed (hash)
  "Mark a headline HASH as processed in the cursor file.
If HASH is nil, this is a no-op (for RSS digest which has no per-entry tracking)."
  (when hash
    (let ((cursor (sem-core--read-cursor)))
      (unless (assoc hash cursor)
        (push (cons hash t) cursor))
      (sem-core--write-cursor cursor))))

(defun sem-core--is-processed (hash)
  "Check if a headline HASH is already processed."
  (let ((cursor (sem-core--read-cursor)))
    (when (assoc hash cursor) t)))

;;; Retry Tracking

(defun sem-core--read-retries ()
  "Read the retries file and return an alist of (hash . count).
Returns nil if file doesn't exist or is empty."
  (let ((retries-file sem-core-retries-file))
    (if (file-exists-p retries-file)
        (with-temp-buffer
          (insert-file-contents retries-file)
          (goto-char (point-min))
          (condition-case nil
              (let ((content (read (current-buffer))))
                (when (listp content)
                  (cl-remove-if-not (lambda (entry)
                                      (and (consp entry) 
                                           (stringp (car entry))
                                           (numberp (cdr entry))))
                                    content)))
            (end-of-file nil)
            (error nil)))
      nil)))

(defun sem-core--write-retries (retries-alist)
  "Write RETRIES-ALIST to the retries file.
Uses atomic write via temp file and rename."
  (let* ((retries-file sem-core-retries-file)
         (tmp-file (concat retries-file ".tmp")))
    (make-directory (file-name-directory retries-file) t)
    (with-temp-file tmp-file
      (insert "(")
      (dolist (entry retries-alist)
        (insert "\n  (\"" (car entry) "\" . " (number-to-string (cdr entry)) ")"))
      (insert "\n)\n"))
    (rename-file tmp-file retries-file t)))

(defun sem-core--get-retry-count (hash)
  "Get the retry count for HASH.
Returns 0 if hash has no recorded retries."
  (when hash
    (let ((retries (sem-core--read-retries)))
      (or (cdr (assoc hash retries)) 0))))

(defun sem-core--increment-retry (hash)
  "Increment the retry count for HASH.
Returns the new retry count."
  (when hash
    (let* ((retries (sem-core--read-retries))
           (current (or (cdr (assoc hash retries)) 0))
           (new-count (1+ current)))
      ;; Remove old entry if exists
      (setq retries (cl-remove hash retries :key #'car :test #'equal))
      ;; Add new entry
      (push (cons hash new-count) retries)
      ;; Write back
      (sem-core--write-retries retries)
      new-count)))

(defun sem-core--clear-retry (hash)
  "Clear the retry count for HASH.
Call this when an item succeeds or is moved to DLQ."
  (when hash
    (let ((retries (sem-core--read-retries)))
      (setq retries (cl-remove hash retries :key #'car :test #'equal))
      (sem-core--write-retries retries))))

(defun sem-core--should-retry-p (hash)
  "Check if HASH should be retried.
Returns t if retry count is less than max (3), nil otherwise."
  (when hash
    (let ((count (sem-core--get-retry-count hash)))
      (< count 3))))

(defun sem-core--mark-dlq (hash &optional title response)
  "Mark HASH as moved to DLQ (Dead Letter Queue).
Clears retry count and optionally logs to errors.org.
TITLE and RESPONSE are optional for error logging."
  (when hash
    ;; Clear retry count
    (sem-core--clear-retry hash)
    ;; Mark as processed so it's not retried
    (sem-core--mark-processed hash)
    ;; Log to errors.org if title provided
    (when title
      (sem-core-log-error "core" "INBOX-ITEM"
                          (format "Moved to DLQ after 3 retries: %s" title)
                          title
                          response))))

;;; Inbox Processing Entry Point

(defun sem-core--cleanup-stale-temp-files ()
  "Remove stale tasks-tmp-*.org files older than 24 hours.
Called at startup and after each batch to clean up orphaned temp files.
Never crashes - errors are silently ignored."
  (ignore-errors
    (let ((tmp-dir "/tmp/data")
          (cutoff-time (- (float-time) (* 24 60 60))))
      (when (file-directory-p tmp-dir)
        (dolist (file (directory-files tmp-dir t "tasks-tmp-.*\\.org$"))
          (when (and (file-regular-p file)
                     (> cutoff-time (float-time (nth 5 (file-attributes file 'string)))))
            (message "SEM: Cleaning up stale temp file: %s" file)
            (delete-file file)))))))

(defun sem-core-process-inbox ()
  "Cron entry point for inbox processing.
Reads unprocessed headlines from inbox-mobile.org and routes them
to the appropriate handler (url-capture or LLM task generation).
Initializes batch state for tracking callbacks and triggering planning step."
  (condition-case err
      (progn
        (message "SEM: sem-core-process-inbox called")
        (sem-core--cleanup-stale-temp-files)
        (setq sem-core--batch-id (1+ sem-core--batch-id))
        (setq sem-core--pending-callbacks 0)
        (sem-core--start-batch-watchdog)
        (when (fboundp 'sem-router-process-inbox)
          (message "SEM: Calling sem-router-process-inbox...")
          (sem-router-process-inbox)
          (message "SEM: sem-router-process-inbox returned"))
        (when (= sem-core--pending-callbacks 0)
          (sem-core--cancel-batch-watchdog)
          (message "SEM: No pending callbacks, firing planning step immediately")
          (when (fboundp 'sem-planner-run-planning-step)
            (sem-planner-run-planning-step)))
        (message "SEM: sem-core-process-inbox done"))
    (error
     (sem-core-log-error "core" "INBOX-ITEM" (error-message-string err) nil)
     (message "SEM: Inbox processing error: %s" (error-message-string err)))))

;;; Inbox Purge

(defun sem-core-purge-inbox ()
  "Atomic purge of processed headlines from inbox-mobile.org.
Only runs at 4AM window. Uses temp file + rename-file for atomicity.
Hash computation matches sem-router--parse-headlines format:
(concat title \"|\" space-joined-tags \"|\" body)"
  (condition-case err
      (let* ((inbox-file sem-core-inbox-file)
             (tmp-file (concat inbox-file ".purge.tmp"))
             (cursor (sem-core--read-cursor))
             (purged-count 0)
             (hour (string-to-number (format-time-string "%H"))))
        ;; Check if we're in the 4AM window (04:00-04:59)
        (cond
         ;; Not 4AM - skip purge
         ((/= hour 4)
          (sem-core-log "purge" "PURGE" "SKIP" "Not in 4AM window")
          (message "SEM: Purge only runs at 4AM, current hour: %d" hour))
         ;; 4AM but file doesn't exist - skip
         ((not (file-exists-p inbox-file))
          (sem-core-log "purge" "PURGE" "SKIP" "inbox-mobile.org does not exist")
          (message "SEM: inbox-mobile.org does not exist, nothing to purge"))
         ;; 4AM and file exists - do purge
         (t
          ;; Read inbox and filter out processed headlines
          ;; Use org-element parsing for consistent body extraction with sem-router
          (require 'sem-router)
          (let ((keep-headlines '()))
            (with-temp-buffer
              (insert-file-contents inbox-file)
              (org-mode)
              (let ((ast (org-element-parse-buffer)))
                (org-element-map ast 'headline
                  (lambda (headline-element)
                    (let* ((title (org-element-property :raw-value headline-element))
                           (tags (org-element-property :tags headline-element))
                           (body (sem-router--extract-headline-body headline-element))
                           (tags-str (if tags (string-join tags " ") ""))
                           (body-str (or body ""))
                           (hash (secure-hash 'sha256
                                              (concat title "|" tags-str "|" body-str))))
                      (if (sem-core--is-processed hash)
                          (setq purged-count (1+ purged-count))
                        ;; Keep the headline subtree in the inbox
                        (let ((begin (org-element-property :begin headline-element))
                              (end (org-element-property :end headline-element)))
                          (push (buffer-substring-no-properties begin end)
                                keep-headlines)))))))
            ;; Write purged content to temp file - preserve full subtrees
            (with-temp-file tmp-file
              (dolist (subtree (nreverse keep-headlines))
                (insert subtree)
                (insert "\n"))))
            ;; Atomic rename
            (rename-file tmp-file inbox-file t)
            (sem-core-log "purge" "PURGE" "OK" (format "Removed %d nodes from inbox-mobile.org" purged-count))
            (message "SEM: Purged %d processed headlines" purged-count)))))
    (error (message "SEM: Purge error: %s" (error-message-string err)))))

(provide 'sem-core)
;;; sem-core.el ends here
