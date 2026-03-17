;;; bootstrap-packages.el --- Bootstrap straight.el and install packages -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; This file bootstraps straight.el and installs all required packages
;; at Docker build time. It is separate from init.el and does not load
;; any sem-*.el modules.
;;
;; If any package installation fails, the Docker build fails.

;;; Code:

;; Bootstrap straight.el
(setq straight-repository-branch "develop")
(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name
        "straight/repos/straight.el/bootstrap.el"
        (or (bound-and-true-p straight-base-dir)
            user-emacs-directory)))
      (bootstrap-version 7))
  (when (file-exists-p bootstrap-file)
    (load bootstrap-file nil 'nomessage)))

;; Load the lockfile to pin exact package revisions
(straight-use-package 'use-package)
(straight-thaw-versions)

;; Install required packages
;; Each call will fail if the package cannot be installed
(straight-use-package 'gptel)
(straight-use-package 'elfeed)
(straight-use-package 'elfeed-org)
(straight-use-package 'org-roam)
(straight-use-package 'websocket)

(message "bootstrap-packages.el: All packages installed successfully")

(provide 'bootstrap-packages)
;;; bootstrap-packages.el ends here
