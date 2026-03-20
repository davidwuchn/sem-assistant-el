;;; init.el --- SEM Assistant Elisp Daemon Initialization -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; This is the main initialization file for the SEM Assistant Elisp daemon.
;; It runs in a Docker container and processes mobile-captured Org notes
;; and RSS feeds autonomously via LLM.
;;
;; Startup sequence (must execute in strict order):
;; 1. Validate required env vars
;; 2. Bootstrap straight.el (makes build-time packages available)
;; 3. Configure gptel with OpenRouter backend
;; 4. Set hardcoded paths as globals
;; 5. Set security globals
;; 6. Initialize git repo for org-roam
;; 7. Run db-initialization (elfeed + org-roam)
;; 8. Load all modules
;; 9. Install *Messages* redirection hook
;; 10. Daemon ready

;;; Code:

;;; 1. Validate Required Environment Variables

(defun sem-init--validate-env ()
  "Validate required environment variables.
Signal an error if OPENROUTER_KEY or OPENROUTER_MODEL is unset or empty."
  (let ((key (getenv "OPENROUTER_KEY"))
        (model (getenv "OPENROUTER_MODEL")))
    (when (or (null key) (string-empty-p key))
      (error "SEM: OPENROUTER_KEY environment variable is not set or empty"))
    (when (or (null model) (string-empty-p model))
      (error "SEM: OPENROUTER_MODEL environment variable is not set or empty"))
    (message "SEM: Environment variables validated successfully")))

;;; 2. Bootstrap straight.el (packages installed at build time)

(defun sem-init--bootstrap-straight ()
  "Bootstrap straight.el and activate build-time-installed packages."
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
  (message "SEM: straight.el bootstrapped")
  (dolist (pkg '(gptel elfeed elfeed-org org-roam websocket))
    (condition-case err
        (straight-use-package pkg)
      (error
       (message "SEM: Failed to activate package %s: %s"
                pkg (error-message-string err))))))

;;; 3. Configure gptel with OpenRouter Backend

(defun sem-init--configure-gptel ()
  "Configure gptel with OpenRouter backend.
API key is read from OPENROUTER_KEY via lambda.
Model is read from OPENROUTER_MODEL at call time."
  (require 'gptel)
  (gptel-make-openai "OpenRouter"
    :host "openrouter.ai"
    :endpoint "/api/v1/chat/completions"
    :stream t
    :key (lambda () (getenv "OPENROUTER_KEY"))
    :models (list (intern (getenv "OPENROUTER_MODEL")))
    :request-params '(:reasoning (:exclude t)))
  (setq gptel-backend (gptel-get-backend "OpenRouter"))
  (setq gptel-model (intern (getenv "OPENROUTER_MODEL")))
  (message "SEM: gptel configured with OpenRouter backend"))

;;; 3. Set Hardcoded Paths as Globals

(defun sem-init--set-paths ()
  "Set all hardcoded paths as global variables."
  (setq org-roam-directory (expand-file-name "/data/org-roam/"))
  (setq elfeed-db-directory (expand-file-name "/data/elfeed/"))
  (setq rmh-elfeed-org-files '("/data/feeds.org"))
  (message "SEM: Paths configured"))

;;; 4. Set Security Globals

(defun sem-init--set-security-globals ()
  "Set security-related global variables.
Disables lock files, local variables, and configures org-babel safety."
  (setq create-lockfiles nil)
  (setq enable-local-variables nil)
  (setq org-confirm-babel-evaluate t)
  (setq org-export-babel-evaluate nil)
  (setq org-display-remote-inline-images nil)
  (message "SEM: Security globals set"))

;;; 5. Initialize Git Repo for org-roam (GitHub Sync Readiness)

(defun sem-init--init-git-repo ()
  "Initialize git repo for org-roam if not already present.
Creates /data/org-roam/.git/ if absent and writes .gitignore.
This is pre-wiring for future github-integration."
  (let ((git-dir (expand-file-name ".git" org-roam-directory)))
    (unless (file-directory-p git-dir)
      (message "SEM: Initializing git repo in %s" org-roam-directory)
      (make-directory org-roam-directory t)
      (call-process "git" nil nil nil "init" org-roam-directory)
      ;; Write .gitignore
      (let ((gitignore-path (expand-file-name ".gitignore" org-roam-directory)))
        (with-temp-file gitignore-path
          (insert "# org-roam database files\n")
          (insert "org-roam.db\n")
          (insert "*.db-shm\n")
          (insert "*.db-wal\n"))))
    (message "SEM: Git repo ready")))

;;; 6. Database Initialization

(defun sem-init--init-elfeed-db ()
  "Load Elfeed database with corruption recovery.
Attempts to load existing DB. On error, wipes and recreates."
  (require 'elfeed)
  (require 'elfeed-org)
  (let ((db-dir elfeed-db-directory))
    (make-directory db-dir t)
    (condition-case err
        (progn
          (elfeed-db-load)
          (message "SEM: Elfeed DB loaded successfully"))
      (error
       (message "SEM: Elfeed DB corrupt, wiping and recreating: %s"
                (error-message-string err))
       (delete-directory db-dir t)
       (make-directory db-dir t)
       (elfeed-db-load)
       (message "SEM: Elfeed DB recreated"))))
  ;; Configure elfeed-org
  (elfeed-org)
  (message "SEM: Elfeed-org configured"))

(defun sem-init--init-org-roam-db ()
  "Rebuild org-roam database from scratch.
Always deletes existing DB and calls org-roam-db-sync.
Handles missing /data/org-roam/ gracefully."
  (require 'org-roam)
  (let* ((db-path (expand-file-name "org-roam.db" org-roam-directory))
         (shm-path (concat db-path "-shm"))
         (wal-path (concat db-path "-wal")))
    ;; Delete old DB files if they exist
    (dolist (path (list db-path shm-path wal-path))
      (when (file-exists-p path)
        (delete-file path)))
    ;; Create directory if needed
    (make-directory org-roam-directory t)
    ;; Sync database
    (condition-case err
        (progn
          (org-roam-db-sync)
          (message "SEM: org-roam DB synced"))
      (error
       (message "SEM: org-roam DB sync error (continuing): %s"
                (error-message-string err))))))

(defun sem-init--init-databases ()
  "Initialize both Elfeed and org-roam databases."
  (sem-init--init-elfeed-db)
  (sem-init--init-org-roam-db))

;;; 7. Load All Modules

(defun sem-init--load-modules ()
  "Load all SEM modules in dependency order.
sem-core must load first as it defines sem-core-log.
sem-prompts must load before sem-router and sem-url-capture."
  (let ((load-path (cons (file-name-directory load-file-name) load-path)))
    (require 'sem-core)
    (require 'sem-security)
    (require 'sem-llm)
    (require 'sem-rss)
    (require 'sem-prompts)
    (require 'sem-url-capture)
    (require 'sem-git-sync)
    (require 'sem-router)
    (message "SEM: All modules loaded")))

;;; 8. Install *Messages* Redirection Hook

(defun sem-init--install-messages-hook ()
  "Install the *Messages* persistence hook with daily rotation."
  (add-hook 'post-command-hook #'sem-core--flush-messages-daily)
  (message "SEM: *Messages* daily rotation installed"))

;;; 9. Daemon Startup Sequence

(defun sem-init--startup ()
  "Execute the complete daemon startup sequence.
All steps run in strict order. Errors are logged to stderr and
written to errors.org to aid debugging."
  (condition-case err
      (progn
        ;; Step 1: Validate env vars
        (message "SEM: Starting init step 1/9 - validate env vars")
        (sem-init--validate-env)
        (message "SEM: Step 1/9 complete - env vars validated")
        ;; Step 2: Bootstrap straight.el
        (message "SEM: Starting init step 2/10 - bootstrap straight")
        (sem-init--bootstrap-straight)
        (message "SEM: Step 2/10 complete - straight bootstrapped")
        ;; Step 3: Configure gptel
        (message "SEM: Starting init step 3/10 - configure gptel")
        (sem-init--configure-gptel)
        (message "SEM: Step 3/10 complete - gptel configured")
        ;; Step 4: Set paths
        (message "SEM: Starting init step 4/10 - set paths")
        (sem-init--set-paths)
        (message "SEM: Step 4/10 complete - paths configured")
        ;; Step 5: Set security globals
        (message "SEM: Starting init step 5/10 - set security globals")
        (sem-init--set-security-globals)
        (message "SEM: Step 5/10 complete - security globals set")
        ;; Step 6: Init git repo
        (message "SEM: Starting init step 6/10 - init git repo")
        (sem-init--init-git-repo)
        (message "SEM: Step 6/10 complete - git repo ready")
        ;; Step 7: Init databases
        (message "SEM: Starting init step 7/10 - init databases")
        (sem-init--init-databases)
        (message "SEM: Step 7/10 complete - databases initialized")
        ;; Step 8: Load modules
        (message "SEM: Starting init step 8/10 - load modules")
        (sem-init--load-modules)
        (message "SEM: Step 8/10 complete - modules loaded")
        ;; Step 9: Install messages hook
        (message "SEM: Starting init step 9/10 - install messages hook")
        (sem-init--install-messages-hook)
        (message "SEM: Step 9/10 complete - messages hook installed")
        ;; Step 10: Daemon ready
        (message "SEM: Step 10/10 complete - daemon ready")
        (message "SEM: Daemon ready")
        (princ "SEM: Daemon started successfully\n" t))
    (error
     (let ((error-msg (error-message-string err)))
       ;; Log to stderr for immediate visibility in container logs
       (princ (format "SEM: STARTUP ERROR: %s\n" error-msg) t)
       ;; Also log via message (goes to *Messages*)
       (message "SEM: Startup error: %s" error-msg)
       ;; Log to errors.org if sem-core-log-error is available
       (condition-case _err2
           (when (fboundp 'sem-core-log-error)
             (sem-core-log-error "init" "STARTUP" error-msg nil))
         (error nil))))))

;; Run startup when this file is loaded
(sem-init--startup)

(provide 'init)
;;; init.el ends here
