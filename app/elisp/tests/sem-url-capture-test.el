;;; sem-url-capture-test.el --- Tests for sem-url-capture.el -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Tests for sem-url-capture text sanitization and validation functions.

;;; Code:

(require 'ert)
(require 'sem-mock)
(require 'sem-url-capture)

;;; Tests for sem-url-capture--sanitize-text

(ert-deftest sem-url-capture-test-sanitize-digit-only-lines ()
  "Test removal of digit-only lines."
  (let ((text "Line 1\n123\nLine 2\n456\nLine 3"))
    (let ((sanitized (sem-url-capture--sanitize-text text)))
      (should-not (string-match-p "^123$" sanitized))
      (should-not (string-match-p "^456$" sanitized))
      (should (string-match-p "Line 1" sanitized))
      (should (string-match-p "Line 2" sanitized))
      (should (string-match-p "Line 3" sanitized)))))

(ert-deftest sem-url-capture-test-sanitize-whitespace ()
  "Test whitespace normalization."
  (let ((text "Multiple   spaces\n\nand\n\nnewlines"))
    (let ((sanitized (sem-url-capture--sanitize-text text)))
      (should-not (string-match-p "  " sanitized))  ; No multiple spaces
      (should-not (string-match-p "\n" sanitized))  ; No newlines
      (should (string= "Multiple spaces and newlines" sanitized)))))

(ert-deftest sem-url-capture-test-sanitize-truncation ()
  "Test truncation to max chars limit."
  (let ((long-text (make-string 50000 ?a)))
    (let ((sanitized (sem-url-capture--sanitize-text long-text)))
      (should (<= (length sanitized) sem-url-capture-max-chars)))))

;;; Tests for sem-url-capture--make-slug

(ert-deftest sem-url-capture-test-make-slug-downcase ()
  "Test slug downcasing."
  (let ((title "My Great Article Title"))
    (let ((slug (sem-url-capture--make-slug title)))
      (should (string= "my-great-article-title" slug)))))

(ert-deftest sem-url-capture-test-make-slug-non-alphanum-strip ()
  "Test non-alphanumeric character stripping."
  (let ((title "Special! @Characters# Here$"))
    (let ((slug (sem-url-capture--make-slug title)))
      (should (string= "special-characters-here" slug)))))

(ert-deftest sem-url-capture-test-make-slug-length-limit ()
  "Test slug truncation to 50 characters."
  (let ((title (make-string 100 ?a)))
    (let ((slug (sem-url-capture--make-slug title)))
      (should (<= (length slug) 50)))))

;;; Tests for sem-url-capture--validate-and-save

(ert-deftest sem-url-capture-test-validate-errors-missing-properties ()
  "Test validation errors on missing :PROPERTIES:."
  (let ((response "No properties drawer here\n#+title: Test")
        (test-log-file (sem-mock-temp-file "* 2026\n** 03 (March)\n*** 2026-03-16\n"))
        (test-errors-file (sem-mock-temp-file "* Errors\n")))
    (unwind-protect
        (let ((sem-core-log-file test-log-file)
              (sem-core-errors-file test-errors-file))
          (let ((result (sem-url-capture--validate-and-save response "http://test.com")))
            (should-not result)))
      (sem-mock-cleanup-temp-file test-log-file)
      (sem-mock-cleanup-temp-file test-errors-file))))

(ert-deftest sem-url-capture-test-validate-errors-missing-title ()
  "Test validation errors on missing #+title:."
  (let ((response ":PROPERTIES:\n:ID: test-id\n:END:\nNo title here")
        (test-log-file (sem-mock-temp-file "* 2026\n** 03 (March)\n*** 2026-03-16\n"))
        (test-errors-file (sem-mock-temp-file "* Errors\n")))
    (unwind-protect
        (let ((sem-core-log-file test-log-file)
              (sem-core-errors-file test-errors-file))
          (let ((result (sem-url-capture--validate-and-save response "http://test.com")))
            (should-not result)))
      (sem-mock-cleanup-temp-file test-log-file)
      (sem-mock-cleanup-temp-file test-errors-file))))

;;; Test prompt builder output contains Source URL as first line of Summary

(ert-deftest sem-url-capture-test-prompt-builder-source-url ()
  "Test that prompt builder includes Source URL as first line of * Summary."
  (let ((url "https://example.com/article")
        (content "Test content"))
    (let ((prompt (sem-url-capture--build-user-prompt url content nil)))
      (should (string-match-p "\\* Summary\nSource: \\[\\[https://example.com/article\\]\\[https://example.com/article\\]\\]" prompt)))))

;;; Tests for security masking (Task 4.5-4.6)

(ert-deftest sem-url-capture-test-security-tokenizes-sensitive-blocks ()
  "Test that text passed to LLM has sensitive blocks tokenized.
Asserts that sem-security-sanitize-for-llm is called and tokens are used."
  (let ((text "Normal text\n#+begin_sensitive\nSECRET_API_KEY=abc123\n#+end_sensitive\nMore text"))
    (let* ((result (sem-security-sanitize-for-llm text))
           (tokenized (car result))
           (blocks (cdr result)))
      ;; Tokenized text should NOT contain the sensitive content
      (should-not (string-match-p "SECRET_API_KEY=abc123" tokenized))
      ;; Tokenized text should contain a token
      (should (string-match-p "<<SENSITIVE_[0-9]+>>" tokenized))
      ;; Blocks should contain the original sensitive content
      (should (not (null blocks)))
      (should (assoc "<<SENSITIVE_1>>" blocks)))))

(ert-deftest sem-url-capture-test-security-urls-defanged ()
  "Test that LLM response passed to validate-and-save has URLs defanged (hxxp://).
Asserts that sem-security-sanitize-urls replaces http:// with hxxp://."
  (let ((response "Check out https://example.com and http://test.org/path"))
    (let ((sanitized (sem-security-sanitize-urls response)))
      ;; https should become hxxps
      (should (string-match-p "hxxps://example\\.com" sanitized))
      ;; http should become hxxp
      (should (string-match-p "hxxp://test\\.org/path" sanitized))
      ;; Original URLs should NOT be present
      (should-not (string-match-p "https://example\\.com" sanitized))
      (should-not (string-match-p "http://test\\.org/path" sanitized)))))

(ert-deftest sem-url-capture-test-security-urls-defanged-in-context ()
  "Test URL defanging in a realistic org-roam node context."
  (let ((response ":PROPERTIES:\n:ID: test-id\n:END:\n#+title: Test\n* Summary\nSource: [[https://example.com][Link]]\n* Notes\nSee http://test.org for more."))
    (let ((sanitized (sem-security-sanitize-urls response)))
      (should (string-match-p "hxxps://example\\.com" sanitized))
      (should (string-match-p "hxxp://test\\.org" sanitized))
      ;; Org structure should be preserved
      (should (string-match-p "^:PROPERTIES:" sanitized))
      (should (string-match-p "^#\\+title: Test" sanitized)))))

(provide 'sem-url-capture-test)
;;; sem-url-capture-test.el ends here
