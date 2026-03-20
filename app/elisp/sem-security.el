;;; sem-security.el --- Security masking and URL sanitization -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; This module provides security masking for sensitive content before
;; sending to LLM APIs, and URL sanitization for human-readable outputs.

;;; Code:

;;; Constants

(defconst sem-security-token-prefix "<<SENSITIVE_"
  "Prefix for sensitive content tokens.")

(defconst sem-security-token-suffix ">>"
  "Suffix for sensitive content tokens.")

;;; Sensitive Block Detection and Tokenization

(defun sem-security--detect-sensitive-blocks (text)
  "Detect all sensitive blocks in TEXT.
Returns an alist of (token . content) pairs where content includes the markers."
  (let ((blocks '())
        (counter 0))
    (with-temp-buffer
      (insert text)
      (goto-char (point-min))
      (while (re-search-forward "^[ \t]*#\\+begin_sensitive[ \t]*$" nil t)
        (let ((start (match-beginning 0)))
          (when (re-search-forward "^[ \t]*#\\+end_sensitive[ \t]*$" nil t)
            (let ((end (point)))
              (let ((content (buffer-substring-no-properties start end)))
                (setq counter (1+ counter))
                (let ((token (format "%s%d%s" sem-security-token-prefix counter sem-security-token-suffix)))
                  (push (cons token content) blocks))))))))
    (nreverse blocks)))

(defun sem-security--detect-sensitive-blocks-with-position (text)
  "Detect sensitive blocks in TEXT with surrounding context for position tracking.
Returns an alist of (token . (before-context . after-context)) where:
- token is the <<SENSITIVE_N>> placeholder
- before-context is up to 20 chars preceding the block
- after-context is up to 20 chars following the block

Note: This function only returns position info, not the full block content.
Use `sem-security--detect-sensitive-blocks` for the blocks-alist used in tokenization."
  (let ((position-info '())
        (counter 0)
        (context-chars 20))
    (with-temp-buffer
      (insert text)
      (goto-char (point-min))
      (while (re-search-forward "^[ \t]*#\\+begin_sensitive[ \t]*$" nil t)
        (let ((block-start (match-beginning 0)))
          (when (re-search-forward "^[ \t]*#\\+end_sensitive[ \t]*$" nil t)
            (let ((block-end (point)))
              (let* ((before-start (max (point-min) (- block-start context-chars)))
                     (after-end (min (point-max) (+ block-end context-chars)))
                     (before-context (string-trim
                                      (buffer-substring-no-properties before-start block-start)))
                     (after-context (string-trim
                                     (buffer-substring-no-properties block-end after-end)))
                     (block-content (buffer-substring-no-properties block-start block-end)))
                (setq counter (1+ counter))
                (let ((token (format "%s%d%s" sem-security-token-prefix counter sem-security-token-suffix)))
                  (push (list token block-content before-context after-context) position-info))))))))
    (nreverse position-info)))

(defun sem-security--tokenize (text blocks)
  "Replace sensitive content in TEXT with tokens from BLOCKS.
Returns the tokenized text."
  (let ((result text))
    (dolist (block blocks)
      (let ((token (car block))
            (content (cdr block)))
        (setq result (replace-regexp-in-string (regexp-quote content) token result t))))
    result))

(defun sem-security--detokenize (text blocks)
  "Replace tokens in TEXT with original content from BLOCKS.
Returns the restored text with sensitive content as plain text.

Multi-line content is indented 2 spaces per line with leading/trailing
newlines. Single-line content is placed at token position verbatim."
  (let ((result text))
    (dolist (block blocks)
      (let ((token (car block))
            (content (cdr block)))
        (let ((plain-text (sem-security--extract-block-content content)))
          (setq result (replace-regexp-in-string
                        (regexp-quote token)
                        plain-text
                        result
                        t)))))
    result))

(defun sem-security--extract-block-content (block)
  "Extract plain text content from BLOCK (which includes markers).
Multi-line content gets exactly 2-space indentation per line with leading/trailing
newlines. Single-line content is returned verbatim."
  (let* ((lines (split-string block "\n"))
         (content-lines (butlast (cdr lines))) ; drop first (begin marker) and last (end marker)
         (trimmed (string-trim (mapconcat 'identity content-lines "\n"))))
    (if (string-match-p "\n" trimmed)
        (concat "\n" (mapconcat (lambda (line) (concat "  " (replace-regexp-in-string "^[ \t]+" "" line))) (split-string trimmed "\n") "\n") "\n")
      trimmed)))

(defun sem-security-sanitize-for-llm (text)
  "Sanitize TEXT before sending to LLM.
Replaces sensitive blocks with opaque tokens.
Returns (tokenized-text blocks-alist position-info-alist) as a list of three elements:
- tokenized-text: the text with sensitive content replaced by tokens
- blocks-alist: alist mapping tokens to original sensitive content
- position-info-alist: alist mapping tokens to (before-context . after-context) pairs"
  (let* ((blocks (sem-security--detect-sensitive-blocks text))
         (tokenized (sem-security--tokenize text blocks))
         (position-info (sem-security--detect-sensitive-blocks-with-position text)))
    (list tokenized blocks position-info)))

(defun sem-security-restore-from-llm (text blocks)
  "Restore original content in TEXT using BLOCKS.
Replaces tokens with original sensitive content."
  (sem-security--detokenize text blocks))

(defun sem-security-verify-tokens-present (llm-output blocks-alist)
  "Verify that no token expansion occurred in LLM-OUTPUT.
BLOCKS-ALIST is an alist mapping tokens to original sensitive content.

Returns ((missing . ()) (expanded . ())) where:
- missing: tokens that should be present but are absent (acceptable)
- expanded: tokens whose original content appears in output (CRITICAL - indicates sanitizer failure)

If expanded is non-empty, this is a CRITICAL security incident."
  (let ((missing '())
        (expanded '()))
    (dolist (block blocks-alist)
      (let ((token (car block))
            (original-content (cdr block)))
        (cond
         ((string-match-p (regexp-quote original-content) llm-output)
          (push token expanded))
         ((not (string-match-p (regexp-quote token) llm-output))
          (push token missing)))))
    (list (cons 'missing missing) (cons 'expanded expanded))))

;;; URL Sanitization

(defun sem-security--sanitize-url (url)
  "Sanitize a single URL by replacing http/https with hxxp/hxxps."
  (cond
   ((string-prefix-p "https://" url)
    (concat "hxxps://" (substring url 8)))
   ((string-prefix-p "http://" url)
    (concat "hxxp://" (substring url 7)))
   (t url)))

(defun sem-security-sanitize-urls (text)
  "Sanitize all URLs in TEXT.
Replaces http:// with hxxp:// and https:// with hxxps://.
Use this for tasks.org and morning-read output only.
Do NOT use for org-roam output."
  (replace-regexp-in-string
   "https?://[^ \t\n\"]+"
   (lambda (match) (sem-security--sanitize-url match))
   text))

(provide 'sem-security)
;;; sem-security.el ends here
