;;; sem-rules-test.el --- Tests for sem-rules.el -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Tests for sem-rules-read function.

;;; Code:

(require 'ert)
(require 'sem-mock)

(load-file (expand-file-name "../sem-rules.el" (file-name-directory load-file-name)))

;;; Tests

(ert-deftest sem-rules-test-read-returns-nil-when-file-missing ()
  "Test that sem-rules-read returns nil when rules file does not exist."
  (let ((sem-rules-file "/nonexistent/path/rules.org"))
    (should (null (sem-rules-read)))))

(ert-deftest sem-rules-test-read-returns-nil-when-file-empty ()
  "Test that sem-rules-read returns nil when rules file is empty."
  (let ((tmp (sem-mock-temp-file "")))
    (unwind-protect
        (let ((sem-rules-file tmp))
          (should (null (sem-rules-read))))
      (sem-mock-cleanup-temp-file tmp))))

(ert-deftest sem-rules-test-read-returns-content-when-file-exists ()
  "Test that sem-rules-read returns content when rules file exists and has content."
  (let ((tmp (sem-mock-temp-file "* Schedule tasks in the afternoon\nNo work on weekends")))
    (unwind-protect
        (let ((sem-rules-file tmp))
          (should (stringp (sem-rules-read)))
          (should (string-match-p "Schedule" (sem-rules-read))))
      (sem-mock-cleanup-temp-file tmp))))

(ert-deftest sem-rules-test-read-trims-whitespace ()
  "Test that sem-rules-read trims leading and trailing whitespace."
  (let ((tmp (sem-mock-temp-file "   \n  Some rules content  \n  ")))
    (unwind-protect
        (let ((sem-rules-file tmp))
          (should (string-match-p "Some rules content" (sem-rules-read)))
          (should-not (string-match-p "^\\s-+" (sem-rules-read))))
      (sem-mock-cleanup-temp-file tmp))))

(provide 'sem-rules-test)
;;; sem-rules-test.el ends here
