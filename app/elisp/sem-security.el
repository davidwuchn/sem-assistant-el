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
      (while (re-search-forward "^#\\+begin_sensitive[ \t]*$" nil t)
        (let ((start (match-beginning 0)))
          (when (re-search-forward "^#\\+end_sensitive[ \t]*$" nil t)
            (let ((end (point)))
              (let ((content (buffer-substring-no-properties start end)))
                (setq counter (1+ counter))
                (let ((token (format "%s%d%s" sem-security-token-prefix counter sem-security-token-suffix)))
                  (push (cons token content) blocks))))))))
    (nreverse blocks)))

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
Returns the restored text."
  (let ((result text))
    (dolist (block blocks)
      (let ((token (car block))
            (content (cdr block)))
        (setq result (replace-regexp-in-string (regexp-quote token) content result t))))
    result))

(defun sem-security-sanitize-for-llm (text)
  "Sanitize TEXT before sending to LLM.
Replaces sensitive blocks with opaque tokens.
Returns (tokenized-text . blocks-alist)."
  (let ((blocks (sem-security--detect-sensitive-blocks text)))
    (cons (sem-security--tokenize text blocks) blocks)))

(defun sem-security-restore-from-llm (text blocks)
  "Restore original content in TEXT using BLOCKS.
Replaces tokens with original sensitive content."
  (sem-security--detokenize text blocks))

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
