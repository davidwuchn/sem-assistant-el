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
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously "https://raw.githubusercontent.com/radian-software/straight.el/develop/install.el"
                                    'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

;; Pin exact package revisions via :commit in each straight-use-package call
(setq straight-check-for-modifications nil)
(setq straight-vc-use-snapshot-installation t)
(straight-override-recipe '(org :type built-in))
(setq straight-vc-git-default-clone-depth 1)
(straight-use-package 'use-package)

;; Install required packages
;; Each call will fail if the package cannot be installed
(straight-use-package '(gptel :commit "d221329ee3aa0198ad51c003a8d94b2af3a72dce" :depth 1))
(straight-use-package '(elfeed :commit "904b6d4feca78e7e5336d7dbb7b8ba53b8c4dac1" :depth 1))
(straight-use-package '(elfeed-org :commit "1197cf29f6604e572ec604874a8f50b58081176a" :depth 1))
(straight-use-package '(org-roam :commit "7ce95a286ba7d0383f2ab16ca4cdbf79901921ff" :depth 1))
(straight-use-package '(websocket :commit "2195e1247ecb04c30321702aa5f5618a51c329c5" :depth 1))

(message "bootstrap-packages.el: All packages installed successfully")

(provide 'bootstrap-packages)
;;; bootstrap-packages.el ends here
