;;; sem-test-runner.el --- Test runner for all SEM ERT tests -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Compatibility runner for manually executing all SEM ERT tests.
;; Prefer `eask test ert` for full suite runs.

;;; Code:

(let* ((test-dir (file-name-directory load-file-name))
       (src-dir (expand-file-name ".." test-dir))
       (test-files (directory-files test-dir t "-test\\.el$")))
  (add-to-list 'load-path test-dir)
  (add-to-list 'load-path src-dir)
  (load-file (expand-file-name "sem-mock.el" test-dir))
  (dolist (test-file (sort test-files #'string<))
    (load-file test-file))
  (let ((test-state (sem-mock-setup-test-data-paths)))
    (unwind-protect
        (ert-run-tests-batch-and-exit)
      (sem-mock-teardown-test-data-paths test-state))))

(provide 'sem-test-runner)
;;; sem-test-runner.el ends here
