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
            ((symbol-function 'current-time-zone)
             (lambda (&rest _args) '(0 "Invalid"))))
    (should-error (sem-time-client-timezone)
                  :type 'error)))

(ert-deftest sem-time-test-client-timezone-valid-returns-value ()
  "Test valid CLIENT_TIMEZONE is accepted and returned unchanged."
  (cl-letf (((symbol-function 'getenv)
              (lambda (_name) "Europe/Belgrade"))
            ((symbol-function 'current-time-zone)
             (lambda (&rest _args) '(7200 "CEST"))))
    (should (string= (sem-time-client-timezone) "Europe/Belgrade"))))

(ert-deftest sem-time-test-emacs-zone-rule-prefers-zoneinfo-file ()
  "Test IANA timezone resolves to absolute tzfile zone rule when present."
  (cl-letf (((symbol-function 'file-exists-p)
             (lambda (path)
               (string= path "/usr/share/zoneinfo/Europe/Belgrade"))))
    (should (string= (sem-time--emacs-zone-rule "Europe/Belgrade")
                     ":/usr/share/zoneinfo/Europe/Belgrade"))))

(ert-deftest sem-time-test-emacs-zone-rule-falls-back-to-original-string ()
  "Test timezone rule falls back when tzfile is unavailable."
  (cl-letf (((symbol-function 'file-exists-p)
             (lambda (_path) nil)))
    (should (string= (sem-time--emacs-zone-rule "Europe/Belgrade")
                     "Europe/Belgrade"))))

(ert-deftest sem-time-test-format-string-uses-resolved-zone-rule ()
  "Test format helper passes resolved zone rule to formatter."
  (let ((captured-zone nil))
    (cl-letf (((symbol-function 'sem-time-client-timezone)
               (lambda () "America/New_York"))
              ((symbol-function 'sem-time--emacs-zone-rule)
               (lambda (_timezone)
                 ":/usr/share/zoneinfo/America/New_York"))
              ((symbol-function 'format-time-string)
               (lambda (_format _time &optional zone)
                 (setq captured-zone zone)
                 "ok")))
      (should (string= (sem-time-format-string "%Y-%m-%d") "ok"))
      (should (string= captured-zone ":/usr/share/zoneinfo/America/New_York")))))

(provide 'sem-time-test)
;;; sem-time-test.el ends here
