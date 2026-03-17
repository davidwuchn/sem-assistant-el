;;; sem-git-sync-test.el --- Tests for git-sync exit code handling -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Tests for verifying sem-git-sync--run-command returns actual exit codes.

;;; Code:

(require 'ert)
(require 'sem-git-sync)

;;; Exit Code Tests

(ert-deftest sem-git-sync-test-run-command-success ()
  "Test that run-command returns exit code 0 for successful command."
  (let ((result (sem-git-sync--run-command "echo 'success'")))
    (should (consp result))
    (should (= (car result) 0))
    (should (string-match-p "success" (cdr result)))))

(ert-deftest sem-git-sync-test-run-command-failure ()
  "Test that run-command returns non-zero exit code for failed command."
  (let ((result (sem-git-sync--run-command "false")))
    (should (consp result))
    (should-not (= (car result) 0))))

(ert-deftest sem-git-sync-test-run-command-invalid-command ()
  "Test that run-command returns non-zero exit code for invalid command."
  (let ((result (sem-git-sync--run-command "nonexistent-command-12345")))
    (should (consp result))
    (should-not (= (car result) 0))))

(ert-deftest sem-git-sync-test-run-command-exit-code-127 ()
  "Test that run-command returns exit code 127 for command not found."
  (let ((result (sem-git-sync--run-command "command-not-found-test")))
    (should (consp result))
    ;; Shell returns 127 for command not found
    (should (= (car result) 127))))

;;; Run Tests

(defun sem-git-sync-test-run-all ()
  "Run all git-sync tests."
  (interactive)
  (ert-run-tests-batch "^sem-git-sync-test"))

(provide 'sem-git-sync-test)
;;; sem-git-sync-test.el ends here
