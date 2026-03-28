;;; sem-paths.el --- Shared path contract helpers -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; This module centralizes SEM path contract resolution.
;; It defines two explicit roots:
;; - Repository root for git lifecycle operations
;; - Notes root for org-roam note creation and indexing

;;; Code:

(require 'cl-lib)

(defconst sem-paths-repository-root-default "/data/org-roam"
  "Default repository root path for git lifecycle operations.")

(defconst sem-paths-notes-subdir "org-files"
  "Notes subdirectory name under repository root.")

(defun sem-paths--normalize-directory (path)
  "Return PATH normalized as a directory path."
  (file-name-as-directory (expand-file-name path)))

(defun sem-paths-join (base &rest segments)
  "Join BASE with SEGMENTS and normalize as an absolute path."
  (let ((joined (expand-file-name base)))
    (dolist (segment segments)
      (setq joined (expand-file-name segment joined)))
    joined))

(defun sem-paths-resolve ()
  "Resolve and return SEM path contract as a plist.
Returned keys are :repository-root and :notes-root."
  (let* ((repository-root (sem-paths--normalize-directory
                           sem-paths-repository-root-default))
         (notes-root (sem-paths--normalize-directory
                      (sem-paths-join repository-root sem-paths-notes-subdir))))
    (list :repository-root repository-root
          :notes-root notes-root)))

(provide 'sem-paths)
;;; sem-paths.el ends here
