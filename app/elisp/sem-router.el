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

;;; Headline Parsing

(defun sem-router--parse-headlines ()
  "Parse all headlines from inbox-mobile.org.
Returns a list of headline plists with :title, :tags, :link, :point, :hash."
  (unless (file-exists-p sem-router-inbox-file)
    (sem-core-log "router" "INBOX-ITEM" "SKIP" "inbox-mobile.org does not exist")
    (cl-return-from sem-router--parse-headlines nil))

  (let ((headlines '()))
    (with-temp-buffer
      (insert-file-contents sem-router-inbox-file)
      (goto-char (point-min))

      (while (re-search-forward "^\\*+ " nil t)
        (let* ((start (match-beginning 0))
               (line (buffer-substring-no-properties
                      (line-beginning-position) (line-end-position)))
               (title (string-trim (substring line (match-end 0))))
               (tags (when (re-search-forward ":\\([[:word:]:]+\\):" (line-end-position) t)
                       (split-string (match-string 1) ":" t)))
               (link (when (string-match-p "^https?://" title)
                       (substring-no-properties title)))
               (hash (secure-hash 'sha256 (concat title "|" (or (string-join tags ":") "")))))

          (push (list :title title
                      :tags tags
                      :link link
                      :point start
                      :hash hash)
                headlines))))

    (nreverse headlines)))

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

(defun sem-router--route-to-task-llm (headline)
  "Route a task headline to LLM for task generation.

HEADLINE is the headline plist.

This is a placeholder - full implementation would call sem-llm
with appropriate prompts for task generation."
  (condition-case err
      (progn
        (sem-core-log "router" "INBOX-ITEM" "OK"
                      (format "Task routing: %s" (plist-get headline :title))
                      nil)
        ;; TODO: Implement full task LLM pipeline
        ;; For now, just mark as processed
        (sem-router--mark-processed (plist-get headline :hash))
        t)
    (error
     (sem-core-log-error "router" "INBOX-ITEM"
                         (error-message-string err)
                         (plist-get headline :title)
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
                 ;; Link headline -> URL capture
                 (url
                  (if (sem-router--route-to-url-capture url headline)
                      (progn
                        (sem-router--mark-processed hash)
                        (setq processed-count (1+ processed-count)))
                    (setq error-count (1+ error-count))))
                 ;; Task headline -> LLM task generation
                 ((sem-router--is-task-headline headline)
                  (if (sem-router--route-to-task-llm headline)
                      (setq processed-count (1+ processed-count))
                    (setq error-count (1+ error-count))))
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
     (message "SEM: Router error: %s" (error-message-string err)))))

(provide 'sem-router)
;;; sem-router.el ends here
