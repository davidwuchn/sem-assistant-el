;;; sem-time.el --- Client timezone helpers -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; This module centralizes client timezone retrieval and validation.
;; It treats CLIENT_TIMEZONE as the single authoritative runtime timezone.

;;; Code:

(require 'subr-x)

(defconst sem-time-client-timezone-env-var "CLIENT_TIMEZONE"
  "Environment variable that defines the authoritative client timezone.")

(defconst sem-time-zoneinfo-root "/usr/share/zoneinfo"
  "Root directory for IANA tzdata files used for Emacs zone rules.")

(defun sem-time--safe-timezone-name-p (timezone)
  "Return non-nil when TIMEZONE has a safe, non-empty zone name format."
  (and (stringp timezone)
       (not (string-empty-p (string-trim timezone)))
       (not (string-prefix-p "/" timezone))
       (not (string-match-p "[[:space:]]" timezone))
       (not (string-match-p "\\.\\." timezone))))

(defun sem-time--emacs-zone-rule (timezone)
  "Return Emacs-compatible zone rule string for TIMEZONE.
For IANA names like Europe/Belgrade, prefer absolute tzfile rule form
:/usr/share/zoneinfo/Europe/Belgrade when available in runtime tzdata."
  (let ((trimmed (and (stringp timezone) (string-trim timezone))))
    (cond
     ((or (null trimmed) (string-empty-p trimmed)) trimmed)
     ((string-prefix-p ":" trimmed) trimmed)
     ((string-match-p "/" trimmed)
      (let ((tzfile (expand-file-name trimmed sem-time-zoneinfo-root)))
        (if (file-exists-p tzfile)
            (concat ":" tzfile)
          trimmed)))
     (t trimmed))))

(defun sem-time--timezone-probe-valid-p (timezone zone-probe)
  "Return non-nil when ZONE-PROBE indicates valid resolution for TIMEZONE."
  (let ((offset (car-safe zone-probe))
        (abbr (car-safe (cdr-safe zone-probe)))
        (region (car-safe (split-string timezone "/" t))))
    (and (integerp offset)
         (stringp abbr)
         (or (not (string-match-p "/" timezone))
             (not (string= abbr region))))))

(defun sem-time--available-iana-timezone-p (timezone)
  "Return non-nil when TIMEZONE is accepted by Emacs runtime.
Validation resolves a runtime zone rule and verifies that Emacs can
compute a non-fallback timezone probe for TIMEZONE."
  (when (sem-time--safe-timezone-name-p timezone)
    (condition-case nil
        (let* ((zone-rule (sem-time--emacs-zone-rule timezone))
               (zone-probe (current-time-zone (current-time) zone-rule)))
          (sem-time--timezone-probe-valid-p timezone zone-probe))
      (error nil))))

(defun sem-time-client-timezone ()
  "Return validated CLIENT_TIMEZONE value or signal a configuration error."
  (let* ((raw-value (getenv sem-time-client-timezone-env-var))
         (timezone (and raw-value (string-trim raw-value))))
    (when (or (null timezone) (string-empty-p timezone))
      (error "SEM: CLIENT_TIMEZONE environment variable is not set or empty"))
    (unless (sem-time--available-iana-timezone-p timezone)
      (error "SEM: CLIENT_TIMEZONE is invalid or unavailable in runtime tzdata: %s" timezone))
    timezone))

(defun sem-time-format-string (format &optional time)
  "Format TIME with FORMAT using CLIENT_TIMEZONE semantics."
  (let* ((timezone (sem-time-client-timezone))
         (zone-rule (sem-time--emacs-zone-rule timezone)))
    (format-time-string format (or time (current-time)) zone-rule)))

(defun sem-time-format-iso-local (&optional time)
  "Format TIME as ISO-8601 local datetime in CLIENT_TIMEZONE.
Example output: 2026-03-30T14:25:00+0200"
  (sem-time-format-string "%Y-%m-%dT%H:%M:%S%z" (or time (current-time))))

(provide 'sem-time)
;;; sem-time.el ends here
