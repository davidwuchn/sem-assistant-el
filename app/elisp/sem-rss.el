;;; sem-rss.el --- RSS digest generation via LLM -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; This module generates daily RSS/arXiv digests via LLM.
;; Ported from tools-rss.el with all interactive patterns stripped.
;; Configuration is via environment variables, not defcustom.

;;; Code:

(require 'seq)
(require 'subr-x)
(require 'elfeed)
(require 'elfeed-org)
(require 'sem-core)
(require 'sem-llm)

;;; Configuration (from environment variables)

(defconst sem-rss-max-entries-per-feed
  (or (when-let ((val (getenv "RSS_MAX_ENTRIES_PER_FEED")))
        (string-to-number val))
      10)
  "Maximum number of entries per feed. Read from RSS_MAX_ENTRIES_PER_FEED.")

(defconst sem-rss-max-input-chars
  (or (when-let ((val (getenv "RSS_MAX_INPUT_CHARS")))
        (string-to-number val))
      199000)
  "Maximum input characters for LLM. Read from RSS_MAX_INPUT_CHARS.")

(defconst sem-rss-dir "/data/morning-read/"
  "Directory where daily digests are stored.")

(defconst sem-rss-model
  (or (when-let ((val (getenv "OPENROUTER_MODEL")))
        (intern val))
      'gptel-default)
  "Model to use for summarization. Read from OPENROUTER_MODEL.")

;;; Prompt Templates (loaded from external files)

(defvar sem-rss-prompts-dir nil
  "Directory containing prompt template files.
If nil, defaults to /data/prompts/ or SEM_PROMPTS_DIR env var.
Set this before loading sem-rss to override the default location.")

(defun sem-rss--get-prompts-dir ()
  "Get the prompts directory.
Uses sem-rss-prompts-dir if set, otherwise SEM_PROMPTS_DIR env var,
or defaults to /data/prompts/."
  (or sem-rss-prompts-dir
      (getenv "SEM_PROMPTS_DIR")
      "/data/prompts/"))

(defvar sem-rss-general-prompt-template nil
  "Template for general RSS digest prompts.
Loaded from general-prompt.txt at module load time.")

(defvar sem-rss-arxiv-prompt-template nil
  "Template for arXiv digest prompts.
Loaded from arxiv-prompt.txt at module load time.")

(defun sem-rss--load-prompt-template (file-path var-name)
  "Load prompt template from FILE-PPATH into variable VAR-NAME.
Signals an error if the file is missing or empty."
  (let ((content nil))
    (with-temp-buffer
      (condition-case err
          (progn
            (insert-file-contents file-path)
            (setq content (string-trim (buffer-string)))
            (when (or (null content) (string-empty-p content))
              (error "Prompt file %s is empty" file-path)))
        (file-missing
         (error "Required prompt file missing: %s" file-path))
        (error
         (error "Failed to load prompt file %s: %s" file-path (error-message-string err)))))
    content))

;; Load prompt templates at module load time
(setq sem-rss-general-prompt-template
      (sem-rss--load-prompt-template
       (expand-file-name "general-prompt.txt" (sem-rss--get-prompts-dir))
       "sem-rss-general-prompt-template"))

(setq sem-rss-arxiv-prompt-template
      (sem-rss--load-prompt-template
       (expand-file-name "arxiv-prompt.txt" (sem-rss--get-prompts-dir))
       "sem-rss-arxiv-prompt-template"))

;;; Category Mappings

(defconst sem-rss-categories
  '(("dataengineering" . "Data Engineering")
    ("engineers" . "Engineers")
    ("vendors" . "Vendors")
    ("opensource" . "Open Source")
    ("ai" . "Artificial Intelligence")
    ("nonengineering" . "Non Engineering"))
  "Mapping of Elfeed tags to Digest Sections (General).")

(defconst sem-rss-arxiv-categories
  '(("csdb" . "cs.DB (Databases)")
    ("csai" . "cs.AI (Artificial Intelligence)")
    ("socph" . "physics.soc-ph (Social Physics & Networks)")
    ("csds" . "cs.DS (Data Structures & Algorithms)")
    ("csdc" . "cs.DC (Distributed Computing)"))
  "Mapping of Arxiv tags to Digest Sections.")

;;; Text Cleaning

(defun sem-rss--clean-text (html)
  "Aggressively strip HTML to save tokens."
  (when html
    (with-temp-buffer
      (insert html)
      (goto-char (point-min))
      ;; Remove script and style blocks
      (while (re-search-forward "<\\(script\\|style\\)[^>]*>\\([\\s\\S]*?\\)</\\1>" nil t)
        (replace-match " " nil nil))
      ;; Remove all HTML tags
      (goto-char (point-min))
      (while (re-search-forward "<[^>]+>" nil t)
        (replace-match " " nil nil))
      ;; Replace HTML entities (order matters: &amp; must be last)
      (goto-char (point-min))
      (while (re-search-forward "&nbsp;" nil t) (replace-match " " nil nil))
      (goto-char (point-min))
      (while (re-search-forward "&lt;" nil t) (replace-match "<" nil nil))
      (goto-char (point-min))
      (while (re-search-forward "&gt;" nil t) (replace-match ">" nil nil))
      (goto-char (point-min))
      (while (re-search-forward "&quot;" nil t) (replace-match "\"" nil nil))
      (goto-char (point-min))
      (while (re-search-forward "&amp;" nil t) (replace-match "&" nil nil))
      ;; Normalize whitespace
      (goto-char (point-min))
      (while (re-search-forward "[[:space:]\n\r]+" nil t)
        (replace-match " " nil nil))
      (let ((text (string-trim (buffer-string))))
        ;; Truncate if too long
        (if (> (length text) 3000)
            (concat (substring text 0 3000) "...")
          text)))))

;;; Entry Collection

(defun sem-rss-collect-entries (filter-fn days)
  "Fetch entries from last DAYS days.

FILTER-FN is a function that takes a list of tag strings and
returns non-nil if entry should be kept.

Returns a list of entry plists."
  (let* ((days-int (truncate days))
         (since-time (time-subtract (current-time) (days-to-time days-int)))
         (raw-entries '()))
    (elfeed-db-ensure)

    (with-elfeed-db-visit (entry feed)
      (let ((date (elfeed-entry-date entry)))
        (when (time-less-p since-time (seconds-to-time date))
          (let* ((all-tags (mapcar #'symbol-name (elfeed-entry-tags entry)))
                 ;; Remove system tags
                 (tags (seq-remove (lambda (tag)
                                     (member tag '("unread" "starred")))
                                   all-tags)))

            ;; Apply filter BEFORE heavy text processing
            (when (funcall filter-fn tags)
              (let* ((title (elfeed-entry-title entry))
                     (link (elfeed-entry-link entry))
                     (feed-title (elfeed-feed-title feed))
                     (content-raw (elfeed-deref (elfeed-entry-content entry)))
                     (content (sem-rss--clean-text content-raw)))
                (push (list :title title
                            :link link
                            :feed feed-title
                            :date date
                            :tags tags
                            :content content)
                      raw-entries)))))))

    ;; Group by feed and apply per-feed limits
    (thread-last raw-entries
                 (seq-group-by (lambda (x) (plist-get x :feed)))
                 (mapcan (lambda (group)
                           (let* ((entries (cdr group))
                                  (sorted (seq-sort-by (lambda (x) (plist-get x :date)) #'> entries)))
                             (seq-take sorted sem-rss-max-entries-per-feed)))))))

;;; Entry Formatting

(defun sem-rss--format-entry-for-llm (entry)
  "Format an ENTRY plist for LLM input."
  (format "Title: %s\nLink: %s\nTags: %s\nAbstract/Content: %s\n---\n"
          (plist-get entry :title)
          (plist-get entry :link)
          (string-join (plist-get entry :tags) ", ")
          (or (plist-get entry :content) "No content")))

(defun sem-rss--build-entries-text (entries)
  "Build the entries text for LLM input.
Truncates to `sem-rss-max-input-chars' if needed."
  (let* ((entries-text (mapconcat #'sem-rss--format-entry-for-llm entries "\n")))
    (if (> (length entries-text) sem-rss-max-input-chars)
        (substring entries-text 0 sem-rss-max-input-chars)
      entries-text)))

;;; Prompt Builders

(defun sem-rss--build-general-prompt (entries days)
  "Build prompt for general RSS digest.
ENTRIES is the list of entry plists.
DAYS is the number of days the digest covers."
  (format sem-rss-general-prompt-template
          days
          (mapconcat #'cdr sem-rss-categories ", ")
          days
          (sem-rss--build-entries-text entries)))

(defun sem-rss--build-arxiv-prompt (entries days)
  "Build prompt for arXiv digest.
ENTRIES is the list of entry plists.
DAYS is the number of days the digest covers."
  (format sem-rss-arxiv-prompt-template
          (mapconcat #'cdr sem-rss-arxiv-categories ", ")
          days
          (sem-rss--build-entries-text entries)))

;;; File Generation

(defun sem-rss--generate-file (target-path prompt title-prefix days &optional callback)
  "Call LLM and write digest to TARGET-PATH.

PROMPT is the LLM prompt.
TITLE-PREFIX is the title prefix (e.g., \"Daily Digest\" or \"Arxiv Digest\").
DAYS is the number of days the digest covers.
CALLBACK is an optional function of (success context) called when complete.
  - SUCCESS is t if file was written, nil on failure.
  - CONTEXT contains :target-path and other metadata.

Uses sem-llm-request with nil hash (no per-entry cursor tracking for RSS).
On malformed LLM output: log to errors.org, do not write file.
On API error: log to errors.org with RETRY status, do not write file.

Returns immediately (async). The CALLBACK is invoked when complete."
  (let* ((days-int (truncate days))
         ;; Compute date range
         (from-date (time-subtract (current-time) (days-to-time days-int)))
         (to-date (current-time))
         (from-org (format-time-string "[%Y-%m-%d %a]" from-date))
         (to-org (format-time-string "[%Y-%m-%d %a]" to-date))
         (system-prompt "You are a helpful Technical Editor assistant. You output ONLY raw Org-mode text. Never use markdown code fences or any wrapper syntax. Never include reasoning or commentary outside of the requested Org-mode structure. Start your response directly with the first Org-mode heading."))

    ;; Use sem-llm-request instead of direct gptel-request
    (require 'sem-llm)
    (sem-llm-request prompt system-prompt
                     (lambda (response info context)
                       "Callback for sem-llm-request in RSS digest.
Handles API errors (RETRY) and malformed output (DLQ)."
                       (let ((target (plist-get context :target-path))
                             (title (plist-get context :title-prefix))
                             (from (plist-get context :from-org))
                             (to (plist-get context :to-org))
                             (digest-type (if (string-prefix-p "Arxiv" (plist-get context :title-prefix))
                                              "ARXIV-DIGEST" "RSS-DIGEST"))
                             (success nil))
                         (cond
                          ;; Success - write to file
                          ((and response (not (string-empty-p response)))
                           (with-temp-file target
                             (insert "#+TITLE: " title ": " (format-time-string "%Y-%m-%d") "\n")
                             (insert "#+FROM: " from "\n")
                             (insert "#+TO: " to "\n")
                             (insert "#+DATE: " (format-time-string "[%Y-%m-%d %a]") "\n")
                             (insert "#+STARTUP: showall\n\n")
                             (insert response))
                           (sem-core-log "rss" digest-type "OK"
                                         (format "Digest written to %s" target)
                                         nil)
                           (setq success t))
                          ;; API error - log RETRY, do not write file
                          ((plist-get info :error)
                           (sem-core-log-error "rss" digest-type
                                               (format "API error: %s" (plist-get info :error))
                                               (plist-get context :prompt)
                                               nil)
                           (setq success nil))
                          ;; Malformed/empty response - log DLQ, do not write file
                          (t
                           (sem-core-log-error "rss" digest-type
                                               "Malformed or empty LLM response"
                                               (plist-get context :prompt)
                                               response)
                           (setq success nil)))
                         ;; Call the completion callback if provided
                         (when callback
                           (funcall callback success context))))
                     (list :target-path target-path :title-prefix title-prefix
                           :from-org from-org :to-org to-org :prompt prompt))

    ;; Return immediately - processing continues asynchronously
    t))

;;; Cron Entry Point

;;;###autoload
(defun sem-rss-generate-morning-digest ()
  "Generate both general and arXiv morning digests.
This is the cron entry point callable via `emacsclient -e`."
  (condition-case err
      (progn
        (sem-core-log "rss" "RSS-DIGEST" "OK" "Morning digest generation started")

        ;; Ensure output directory exists
        (make-directory sem-rss-dir t)

        ;; Generate filenames
        (let* ((date-str (format-time-string "%Y-%m-%d"))
               (general-file (expand-file-name (concat date-str ".org") sem-rss-dir))
               (arxiv-file (expand-file-name (concat date-str "-arxiv.org") sem-rss-dir))
               (days 1))  ; Always 24-hour lookback

          ;; Check if files already exist
          (if (file-exists-p general-file)
              (sem-core-log "rss" "RSS-DIGEST" "SKIP" "General digest already exists")
            ;; Generate general digest
            (let ((entries (sem-rss-collect-entries
                            (lambda (tags) (not (member "arxiv" tags)))
                            days)))
              (if (null entries)
                  (sem-core-log "rss" "RSS-DIGEST" "SKIP" "No entries found for general filter")
                (sem-core-log "rss" "RSS-DIGEST" "OK"
                              (format "Found %d entries for general digest" (length entries))
                              nil)
                (sem-rss--generate-file general-file
                                        (sem-rss--build-general-prompt entries days)
                                        "Daily Digest"
                                        days))))

          ;; Check if arxiv file already exists
          (if (file-exists-p arxiv-file)
              (sem-core-log "rss" "ARXIV-DIGEST" "SKIP" "Arxiv digest already exists")
            ;; Generate arxiv digest
            (let ((entries (sem-rss-collect-entries
                            (lambda (tags) (member "arxiv" tags))
                            days)))
              (if (null entries)
                  (sem-core-log "rss" "ARXIV-DIGEST" "SKIP" "No entries found for arxiv filter")
                (sem-core-log "rss" "ARXIV-DIGEST" "OK"
                              (format "Found %d entries for arxiv digest" (length entries))
                              nil)
                (sem-rss--generate-file arxiv-file
                                        (sem-rss--build-arxiv-prompt entries days)
                                        "Arxiv Digest"
                                        days))))))

        (sem-core-log "rss" "RSS-DIGEST" "OK" "Morning digest generation completed"))
    (error
     (sem-core-log-error "rss" "RSS-DIGEST"
                         (error-message-string err)
                         nil
                         nil)
     (message "SEM: RSS digest error: %s" (error-message-string err))))

(provide 'sem-rss)
;;; sem-rss.el ends here
