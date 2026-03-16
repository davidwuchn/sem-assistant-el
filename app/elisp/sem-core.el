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

(defun sem-core--flush-messages ()
  "Append *Messages* buffer content to the durable log file.
Called via post-command-hook after every emacsclient invocation.
Wrapped in condition-case to never crash the daemon."
  (condition-case _err
      (let ((log-path "/var/log/sem/messages.log")
            (content (with-current-buffer "*Messages*"
                       (buffer-string))))
        (make-directory "/var/log/sem" t)
        (write-region content nil log-path t 'silent))
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
  "Mark a headline HASH as processed in the cursor file."
  (let ((cursor (sem-core--read-cursor)))
    (unless (assoc hash cursor)
      (push (cons hash t) cursor))
    (sem-core--write-cursor cursor)))

(defun sem-core--is-processed (hash)
  "Check if a headline HASH is already processed."
  (let ((cursor (sem-core--read-cursor)))
    (when (assoc hash cursor) t)))

;;; Inbox Processing Entry Point

(defun sem-core-process-inbox ()
  "Cron entry point for inbox processing.
Reads unprocessed headlines from inbox-mobile.org and routes them
to the appropriate handler (url-capture or LLM task generation)."
  (condition-case err
      (progn
        (sem-core-log "core" "INBOX-ITEM" "OK" "Inbox processing started")
        ;; TODO: Implement full inbox processing logic
        ;; This will be implemented in sem-router.el
        (when (fboundp 'sem-router-process-inbox)
          (sem-router-process-inbox))
        (sem-core-log "core" "INBOX-ITEM" "OK" "Inbox processing completed"))
    (error
     (sem-core-log-error "core" "INBOX-ITEM" (error-message-string err) nil)
     (message "SEM: Inbox processing error: %s" (error-message-string err)))))

;;; Inbox Purge

(defun sem-core-purge-inbox ()
  "Atomic purge of processed headlines from inbox-mobile.org.
Only runs at 4AM window. Uses temp file + rename-file for atomicity."
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
          (with-temp-buffer
            (insert-file-contents inbox-file)
            (goto-char (point-min))

            (let ((keep-headlines '())
                  (current-headline nil)
                  (current-content ""))

              (while (not (eobp))
                (if (looking-at "^\\*+ ")
                    (progn
                      ;; Save previous headline if any
                      (when current-headline
                        (let ((hash (sem-core--compute-headline-hash current-headline)))
                          (if (sem-core--is-processed hash)
                              (setq purged-count (1+ purged-count))
                            (push current-headline keep-headlines))))
                      ;; Start new headline
                      (let ((start (point)))
                        (end-of-line)
                        (setq current-headline (buffer-substring-no-properties start (point)))))
                      (setq current-content ""))
                  (when current-headline
                    (setq current-content (concat current-content (thing-at-point 'line)))))
                (forward-line 1))

              ;; Don't forget the last headline
              (when current-headline
                (let ((hash (sem-core--compute-headline-hash current-headline)))
                  (if (sem-core--is-processed hash)
                      (setq purged-count (1+ purged-count))
                    (push current-headline keep-headlines)))))

              ;; Write purged content to temp file
              (with-temp-file tmp-file
                (dolist (headline (nreverse keep-headlines))
                  (insert headline "\n"))))

            ;; Atomic rename
            (rename-file tmp-file inbox-file t))

          (sem-core-log "purge" "PURGE" "OK" (format "Removed %d nodes from inbox-mobile.org" purged-count))
          (message "SEM: Purged %d processed headlines" purged-count)))
    (error
     (sem-core-log-error "purge" "PURGE" (error-message-string err) nil)
     (message "SEM: Purge error: %s" (error-message-string err))))

(provide 'sem-core)
;;; sem-core.el ends here
