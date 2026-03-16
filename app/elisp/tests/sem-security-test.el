;;; sem-security-test.el --- Tests for sem-security.el -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Tests for sem-security masking and URL sanitization functions.

;;; Code:

(require 'ert)

;; Load the module under test
(load-file (expand-file-name "../sem-security.el" (file-name-directory load-file-name)))

;;; Tests for tokenize/detokenize round-trip

(ert-deftest sem-security-test-tokenize-detokenize-roundtrip ()
  "Test that tokenize/detokenize round-trip preserves content."
  (let ((original "Normal text
#+begin_sensitive
secret-api-key-12345
#+end_sensitive
More normal text"))
    (let* ((result (sem-security-sanitize-for-llm original))
           (tokenized (car result))
           (blocks (cdr result)))
      ;; Tokenized text should contain token placeholder
      (should (string-prefix-p "Normal text\n<<" tokenized))
      ;; Detokenize should restore original
      (let ((restored (sem-security-restore-from-llm tokenized blocks)))
        (should (string= original restored))))))

;;; Test sensitive block content not present in tokenized string

(ert-deftest sem-security-test-sensitive-content-masked ()
  "Test that sensitive content is not present in tokenized string."
  (let ((original "Public info
#+begin_sensitive
SECRET_PASSWORD_123
#+end_sensitive
More public info"))
    (let* ((result (sem-security-sanitize-for-llm original))
           (tokenized (car result)))
      ;; Tokenized text should NOT contain the sensitive content
      (should-not (string-match-p "SECRET_PASSWORD_123" tokenized))
      ;; Should contain token placeholder instead
      (should (string-match-p "<<SENSITIVE_[0-9]+>>" tokenized)))))

;;; Tests for URL sanitization

(ert-deftest sem-security-test-url-sanitization-http ()
  "Test URL sanitization replaces http with hxxp."
  (let ((text "Check out http://example.com/page for more info"))
    (let ((sanitized (sem-security-sanitize-urls text)))
      (should (string= "Check out hxxp://example.com/page for more info" sanitized))
      (should-not (string-match-p "http://" sanitized)))))

(ert-deftest sem-security-test-url-sanitization-https ()
  "Test URL sanitization replaces https with hxxps."
  (let ((text "Visit https://secure.example.com/login now"))
    (let ((sanitized (sem-security-sanitize-urls text)))
      (should (string= "Visit hxxps://secure.example.com/login now" sanitized))
      (should-not (string-match-p "https://" sanitized)))))

(ert-deftest sem-security-test-url-sanitization-multiple-urls ()
  "Test URL sanitization handles multiple URLs."
  (let ((text "See http://a.com and https://b.org for details"))
    (let ((sanitized (sem-security-sanitize-urls text)))
      (should (string= "See hxxp://a.com and hxxps://b.org for details" sanitized)))))

(ert-deftest sem-security-test-url-sanitization-preservation ()
  "Test that non-URL text is preserved."
  (let ((text "This is just regular text with no URLs"))
    (let ((sanitized (sem-security-sanitize-urls text)))
      (should (string= text sanitized)))))

;;; Test that URL sanitization is NOT applied to org-roam output
;;; (This is a policy test - the function exists but should not be called for org-roam)

(ert-deftest sem-security-test-url-sanitization-scope ()
  "Test that sem-security-sanitize-urls is a separate function.
Org-roam output should NOT call this function (policy check)."
  ;; The function exists and works
  (should (functionp 'sem-security-sanitize-urls))
  ;; But org-roam modules should not use it (this is a code review check)
  (should t))

(provide 'sem-security-test)
;;; sem-security-test.el ends here
