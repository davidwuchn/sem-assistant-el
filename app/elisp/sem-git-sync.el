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

(defun sem-git-sync--run-command (program args &optional dir)
  "Run PROGRAM with ARGS in DIR and return (exit-code . output).
Returns a cons cell where car is the exit code and cdr is the command output."
  (let ((default-directory (or dir default-directory))
        (output-buffer (generate-new-buffer " *git-sync-cmd*")))
    (unwind-protect
        (with-current-buffer output-buffer
          (erase-buffer)
          (condition-case err
              (let ((exit-code
                     (apply #'call-process program nil output-buffer nil args)))
                (cons exit-code (buffer-string)))
            (error
             (insert (error-message-string err))
             (cons 127 (buffer-string)))))
      (when (buffer-live-p output-buffer)
        (kill-buffer output-buffer)))))

(defun sem-git-sync--has-changes-p ()
  "Check if there are uncommitted changes in org-roam directory.
Returns t if there are changes to commit, nil otherwise."
  (let ((result (sem-git-sync--run-command "git" '("status" "--porcelain") sem-git-sync-org-roam-dir)))
    (and (= (car result) 0)
         (not (string-empty-p (string-trim (cdr result)))))))

(defun sem-git-sync--setup-ssh ()
  "Set up SSH agent and add the SSH key for GitHub authentication.
Returns (t . spawn) on success where spawn is t if a new agent was spawned,
nil if an existing agent was reused. Returns nil on failure."
  (condition-case err
      (cl-block sem-git-sync--setup-ssh
        ;; Check for existing SSH_AUTH_SOCK and valid socket file
        (let* ((existing-auth-sock (getenv "SSH_AUTH_SOCK"))
               (agent-spawned nil))

          ;; If SSH_AUTH_SOCK is set and socket exists, reuse existing agent
          (if (and existing-auth-sock
                   (file-exists-p existing-auth-sock))
              (progn
                (sem-core-log "git-sync" "GIT-SYNC" "OK"
                              (format "Reusing existing ssh-agent: %s" existing-auth-sock)
                              nil))

            ;; No valid existing agent - spawn a new one
             (let* ((agent-result (sem-git-sync--run-command "ssh-agent" '("-s")))
                    (agent-exit-code (car agent-result))
                    (agent-output (cdr agent-result)))
              (when (/= agent-exit-code 0)
                (sem-core-log "git-sync" "GIT-SYNC" "FAIL"
                              "Failed to start ssh-agent"
                              nil)
                (cl-return-from sem-git-sync--setup-ssh nil))

              ;; Parse SSH_AUTH_SOCK from output
              (let ((auth-sock nil)
                    (agent-pid nil))
                (when (string-match "SSH_AUTH_SOCK=\\([^;]+\\)" agent-output)
                  (setq auth-sock (match-string 1 agent-output)))
                (when (string-match "SSH_AGENT_PID=\\([0-9]+\\)" agent-output)
                  (setq agent-pid (match-string 1 agent-output)))

                ;; Check if both values were parsed successfully
                (unless (and auth-sock agent-pid)
                  (sem-core-log "git-sync" "GIT-SYNC" "FAIL"
                                (format "Failed to parse ssh-agent output: SOCK=%s PID=%s"
                                        (or auth-sock "nil") (or agent-pid "nil"))
                                nil)
                  (cl-return-from sem-git-sync--setup-ssh nil))

                ;; Set environment variables in Emacs process
                (setenv "SSH_AUTH_SOCK" auth-sock)
                (setenv "SSH_AGENT_PID" agent-pid)
                (setq agent-spawned t)
                (sem-core-log "git-sync" "GIT-SYNC" "OK"
                              (format "Spawned new ssh-agent: PID=%s" agent-pid)
                              nil))))

          ;; Add SSH key
          (if (file-exists-p sem-git-sync-ssh-key)
              (let ((add-result (sem-git-sync--run-command
                                 "ssh-add" (list sem-git-sync-ssh-key))))
                (if (= (car add-result) 0)
                    (cons t agent-spawned)
                  (sem-core-log "git-sync" "GIT-SYNC" "FAIL"
                                (format "Failed to add SSH key: %s" (cdr add-result))
                                nil)
                  nil))
            (sem-core-log "git-sync" "GIT-SYNC" "FAIL"
                          (format "SSH key not found at %s" sem-git-sync-ssh-key)
                          nil)
            nil)))
    (error
     (sem-core-log-error "git-sync" "GIT-SYNC"
                         (format "SSH setup error: %s" (error-message-string err))
                         nil
                         nil)
     nil)))

(defun sem-git-sync--teardown-ssh (agent-spawned-this-cycle)
  "Teardown SSH agent after git operations.
AGENT-SPAWNED-THIS-CYCLE is t if the agent was spawned in this sync cycle.
Only kills the agent if it was spawned by this cycle (not pre-existing).
Handles nil SSH_AGENT_PID gracefully."
  (when agent-spawned-this-cycle
    (let ((agent-pid (getenv "SSH_AGENT_PID")))
      (if (and agent-pid (not (string-empty-p agent-pid)))
          (progn
            (sem-git-sync--run-command "ssh-agent" '("-k"))
            (sem-core-log "git-sync" "GIT-SYNC" "OK"
                          (format "Killed ssh-agent PID=%s" agent-pid)
                          nil))
        (sem-core-log "git-sync" "GIT-SYNC" "SKIP"
                      "SSH_AGENT_PID not set, cannot kill agent"
                      nil)))))

;;; Main Entry Point

;;;###autoload
(defun sem-git-sync-org-roam ()
  "Synchronize org-roam directory to remote GitHub repository.

This is the cron entry point. It:
1. Checks if /data/org-roam is a git repository
2. Sets up SSH authentication (reuses existing agent if available)
3. Checks for uncommitted changes (respecting .gitignore)
4. Commits all changes with timestamp
5. Pushes to origin
6. Tears down SSH agent (if spawned in this cycle)

Returns t on success, nil on failure or when no changes to sync.
Uses unwind-protect to ensure agent teardown runs even on failure."
  (condition-case err
      (cl-block sem-git-sync-org-roam
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
        (let ((git-check (sem-git-sync--run-command "git" '("rev-parse" "--git-dir") sem-git-sync-org-roam-dir)))
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

        ;; Set up SSH and track if we spawned a new agent
        (let* ((ssh-setup-result (sem-git-sync--setup-ssh))
               (sem-git-sync--agent-spawned-this-cycle (and ssh-setup-result (cdr ssh-setup-result)))
               (push-success nil))

          (unless ssh-setup-result
            (cl-return-from sem-git-sync-org-roam nil))

          ;; Use unwind-protect to ensure teardown runs on success, failure, or condition
          (unwind-protect
              (progn
                ;; Stage all changes
                (let ((add-result (sem-git-sync--run-command "git" '("add" "-A") sem-git-sync-org-roam-dir)))
                  (when (/= (car add-result) 0)
                    (sem-core-log "git-sync" "GIT-SYNC" "FAIL"
                                  (format "Failed to stage changes: %s" (cdr add-result))
                                  nil)
                    (cl-return-from sem-git-sync-org-roam nil)))

                ;; Commit with timestamp
                (let* ((timestamp (format-time-string "%Y-%m-%d %H:%M:%S"))
                       (commit-msg (format "Sync org-roam: %s" timestamp))
                       (commit-result (sem-git-sync--run-command
                                       "git" (list "commit" "-m" commit-msg)
                                       sem-git-sync-org-roam-dir)))
                  (when (/= (car commit-result) 0)
                    (sem-core-log "git-sync" "GIT-SYNC" "FAIL"
                                  (format "Failed to commit: %s" (cdr commit-result))
                                  nil)
                    (cl-return-from sem-git-sync-org-roam nil)))

                ;; Push to origin
                (let ((push-result (sem-git-sync--run-command "git" '("push" "origin") sem-git-sync-org-roam-dir)))
                  (when (/= (car push-result) 0)
                    (sem-core-log "git-sync" "GIT-SYNC" "FAIL"
                                  (format "Failed to push: %s" (cdr push-result))
                                  nil)
                    (cl-return-from sem-git-sync-org-roam nil)))

                ;; Mark push as successful
                (setq push-success t)

                ;; Success
                (sem-core-log "git-sync" "GIT-SYNC" "OK"
                              "Successfully synced org-roam to GitHub"
                              nil)
                (message "SEM: Git sync complete"))

            ;; Cleanup: always run teardown (even on failure or condition)
            (sem-git-sync--teardown-ssh sem-git-sync--agent-spawned-this-cycle))

          push-success))
    (error
     (sem-core-log-error "git-sync" "GIT-SYNC"
                         (error-message-string err)
                         nil
                         nil)
     (message "SEM: Git sync error: %s" (error-message-string err))
     nil)))

(provide 'sem-git-sync)
;;; sem-git-sync.el ends here
