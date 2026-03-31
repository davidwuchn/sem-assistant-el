;;; sem-time-test.el --- Tests for sem-time.el -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Tests for client timezone validation and formatting helpers.

;;; Code:

(require 'ert)
(require 'cl-lib)

(load-file (expand-file-name "../sem-time.el" (file-name-directory load-file-name)))

(ert-deftest sem-time-test-client-timezone-missing-signals-error ()
  "Test missing CLIENT_TIMEZONE signals a clear configuration error."
  (cl-letf (((symbol-function 'getenv)
             (lambda (_name) nil)))
    (should-error (sem-time-client-timezone)
                  :type 'error)))

(ert-deftest sem-time-test-client-timezone-invalid-signals-error ()
  "Test invalid CLIENT_TIMEZONE signals a clear configuration error."
  (cl-letf (((symbol-function 'getenv)
             (lambda (_name) "Invalid/Zone"))
            ((symbol-function 'format-time-string)
             (lambda (&rest _args)
               (error "Invalid timezone"))))
    (should-error (sem-time-client-timezone)
                  :type 'error)))

(ert-deftest sem-time-test-client-timezone-valid-returns-value ()
  "Test valid CLIENT_TIMEZONE is accepted and returned unchanged."
  (cl-letf (((symbol-function 'getenv)
             (lambda (_name) "Europe/Belgrade"))
            ((symbol-function 'format-time-string)
             (lambda (&rest _args) "ok")))
    (should (string= (sem-time-client-timezone) "Europe/Belgrade"))))

(ert-deftest sem-time-test-format-string-uses-client-timezone ()
  "Test format helper forwards client timezone to `format-time-string'."
  (let ((captured-zone nil))
    (cl-letf (((symbol-function 'sem-time-client-timezone)
               (lambda () "America/New_York"))
              ((symbol-function 'format-time-string)
               (lambda (_format _time zone)
                 (setq captured-zone zone)
                 "ok")))
      (should (string= (sem-time-format-string "%Y-%m-%d") "ok"))
      (should (string= captured-zone "America/New_York")))))

(provide 'sem-time-test)
;;; sem-time-test.el ends here
