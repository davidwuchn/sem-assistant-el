;;; sem-git-sync.el --- Git synchronization for org-roam -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; This module provides automated Git synchronization for the org-roam directory.
;; It commits all changes and pushes to origin on a cron schedule.
;;
;; Entry point: sem-git-sync-org-roam (callable from cron)

;;; Code:

(require 'sem-core)

;;; Constants

(defconst sem-git-sync-org-roam-dir "/data/org-roam"
  "Path to the org-roam directory to synchronize.")

(defconst sem-git-sync-ssh-key "/root/.ssh/id_rsa"
  "Path to the SSH private key for GitHub authentication.")

;;; Helper Functions

(defun sem-git-sync--run-command (command &optional dir)
  "Run shell COMMAND in DIR and return (exit-code . output).
Returns a cons cell where car is the exit code and cdr is the command output."
  (let ((default-directory (or dir default-directory))
        (output-buffer (generate-new-buffer " *git-sync-cmd*")))
    (unwind-protect
        (let ((exit-code
               (with-current-buffer output-buffer
                 (erase-buffer)
                 (call-process-shell-command command nil output-buffer nil)
                 (buffer-string)
                 (if (re-search-backward "^Process shell\s-.*\s-finished" nil t)
                     0
                   (if (re-search-backward "^Process shell\s-.*\s-exited abnormally" nil t)
                       1
                       0)))))
          (cons exit-code (with-current-buffer output-buffer (buffer-string))))
      (when (buffer-live-p output-buffer)
        (kill-buffer output-buffer)))))

(defun sem-git-sync--has-changes-p ()
  "Check if there are uncommitted changes in org-roam directory.
Returns t if there are changes to commit, nil otherwise."
  (let ((result (sem-git-sync--run-command "git status --porcelain" sem-git-sync-org-roam-dir)))
    (and (= (car result) 0)
         (not (string-empty-p (string-trim (cdr result)))))))

(defun sem-git-sync--setup-ssh ()
  "Set up SSH agent and add the SSH key for GitHub authentication.
Returns t on success, nil on failure."
  (condition-case err
      (progn
        ;; Start ssh-agent if not running
        (let ((agent-result (sem-git-sync--run-command "eval $(ssh-agent -s)")))
          (when (/= (car agent-result) 0)
            (sem-core-log "git-sync" "GIT-SYNC" "FAIL"
                          "Failed to start ssh-agent"
                          nil)
            (cl-return-from sem-git-sync--setup-ssh nil)))
        
        ;; Add SSH key
        (if (file-exists-p sem-git-sync-ssh-key)
            (let ((add-result (sem-git-sync--run-command 
                               (format "ssh-add %s" sem-git-sync-ssh-key))))
              (if (= (car add-result) 0)
                  t
                (sem-core-log "git-sync" "GIT-SYNC" "FAIL"
                              (format "Failed to add SSH key: %s" (cdr add-result))
                              nil)
                nil))
          (sem-core-log "git-sync" "GIT-SYNC" "FAIL"
                        (format "SSH key not found at %s" sem-git-sync-ssh-key)
                        nil)
          nil))
    (error
     (sem-core-log-error "git-sync" "GIT-SYNC"
                         (format "SSH setup error: %s" (error-message-string err))
                         nil
                         nil)
     nil)))

;;; Main Entry Point

;;;###autoload
(defun sem-git-sync-org-roam ()
  "Synchronize org-roam directory to remote GitHub repository.

This is the cron entry point. It:
1. Checks if /data/org-roam is a git repository
2. Sets up SSH authentication
3. Checks for uncommitted changes (respecting .gitignore)
4. Commits all changes with timestamp
5. Pushes to origin

Returns t on success, nil on failure or when no changes to sync."
  (condition-case err
      (progn
        (sem-core-log "git-sync" "GIT-SYNC" "OK"
                      "Starting org-roam sync"
                      nil)
        
        ;; Check if directory exists
        (unless (file-directory-p sem-git-sync-org-roam-dir)
          (sem-core-log "git-sync" "GIT-SYNC" "FAIL"
                        (format "Directory does not exist: %s" sem-git-sync-org-roam-dir)
                        nil)
          (cl-return-from sem-git-sync-org-roam nil))
        
        ;; Check if it's a git repository
        (let ((git-check (sem-git-sync--run-command "git rev-parse --git-dir" sem-git-sync-org-roam-dir)))
          (when (or (/= (car git-check) 0)
                    (string-empty-p (string-trim (cdr git-check))))
            (sem-core-log "git-sync" "GIT-SYNC" "FAIL"
                          (format "Not a git repository: %s" sem-git-sync-org-roam-dir)
                          nil)
            (cl-return-from sem-git-sync-org-roam nil)))
        
        ;; Check for changes
        (unless (sem-git-sync--has-changes-p)
          (sem-core-log "git-sync" "GIT-SYNC" "SKIP"
                        "No changes to sync"
                        nil)
          (message "SEM: Git sync - no changes to commit")
          (cl-return-from sem-git-sync-org-roam t))
        
        ;; Set up SSH
        (unless (sem-git-sync--setup-ssh)
          (cl-return-from sem-git-sync-org-roam nil))
        
        ;; Stage all changes
        (let ((add-result (sem-git-sync--run-command "git add -A" sem-git-sync-org-roam-dir)))
          (when (/= (car add-result) 0)
            (sem-core-log "git-sync" "GIT-SYNC" "FAIL"
                          (format "Failed to stage changes: %s" (cdr add-result))
                          nil)
            (cl-return-from sem-git-sync-org-roam nil)))
        
        ;; Commit with timestamp
        (let* ((timestamp (format-time-string "%Y-%m-%d %H:%M:%S"))
               (commit-msg (format "Sync org-roam: %s" timestamp))
               (commit-result (sem-git-sync--run-command 
                               (format "git commit -m '%s'" commit-msg)
                               sem-git-sync-org-roam-dir)))
          (when (/= (car commit-result) 0)
            (sem-core-log "git-sync" "GIT-SYNC" "FAIL"
                          (format "Failed to commit: %s" (cdr commit-result))
                          nil)
            (cl-return-from sem-git-sync-org-roam nil)))
        
        ;; Push to origin
        (let ((push-result (sem-git-sync--run-command "git push origin" sem-git-sync-org-roam-dir)))
          (when (/= (car push-result) 0)
            (sem-core-log "git-sync" "GIT-SYNC" "FAIL"
                          (format "Failed to push: %s" (cdr push-result))
                          nil)
            (cl-return-from sem-git-sync-org-roam nil)))
        
        ;; Success
        (sem-core-log "git-sync" "GIT-SYNC" "OK"
                      "Successfully synced org-roam to GitHub"
                      nil)
        (message "SEM: Git sync complete")
        t)
    (error
     (sem-core-log-error "git-sync" "GIT-SYNC"
                         (error-message-string err)
                         nil
                         nil)
     (message "SEM: Git sync error: %s" (error-message-string err))
     nil)))

(provide 'sem-git-sync)
;;; sem-git-sync.el ends here
