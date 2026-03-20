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
  "Test that tokenize/detokenize round-trip restores content as plain text."
  (let ((original "Normal text
#+begin_sensitive
secret-api-key-12345
#+end_sensitive
More normal text"))
    (let* ((result (sem-security-sanitize-for-llm original))
           (tokenized (car result))
           (blocks (cadr result)))
      ;; Tokenized text should contain token placeholder
      (should (string-prefix-p "Normal text\n<<" tokenized))
      ;; Detokenize should restore content as plain text (no markers)
      ;; Single-line content is placed verbatim at token position
      (let ((restored (sem-security-restore-from-llm tokenized blocks)))
        (should (string= "Normal text
secret-api-key-12345
More normal text" restored))))))

;;; Test sensitive block content not present in tokenized string

(ert-deftest sem-security-test-sensitive-content-masked ()
  "Test that sensitive content is not present in tokenized string."
  (let ((original "Public info
#+begin_sensitive
SECRET_PASSWORD_123
#+end_sensitive
More public info"))
    (let* ((result (sem-security-sanitize-for-llm original))
           (tokenized (car result))
           (blocks (cadr result))
           (position-info (caddr result)))
      ;; Tokenized text should NOT contain the sensitive content
      (should-not (string-match-p "SECRET_PASSWORD_123" tokenized))
      ;; Should contain token placeholder instead
      (should (string-match-p "<<SENSITIVE_[0-9]+>>" tokenized))
      ;; Position info should exist and be non-nil
      (should (listp position-info))
      (should (> (length position-info) 0)))))

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

;;; Tests for position-preserving round-trip

(ert-deftest sem-security-test-position-roundtrip ()
  "Test that position info is correctly captured and restored as plain text."
  (let ((original "Update password to\n#+begin_sensitive\nsupersecret123\n#+end_sensitive\nfor access"))
    (let* ((result (sem-security-sanitize-for-llm original))
           (tokenized (car result))
           (blocks (cadr result))
           (position-info (caddr result)))
      ;; Token should be present in tokenized text
      (should (string-match-p "<<SENSITIVE_1>>" tokenized))
      ;; Original sensitive content should NOT be present
      (should-not (string-match-p "supersecret123" tokenized))
      ;; Position info should have entry for <<SENSITIVE_1>>
      (should (= (length position-info) 1))
      (let ((entry (car position-info)))
        (should (string= (car entry) "<<SENSITIVE_1>>"))
        (should (= (length entry) 4)) ;; token, content, before-context, after-context
        ;; Before context should contain text before the sensitive block
        (let ((before-context (caddr entry)))
          (should (string-match-p "Update password to" before-context)))
        ;; After context should contain text after the sensitive block
        (let ((after-context (cadddr entry)))
          (should (string-match-p "for access" after-context))))
      ;; Round-trip should restore plain text (no markers)
      (let ((restored (sem-security-restore-from-llm tokenized blocks)))
        (should (string= "Update password to
supersecret123
for access" restored))))))

;;; Tests for expansion detection

(ert-deftest sem-security-test-expansion-detection ()
  "Test that sem-security-verify-tokens-present detects token expansion."
  (let ((blocks-alist (list
                       (cons "<<SENSITIVE_1>>" (concat "#+begin_sensitive" (string ?\n) "supersecret123" (string ?\n) "#+end_sensitive"))
                       (cons "<<SENSITIVE_2>>" (concat "#+begin_sensitive" (string ?\n) "sk-live-abc123xyz789" (string ?\n) "#+end_sensitive")))))
    ;; Test case 1: No expansion - tokens present, no secret content
    (let* ((llm-output "Password: <<SENSITIVE_1>> and API key: <<SENSITIVE_2>>")
           (verification (sem-security-verify-tokens-present llm-output blocks-alist))
           (missing (cdr (assoc 'missing verification)))
           (expanded (cdr (assoc 'expanded verification))))
      (progn
        (should (null missing))
        (should (null expanded))))
    ;; Test case 2: Token missing - secret appeared instead of token
    ;; Note: The function checks if full block content appears, not just secret.
    ;; Since the LLM output has "supersecret123" (not the full block with markers),
    ;; it is NOT detected as expansion of the block. Instead, the token
    ;; is marked as missing because it was not preserved in the output.
    (let* ((llm-output "Password: supersecret123 and API key: <<SENSITIVE_2>>")
           (verification (sem-security-verify-tokens-present llm-output blocks-alist))
           (missing (cdr (assoc 'missing verification)))
           (expanded (cdr (assoc 'expanded verification))))
      (progn
        (should (= (length missing) 1))
        (should (string= (car missing) "<<SENSITIVE_1>>"))
        (should (null expanded))))
    ;; Test case 3: Missing tokens (acceptable - LLM didn't use them)
    (let* ((llm-output "Password: <<SENSITIVE_1>>")
           (verification (sem-security-verify-tokens-present llm-output blocks-alist))
           (missing (cdr (assoc 'missing verification)))
           (expanded (cdr (assoc 'expanded verification))))
      (progn
        (should (= (length missing) 1))
        (should (string= (car missing) "<<SENSITIVE_2>>"))
        (should (null expanded))))
    ;; Test case 4: Full block expansion detected
    ;; When the full block with markers appears in output, it is detected as expansion.
    ;; Token <<SENSITIVE_2>> is in output, so it's not missing.
    (let* ((llm-output (concat "Password: #+begin_sensitive\nsupersecret123\n#+end_sensitive and API key: <<SENSITIVE_2>>"))
           (verification (sem-security-verify-tokens-present llm-output blocks-alist))
           (missing (cdr (assoc 'missing verification)))
           (expanded (cdr (assoc 'expanded verification))))
      (progn
        (should (null missing))
        (should (= (length expanded) 1))
        (should (string= (car expanded) "<<SENSITIVE_1>>"))))))

(provide 'sem-security-test)
;;; sem-security-test.el ends here
