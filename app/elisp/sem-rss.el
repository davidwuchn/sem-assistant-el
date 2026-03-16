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
  (format "Analyze the following RSS entries from the last %d days.
Target Audience: Senior Software Engineer.
Language: Russian.
Output Format: Org-mode.

CRITICAL OUTPUT RULES:
- Return ONLY raw Org-mode text. No markdown, no code fences (no ``` symbols), no reasoning, no explanations before or after.
- Start your response directly with the first Org-mode heading.
- Do not wrap the output in any block or container.

Task:
1. Group articles by categories: %s.
2. Structure:
   * 🚀 Главное за %d дней (Executive Summary — 3-5 sentences overview of the period)
   * 📂 Категории
     ** Category Name
        - [[Link][Title]] (Source) - 1 concise sentence summary.
        *** 💎 Топ-3 категории (Top 3 most interesting reads in this category)
            **** [[Link][Title]]
                 :SCORE: X/10
                 :WHY: Brief reasoning why this is a must-read.
3. Every category MUST have its own 💎 Топ-3 subsection with exactly 3 entries (or fewer if the category has less than 3 articles).
4. Follow ORG-mode convention strictly: * -- top-level header, ** -- second level, *** -- third level, **** -- fourth level.
5. Result must be valid Org-mode, optimized for human reading.

Data:
%s"
          days
          (mapconcat #'cdr sem-rss-categories ", ")
          days
          (sem-rss--build-entries-text entries)))

(defun sem-rss--build-arxiv-prompt (entries days)
  "Build prompt for arXiv digest.
ENTRIES is the list of entry plists.
DAYS is the number of days the digest covers."
  (format "You are a Research Assistant monitoring Arxiv preprints.
Target Audience: Graph & Data Systems Researcher.
Language: Russian.
Output Format: Org-mode.

Context: The user is interested in Databases, Distributed Systems, and Graph Algorithms/Networks.

Task:
1. Group papers by Arxiv categories: %s.
2. For EACH Category, generate a report with specific subsections (if applicable):

   ** Category Name (e.g. cs.DB)
      *** 🧐 Обзор (Overview of last %d days trend)
      *** 🛠 Практика и Системы (New DBs, DistSys, Optimizations)
          - [[Link][Title]]
            :WHAT: What they built/optimized.
            :IMPACT: Practical value.
      *** 🕸 Графы и Алгоритмы (Graph Algorithms, GNNs, Network Analysis)
          - [[Link][Title]]
            :ALGO: Key algorithmic contribution.
      *** 📄 Остальное (Brief list)
          - [[Link][Title]] - One sentence summary.

3. Ignore purely theoretical papers unless they have clear system applications or graph algorithm breakthroughs.
4. Follow ORG-mode convention: * -- top-level header (Category Name), ** -- sub-header (Обзор, Графы, etc.)
5. Result should be org-mode formatted and optimized for reading by human.

Data:
%s"
          (mapconcat #'cdr sem-rss-arxiv-categories ", ")
          days
          (sem-rss--build-entries-text entries)))

;;; File Generation

(defun sem-rss--generate-file (target-path prompt title-prefix days)
  "Call LLM and write digest to TARGET-PATH.

PROMPT is the LLM prompt.
TITLE-PREFIX is the title prefix (e.g., \"Daily Digest\" or \"Arxiv Digest\").
DAYS is the number of days the digest covers."
  (let* ((days-int (truncate days))
         ;; Compute date range
         (from-date (time-subtract (current-time) (days-to-time days-int)))
         (to-date (current-time))
         (from-org (format-time-string "[%Y-%m-%d %a]" from-date))
         (to-org (format-time-string "[%Y-%m-%d %a]" to-date)))

    (require 'gptel)
    (gptel-request prompt
      :system "You are a helpful Technical Editor assistant. You output ONLY raw Org-mode text. Never use markdown code fences or any wrapper syntax. Never include reasoning or commentary outside of the requested Org-mode structure. Start your response directly with the first Org-mode heading."
      :callback (lambda (response info)
                  (if (not response)
                      (sem-core-log-error "rss" "RSS-DIGEST"
                                          (format "LLM Error: %s" (plist-get info :status))
                                          prompt
                                          nil)
                    ;; Write to file
                    (with-temp-file target-path
                      (insert "#+TITLE: " title-prefix ": " (format-time-string "%Y-%m-%d") "\n")
                      (insert "#+FROM: " from-org "\n")
                      (insert "#+TO: " to-org "\n")
                      (insert "#+DATE: " (format-time-string "[%Y-%m-%d %a]") "\n")
                      (insert "#+STARTUP: showall\n\n")
                      (insert response))
                    (sem-core-log "rss"
                                  (if (string-prefix-p "Arxiv" title-prefix) "ARXIV-DIGEST" "RSS-DIGEST")
                                  "OK"
                                  (format "Digest written to %s" target-path)
                                  nil))))))

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
