;;; sem-url-capture.el --- URL capture for org-roam with LLM assistance -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; This module provides automated web article capture and integration into
;; org-roam. Ported from org-roam-url-catcher.el with all interactive
;; patterns stripped and replaced with non-interactive daemon-safe equivalents.
;;
;; The pipeline:
;; 1. Fetch URL content using trafilatura CLI
;; 2. Sanitize text for token efficiency
;; 3. Extract metadata (umbrella nodes) from org-roam database
;; 4. Build prompts for LLM
;; 5. Request LLM to generate org-roam node content
;; 6. Validate and save the generated content
;;
;; Entry point: sem-url-capture-process (callable from sem-router.el)

;;; Code:

(require 'org)
(require 'org-roam)
(require 'org-id)
(require 'sem-core)
(require 'sem-llm)

;;; Constants

(defconst sem-url-capture-max-chars 40000
  "Maximum number of characters to send to LLM after sanitization.")

(defconst sem-url-capture-umbrella-tag "umbrella"
  "Tag used to identify umbrella (semantic hub) nodes in org-roam.")

;;; URL Fetching

(defun sem-url-capture--fetch-url (url)
  "Fetch content from URL using trafilatura CLI.

Uses `trafilatura -u URL --markdown --no-comments --fast` to extract
readable content. Returns the raw markdown string on success, or nil
on failure.

Signals an error if trafilatura binary is not found."
  (unless (executable-find "trafilatura")
    (error "URL Catcher: trafilatura binary not found in PATH"))

  (let ((temp-buffer (generate-new-buffer " *trafilatura-temp*")))
    (unwind-protect
        (let ((exit-code
               (with-current-buffer temp-buffer
                 (call-process "trafilatura" nil temp-buffer nil
                               "-u" url "--markdown" "--no-comments" "--fast"))))
          (if (and (numberp exit-code) (= exit-code 0))
              (with-current-buffer temp-buffer
                (buffer-substring-no-properties (point-min) (point-max)))
            (sem-core-log "url-capture" "URL-CAPTURE" "RETRY"
                          (format "trafilatura failed exit=%d" exit-code)
                          nil)
            nil))
      (when (buffer-live-p temp-buffer)
        (kill-buffer temp-buffer)))))

;;; Text Sanitization

(defun sem-url-capture--sanitize-text (raw-text)
  "Aggressively sanitize RAW-TEXT for maximum token efficiency.

Applies the following pipeline in order:
1. Remove lines containing only digits (e.g., code block line numbers).
2. Remove lines containing exactly one non-whitespace character.
3. Replace all newlines with a single space.
4. Replace multiple spaces/tabs with a single space.
5. Trim leading and trailing whitespace.
6. Truncate to `sem-url-capture-max-chars` limit.

Returns the sanitized string."
  (if (not raw-text)
      ""
    (let ((text raw-text))
      ;; Remove lines containing only digits
      (setq text (replace-regexp-in-string "^[ \t]*[0-9]+[ \t]*\n" "" text))
      ;; Remove lines containing exactly one non-whitespace character
      (setq text (replace-regexp-in-string "^[ \t]*[^ \t\n][ \t]*\n" "" text))
      ;; Replace all newlines with a single space
      (setq text (replace-regexp-in-string "\n" " " text))
      ;; Replace multiple spaces/tabs with a single space
      (setq text (replace-regexp-in-string "[ \t]+" " " text))
      ;; Trim leading and trailing whitespace
      (setq text (string-trim text))
      ;; Truncate to max chars limit
      (when (> (length text) sem-url-capture-max-chars)
        (setq text (substring text 0 sem-url-capture-max-chars)))
      text)))

;;; Metadata Extraction

(defun sem-url-capture--get-umbrella-nodes ()
  "Query org-roam database for nodes tagged with `sem-url-capture-umbrella-tag`.

Returns an alist mapping node titles to their UUIDs (IDs).
Returns nil if no umbrella nodes exist or on database error."
  (condition-case err
      (let ((rows (org-roam-db-query
                   [:select [nodes:title nodes:id]
                    :from nodes
                    :inner-join tags :on (= nodes:id tags:node_id)
                    :where (= tags:tag $s1)]
                   sem-url-capture-umbrella-tag)))
        (when rows
          (mapcar (lambda (row) (cons (car row) (cadr row))) rows)))
    (error
     (sem-core-log "url-capture" "URL-CAPTURE" "FAIL"
                   (format "Failed to query umbrella nodes: %s"
                           (error-message-string err))
                   nil)
     nil)))

;;; Prompt Generation

(defun sem-url-capture--build-system-prompt ()
  "Build the system prompt for LLM org-roam node generation.
Includes a comprehensive org-mode syntax cheat sheet to prevent markdown hallucinations."
  "You are a specialized Knowledge Management assistant. Your ONLY task is to output valid, raw `org-roam` node text based on the provided article.

CRITICAL REQUIREMENT: YOU MUST USE STRICT ORG-MODE SYNTAX. ABSOLUTELY NO MARKDOWN.

=== ORG-MODE SYNTAX CHEAT SHEET ===
- Headings: Use asterisks `* Heading 1`, `** Heading 2` (NEVER use `# Heading`).
- Bold: `*bold text*` (NEVER use `**bold**`).
- Italic: `/italic text/` (NEVER use `*italic*` or `_italic_`).
- Underline: `_underlined text_`.
- Strikethrough: `+strikethrough+` (NEVER use `~~strike~~`).
- Inline code: `=code=` or `~verbatim~` (NEVER use backticks ` ` `).
- Code blocks:
  #+begin_src language
  // code here
  #+end_src
  (NEVER use ```language ... ```).
- Blockquotes:
  #+begin_quote
  Quoted text here.
  #+end_quote
  (NEVER use `> quote`).
- External Links: `[[https://example.com][Link description]]` (NEVER use `[desc](url)`).
- Lists: Use `-` or `+` for unordered, and `1.` for ordered.

=== RULES FOR THIS TASK ===
1. NEVER wrap your overall response in markdown code blocks (e.g., do NOT start with ```org). Output raw text only.
2. At the very top, include a property drawer with the provided ID.
3. Below the property drawer, include:
   `#+title: <Article Title>`
   `#+ROAM_REFS: <Original URL>`
   `#+filetags: :article:`
4. Write a brief summary and bullet points extracting the core value of the article.
5. Link to the provided Umbrella Nodes IF AND ONLY IF highly relevant. Use exact IDs provided: `[[id:GIVEN-ID][Title]]`.
6. Structure the note with `* Summary` and `* Key Takeaways` sections.
7. The first line of the `* Summary` section MUST be: `Source: [[ARTICLE_URL][ARTICLE_URL]]`")

(defun sem-url-capture--make-slug (title)
  "Generate a URL-safe slug from TITLE for filename generation.

1. Downcase the title
2. Strip non-ASCII and non-alphanumeric characters (replace with `-`)
3. Trim leading/trailing hyphens
4. Truncate to 50 characters maximum

Returns the slug string."
  (let ((slug (downcase title)))
    ;; Strip non-ASCII and non-alphanumeric, replace with hyphen
    (setq slug (replace-regexp-in-string "[^a-z0-9]+" "-" slug))
    ;; Trim leading/trailing hyphens
    (setq slug (string-trim slug "\\`-+" "-+\\'"))
    ;; Truncate to 50 characters
    (when (> (length slug) 50)
      (setq slug (substring slug 0 50))
      ;; Trim again after truncation in case we cut off mid-word
      (setq slug (string-trim slug "-")))
    slug))

(defun sem-url-capture--build-user-prompt (url sanitized-text umbrella-nodes-alist)
  "Build the user prompt for LLM org-roam node generation.

URL is the original article URL.
SANITIZED-TEXT is the cleaned article content.
UMBRELLA-NODES-ALIST is an alist of (title . id) for semantic hubs.

Generates a new org-roam ID and includes it in the expected format section."
  (let ((new-id (org-id-new))
        (umbrella-section ""))

    ;; Build umbrella nodes mapping section if available
    (when (and umbrella-nodes-alist (not (null umbrella-nodes-alist)))
      (setq umbrella-section
            (concat "UMBRELLA NODES MAP:\n"
                    (mapconcat
                     (lambda (node)
                       (format "  - %s: [[id:%s][%s]]" (car node) (cdr node) (car node)))
                     umbrella-nodes-alist
                     "\n")
                    "\n\n")))

    (concat umbrella-section
            "ARTICLE URL: " url "\n\n"
            "ARTICLE CONTENT:\n" sanitized-text "\n\n"
            "EXPECTED OUTPUT FORMAT:\n"
            ":PROPERTIES:\n"
            ":ID:          " new-id "\n"
            ":END:\n"
            "#+title: <Article Title>\n"
            "#+ROAM_REFS: " url "\n"
            "#+filetags: :article:\n\n"
            "* Summary\n"
            "Source: [[" url "][" url "]]\n"
            "<Brief summary of the article>\n\n"
            "* Key Takeaways\n"
            "- <Key point 1>\n"
            "- <Key point 2>\n"
            "- <Key point 3>\n\n"
            "* Notes\n"
            "<Detailed notes with links to umbrella nodes if relevant>\n\n"
            "Generate the complete org-roam node following this format.")))

;;; Validation and Save

(defun sem-url-capture--validate-and-save (llm-response url)
  "Validate LLM-RESPONSE and save as org-roam node.

URL is the original article URL for error reporting.

Validation steps:
1. Write to temporary buffer
2. Strip hallucinated markdown code blocks
3. Validate presence of :PROPERTIES:, :ID:, and #+title:
4. Extract title and generate slug
5. Write to org-roam-directory with timestamp-slug.org name
6. Invoke org-roam-db-sync
7. Kill temporary buffer

Returns the filepath on success, nil on validation failure."
  (cl-block sem-url-capture--validate-and-save
    (let ((temp-buf (generate-new-buffer " *url-capture-validate*"))
          (filepath nil))
      (unwind-protect
        (progn
          ;; Write response to temporary buffer
          (with-current-buffer temp-buf
            (insert llm-response)
            (goto-char (point-min))

            ;; Strip hallucinated markdown code blocks
            (while (re-search-forward "```org\n\\|```\n\\|```$" nil t)
              (replace-match ""))
            (goto-char (point-min))

            ;; Validate required elements
            (let ((has-properties (re-search-forward "^:PROPERTIES:" nil t))
                  (has-id (re-search-forward "^:ID:" nil t))
                  (has-title (progn
                               (goto-char (point-min))
                               (re-search-forward "^#\\+title:\\s-+" nil t))))
              (unless (and has-properties has-id has-title)
                (sem-core-log-error "url-capture" "URL-CAPTURE"
                                    (format "Missing required elements: props=%s, id=%s, title=%s"
                                            has-properties has-id has-title)
                                    llm-response
                                    llm-response)
                (cl-return-from sem-url-capture--validate-and-save nil)))

            ;; Extract title for slug generation
            (goto-char (point-min))
            (if (re-search-forward "^#\\+title:\\s-+\\(.+\\)$" nil t)
                (let* ((title (match-string 1))
                       (slug (sem-url-capture--make-slug title))
                       (timestamp (format-time-string "%Y%m%d%H%M%S"))
                       (filename (format "%s-%s.org" timestamp slug))
                       (fpath (expand-file-name filename org-roam-directory))
                       (content (buffer-string)))

                  ;; Write to org-roam-directory
                  (with-temp-file fpath
                    (insert content))

                  ;; Sync database
                  (org-roam-db-sync)

                  (sem-core-log "url-capture" "URL-CAPTURE" "OK"
                                (format "Successfully saved node to %s" fpath)
                                nil)
                  (setq filepath fpath))
              (sem-core-log-error "url-capture" "URL-CAPTURE"
                                  "Could not extract title from #+title:"
                                  llm-response
                                  llm-response)
              nil)))
      (when (buffer-live-p temp-buf)
        (kill-buffer temp-buf)))
    filepath)))

;;; Non-Interactive Entry Point

(defun sem-url-capture-process (url)
  "Fetch URL content and create an org-roam node via LLM.

URL is the original article URL.

This is the non-interactive entry point callable from sem-router.el.
It orchestrates the full pipeline:
1. Fetch content using trafilatura
2. Sanitize text for token efficiency
3. Extract umbrella nodes from org-roam database
4. Build prompts for LLM
5. Request LLM to generate org-roam node via sem-llm-request
6. Validate and save the result

Returns the saved filepath on success, nil on any failure.
Errors are logged to /data/errors.org."
  (condition-case err
      (progn
        (sem-core-log "url-capture" "URL-CAPTURE" "OK"
                      (format "Processing URL: %s" url)
                      nil)

        ;; Fetch URL content
        (let ((raw-content (sem-url-capture--fetch-url url)))
          (if raw-content
              (let* ((sanitized (sem-url-capture--sanitize-text raw-content))
                     (umbrella-nodes (sem-url-capture--get-umbrella-nodes))
                     (system-prompt (sem-url-capture--build-system-prompt))
                     (user-prompt (sem-url-capture--build-user-prompt url sanitized umbrella-nodes))
                     (result nil))

                ;; Request LLM via sem-llm-request with callback
                (require 'sem-llm)
                (let ((done nil))
                  (sem-llm-request user-prompt system-prompt
                                   (lambda (response info context)
                                     "Callback for sem-llm-request.
Calls sem-url-capture--validate-and-save with the response."
                                     (if (and response (not (string-empty-p response)))
                                         (setq result (sem-url-capture--validate-and-save response url))
                                       (progn
                                         (sem-core-log-error "url-capture" "URL-CAPTURE"
                                                             (format "LLM request failed: %s"
                                                                     (plist-get info :error))
                                                             url
                                                             response)
                                         (setq result nil)))
                                     (setq done t))
                                   nil)
                  
                  ;; Wait for callback to complete (synchronous for now)
                  ;; TODO: Convert to async when sem-llm is fully integrated
                  (while (not done)
                    (sit-for 0.1)))
                
                result)
            (sem-core-log-error "url-capture" "URL-CAPTURE"
                                "Failed to fetch content"
                                url
                                nil)
            nil)))
    (error
     (sem-core-log-error "url-capture" "URL-CAPTURE"
                         (error-message-string err)
                         url
                         nil)
     nil)))

(provide 'sem-url-capture)
;;; sem-url-capture.el ends here
