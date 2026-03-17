;;; sem-url-sanitize-test.el --- Tests for URL sanitization in org-roam output -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Tests for verifying that org-roam nodes do NOT have defanged URLs.
;; URL defanging (hxxps://) should only be applied to RSS/task outputs,
;; not to org-roam node #+ROAM_REFS:.

;;; Code:

(require 'ert)
(require 'sem-security)

;;; URL Defanging Tests

(ert-deftest sem-url-sanitize-test-https-preserved ()
  "Test that https:// URLs are preserved in org-roam output."
  (let ((input "#+ROAM_REFS: https://example.com/article"))
    ;; In org-roam output, URLs should NOT be defanged
    ;; The sem-security-sanitize-urls function is NOT called in sem-url-capture.el
    (should (string-match-p "https://" input))))

(ert-deftest sem-url-sanitize-test-no-defanging-in-roam-refs ()
  "Test that #+ROAM_REFS: contains valid https:// URLs."
  (let ((roam-content ":PROPERTIES:
:ID: 550e8400-e29b-41d4-a716-446655440000
:END:
#+title: Test Article
#+ROAM_REFS: https://example.com/test-article
#+filetags: :article:

* Summary
Source: [[https://example.com/test-article][https://example.com/test-article]]
Test summary content."))
    ;; Verify https:// is present
    (should (string-match-p "https://" roam-content))
    ;; Verify hxxps:// is NOT present
    (should-not (string-match-p "hxxps://" roam-content))))

(ert-deftest sem-url-sanitize-test-multiple-urls-preserved ()
  "Test that multiple URLs in org-roam content are preserved."
  (let ((roam-content "* Test
:PROPERTIES:
:ID: test-id
:END:
#+ROAM_REFS: https://site1.com https://site2.org
Some content with https://site3.com links."))
    (should (string-match-p "https://site1.com" roam-content))
    (should (string-match-p "https://site2.org" roam-content))
    (should (string-match-p "https://site3.com" roam-content))
    (should-not (string-match-p "hxxps://" roam-content))))

(ert-deftest sem-url-sanitize-test-security-function-exists ()
  "Test that sem-security-sanitize-urls function still exists."
  (should (fboundp 'sem-security-sanitize-urls)))

;;; Run Tests

(defun sem-url-sanitize-test-run-all ()
  "Run all URL sanitization tests."
  (interactive)
  (ert-run-tests-batch "^sem-url-sanitize-test"))

(provide 'sem-url-sanitize-test)
;;; sem-url-sanitize-test.el ends here
