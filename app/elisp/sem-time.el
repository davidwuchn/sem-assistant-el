;;; sem-time.el --- Client timezone helpers -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; This module centralizes client timezone retrieval and validation.
;; It treats CLIENT_TIMEZONE as the single authoritative runtime timezone.

;;; Code:

(require 'subr-x)

(defconst sem-time-client-timezone-env-var "CLIENT_TIMEZONE"
  "Environment variable that defines the authoritative client timezone.")

(defun sem-time--safe-timezone-name-p (timezone)
  "Return non-nil when TIMEZONE has a safe, non-empty zone name format."
  (and (stringp timezone)
       (not (string-empty-p (string-trim timezone)))
       (not (string-prefix-p "/" timezone))
       (not (string-match-p "[[:space:]]" timezone))
       (not (string-match-p "\\.\\." timezone))))

(defun sem-time--available-iana-timezone-p (timezone)
  "Return non-nil when TIMEZONE is accepted by Emacs runtime.
Validation is runtime-based rather than filesystem-based because some
container images expose timezone data without a canonical zoneinfo tree."
  (when (sem-time--safe-timezone-name-p timezone)
    (condition-case nil
        (progn
          (format-time-string "%Y-%m-%d %H:%M:%S%z" (current-time) timezone)
          t)
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
  (format-time-string format (or time (current-time)) (sem-time-client-timezone)))

(defun sem-time-format-iso-local (&optional time)
  "Format TIME as ISO-8601 local datetime in CLIENT_TIMEZONE.
Example output: 2026-03-30T14:25:00+0200"
  (sem-time-format-string "%Y-%m-%dT%H:%M:%S%z" (or time (current-time))))

(provide 'sem-time)
;;; sem-time.el ends here
