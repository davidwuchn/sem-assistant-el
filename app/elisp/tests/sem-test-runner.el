;;; sem-test-runner.el --- Test runner for all SEM ERT tests -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; This file loads all test files and runs the complete ERT test suite.
;; Run with: emacs --batch --load sem-test-runner.el

;;; Code:

;; Set up load path
(let* ((test-dir (file-name-directory load-file-name))
       (src-dir (expand-file-name ".." test-dir)))
  (add-to-list 'load-path test-dir)
  (add-to-list 'load-path src-dir))

;; Load mock helpers first
(load-file (expand-file-name "sem-mock.el" (file-name-directory load-file-name)))

;; Load test files in dependency order
(load-file (expand-file-name "sem-core-test.el" (file-name-directory load-file-name)))
(load-file (expand-file-name "sem-security-test.el" (file-name-directory load-file-name)))
(load-file (expand-file-name "sem-prompts-test.el" (file-name-directory load-file-name)))
(load-file (expand-file-name "sem-router-test.el" (file-name-directory load-file-name)))
(load-file (expand-file-name "sem-rss-test.el" (file-name-directory load-file-name)))
(load-file (expand-file-name "sem-url-capture-test.el" (file-name-directory load-file-name)))
(load-file (expand-file-name "sem-llm-test.el" (file-name-directory load-file-name)))
(load-file (expand-file-name "sem-async-test.el" (file-name-directory load-file-name)))
(load-file (expand-file-name "sem-retry-test.el" (file-name-directory load-file-name)))
(load-file (expand-file-name "sem-git-sync-test.el" (file-name-directory load-file-name)))
(load-file (expand-file-name "sem-url-sanitize-test.el" (file-name-directory load-file-name)))

;; Run all tests
(let ((result (ert-run-tests-batch-and-exit)))
  (message "Test run complete")
  (kill-emacs (if (zerop result) 0 1)))

(provide 'sem-test-runner)
;;; sem-test-runner.el ends here
