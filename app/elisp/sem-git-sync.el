;;; sem-git-sync.el --- Git synchronization for org-roam -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; This module provides automated Git synchronization for the org-roam directory.
;; It commits all changes and pushes to origin on a cron schedule.
;;
;; Entry point: sem-git-sync-org-roam (callable from cron)

;;; Code:

(require 'sem-core)
(require 'cl-lib)

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

(defun sem-git-sync--parse-upstream (upstream)
  "Parse UPSTREAM string into (REMOTE . BRANCH).
UPSTREAM is expected in format `remote/branch'. Returns nil on parse failure."
  (when (and (stringp upstream)
             (string-match "\\`\\([^/]+\\)/\\(.+\\)\\'" upstream))
    (cons (match-string 1 upstream)
          (match-string 2 upstream))))

(defun sem-git-sync--sync-state ()
  "Return repository sync state for `sem-git-sync-org-roam-dir'.
The returned plist contains:
- :ok             Non-nil when state checks succeeded.
- :dirty          Non-nil when working tree has uncommitted changes.
- :ahead          Local commits ahead of upstream.
- :behind         Upstream commits ahead of local branch.
- :upstream       Tracked upstream ref (for example, `origin/main').
- :remote         Upstream remote name.
- :branch         Upstream branch name.
- :sync-needed    Non-nil when dirty or ahead > 0.
- :error          Optional error message when checks fail.

When no upstream is configured, :ok is nil and :error is set."
  (let* ((status-result
          (sem-git-sync--run-command "git" '("status" "--porcelain") sem-git-sync-org-roam-dir))
         (dirty (and (= (car status-result) 0)
                     (not (string-empty-p (string-trim (cdr status-result))))))
         (upstream-result
          (sem-git-sync--run-command "git"
                                     '("rev-parse" "--abbrev-ref" "--symbolic-full-name" "@{u}")
                                     sem-git-sync-org-roam-dir)))
    (if (/= (car upstream-result) 0)
        (list :ok nil
              :dirty dirty
              :ahead 0
              :behind 0
              :sync-needed dirty
              :error (format "Upstream not configured: %s" (string-trim (cdr upstream-result))))
      (let* ((upstream (string-trim (cdr upstream-result)))
             (upstream-parts (sem-git-sync--parse-upstream upstream))
             (divergence-result
              (sem-git-sync--run-command "git"
                                         '("rev-list" "--left-right" "--count" "@{u}...HEAD")
                                         sem-git-sync-org-roam-dir))
             (divergence-output (string-trim (cdr divergence-result)))
             (counts (split-string divergence-output "[ \t\n]+" t))
             (behind 0)
             (ahead 0))
        (if (or (/= (car divergence-result) 0)
                (< (length counts) 2)
                (null upstream-parts))
            (list :ok nil
                  :dirty dirty
                  :ahead 0
                  :behind 0
                  :sync-needed dirty
                  :error (format "Failed to compute branch divergence: %s"
                                 (string-trim (cdr divergence-result))))
          (setq behind (string-to-number (nth 0 counts)))
          (setq ahead (string-to-number (nth 1 counts)))
          (list :ok t
                :dirty dirty
                :ahead ahead
                :behind behind
                :upstream upstream
                :remote (car upstream-parts)
                :branch (cdr upstream-parts)
                :sync-needed (or dirty (> ahead 0))))))))

(defun sem-git-sync--classify-git-failure (output)
  "Classify git failure OUTPUT into a stable keyword symbol.
Returns one of: conflict, auth, network, other."
  (let ((text (downcase (or output ""))))
    (cond
     ((or (string-match-p "conflict" text)
          (string-match-p "could not apply" text)
          (string-match-p "merge conflict" text)
          (string-match-p "resolve all conflicts" text))
      'conflict)
     ((or (string-match-p "auth" text)
          (string-match-p "permission denied" text)
          (string-match-p "could not read from remote repository" text)
          (string-match-p "repository not found" text)
          (string-match-p "access denied" text))
      'auth)
     ((or (string-match-p "timed out" text)
          (string-match-p "could not resolve host" text)
          (string-match-p "failed to connect" text)
          (string-match-p "connection reset" text)
          (string-match-p "network is unreachable" text)
          (string-match-p "temporary failure" text))
      'network)
     (t 'other))))

(defun sem-git-sync--pull-before-push (remote branch)
  "Run pull reconciliation for REMOTE and BRANCH.
Returns t on success. On failure, logs classified failure and returns nil."
  (let* ((pull-result (sem-git-sync--run-command
                       "git" (list "pull" "--rebase" remote branch) sem-git-sync-org-roam-dir))
         (pull-output (cdr pull-result)))
    (if (= (car pull-result) 0)
        t
      (let ((classification (sem-git-sync--classify-git-failure pull-output)))
        (sem-core-log "git-sync" "GIT-SYNC" "FAIL"
                      (format "Pull failed (%s): %s" classification (string-trim pull-output))
                      nil)
        nil))))

(defun sem-git-sync--push-with-classification (remote)
  "Run push to REMOTE and classify failures.
Returns t on success, nil on failure."
  (let* ((push-result (sem-git-sync--run-command "git" (list "push" remote) sem-git-sync-org-roam-dir))
         (push-output (cdr push-result)))
    (if (= (car push-result) 0)
        t
      (let ((classification (sem-git-sync--classify-git-failure push-output)))
        (sem-core-log "git-sync" "GIT-SYNC" "FAIL"
                      (format "Push failed (%s): %s" classification (string-trim push-output))
                      nil)
        nil))))

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
3. Computes sync-needed state from dirty tree + upstream divergence
4. Commits local changes (when dirty)
5. Pulls before push (mandatory for sync-needed)
6. Pushes pending commits to upstream remote
7. Tears down SSH agent (if spawned in this cycle)

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

        (let ((initial-state (sem-git-sync--sync-state)))
          (unless (plist-get initial-state :ok)
            (sem-core-log "git-sync" "GIT-SYNC" "FAIL"
                          (plist-get initial-state :error)
                          nil)
            (cl-return-from sem-git-sync-org-roam nil))

          (unless (plist-get initial-state :sync-needed)
            (sem-core-log "git-sync" "GIT-SYNC" "SKIP"
                          "No sync needed (clean tree and not ahead of upstream)"
                          nil)
            (message "SEM: Git sync - no sync needed")
            (cl-return-from sem-git-sync-org-roam t))

          ;; Set up SSH and track if we spawned a new agent
          (let* ((ssh-setup-result (sem-git-sync--setup-ssh))
                 (sem-git-sync--agent-spawned-this-cycle (and ssh-setup-result (cdr ssh-setup-result)))
                 (sync-success nil))

            (unless ssh-setup-result
              (cl-return-from sem-git-sync-org-roam nil))

            ;; Use unwind-protect to ensure teardown runs on success, failure, or condition
            (unwind-protect
                (progn
                  ;; Stage + commit only when tree is dirty
                  (when (plist-get initial-state :dirty)
                    (let ((add-result (sem-git-sync--run-command "git" '("add" "-A") sem-git-sync-org-roam-dir)))
                      (when (/= (car add-result) 0)
                        (sem-core-log "git-sync" "GIT-SYNC" "FAIL"
                                      (format "Failed to stage changes: %s" (cdr add-result))
                                      nil)
                        (cl-return-from sem-git-sync-org-roam nil)))

                    (let* ((timestamp (format-time-string "%Y-%m-%d %H:%M:%S"))
                           (commit-msg (format "Sync org-roam: %s" timestamp))
                           (commit-result (sem-git-sync--run-command
                                           "git" (list "commit" "-m" commit-msg)
                                           sem-git-sync-org-roam-dir))
                           (commit-output (string-trim (cdr commit-result))))
                      (when (/= (car commit-result) 0)
                        (if (string-match-p "nothing to commit" (downcase commit-output))
                            (sem-core-log "git-sync" "GIT-SYNC" "SKIP"
                                          "Commit skipped (nothing to commit after stage)"
                                          nil)
                          (sem-core-log "git-sync" "GIT-SYNC" "FAIL"
                                        (format "Failed to commit: %s" commit-output)
                                        nil)
                          (cl-return-from sem-git-sync-org-roam nil)))))

                  ;; Recompute sync state after optional commit so ahead/behind is current.
                  (let ((state (sem-git-sync--sync-state)))
                    (unless (plist-get state :ok)
                      (sem-core-log "git-sync" "GIT-SYNC" "FAIL"
                                    (plist-get state :error)
                                    nil)
                      (cl-return-from sem-git-sync-org-roam nil))

                    (if (<= (plist-get state :ahead) 0)
                        (progn
                          (sem-core-log "git-sync" "GIT-SYNC" "OK"
                                        "Sync complete: no local commits ahead after reconciliation"
                                        nil)
                          (setq sync-success t)
                          (message "SEM: Git sync complete (no ahead commits)"))
                      (let ((remote (plist-get state :remote))
                            (branch (plist-get state :branch)))
                        (unless (sem-git-sync--pull-before-push remote branch)
                          (cl-return-from sem-git-sync-org-roam nil))
                        (unless (sem-git-sync--push-with-classification remote)
                          (cl-return-from sem-git-sync-org-roam nil))
                        (sem-core-log "git-sync" "GIT-SYNC" "OK"
                                      "Successfully synced org-roam to upstream"
                                      nil)
                        (setq sync-success t)
                        (message "SEM: Git sync complete")))))

              ;; Cleanup: always run teardown (even on failure or condition)
              (sem-git-sync--teardown-ssh sem-git-sync--agent-spawned-this-cycle))

            sync-success)))
    (error
     (sem-core-log-error "git-sync" "GIT-SYNC"
                         (error-message-string err)
                         nil
                         nil)
     (message "SEM: Git sync error: %s" (error-message-string err))
     nil)))

;;;###autoload
(defun sem-git-sync-org-roam-prepull ()
  "Run pull-only reconciliation for org-roam repository.

This entry point validates repository/upstream state and performs
`git pull --rebase <remote> <branch>' without creating commits or pushing.
Returns t on success and nil on failure."
  (condition-case err
      (cl-block sem-git-sync-org-roam-prepull
        (sem-core-log "git-sync" "GIT-SYNC" "OK"
                      "Starting org-roam pre-pull"
                      nil)

        (unless (file-directory-p sem-git-sync-org-roam-dir)
          (sem-core-log "git-sync" "GIT-SYNC" "FAIL"
                        (format "Directory does not exist: %s" sem-git-sync-org-roam-dir)
                        nil)
          (cl-return-from sem-git-sync-org-roam-prepull nil))

        (let ((git-check (sem-git-sync--run-command "git" '("rev-parse" "--git-dir") sem-git-sync-org-roam-dir)))
          (when (or (/= (car git-check) 0)
                    (string-empty-p (string-trim (cdr git-check))))
            (sem-core-log "git-sync" "GIT-SYNC" "FAIL"
                          (format "Not a git repository: %s" sem-git-sync-org-roam-dir)
                          nil)
            (cl-return-from sem-git-sync-org-roam-prepull nil)))

        (let ((state (sem-git-sync--sync-state)))
          (unless (plist-get state :ok)
            (sem-core-log "git-sync" "GIT-SYNC" "FAIL"
                          (plist-get state :error)
                          nil)
            (cl-return-from sem-git-sync-org-roam-prepull nil))

          (let* ((ssh-setup-result (sem-git-sync--setup-ssh))
                 (sem-git-sync--agent-spawned-this-cycle (and ssh-setup-result (cdr ssh-setup-result))))
            (unless ssh-setup-result
              (cl-return-from sem-git-sync-org-roam-prepull nil))

            (unwind-protect
                (let* ((remote (plist-get state :remote))
                       (branch (plist-get state :branch))
                       (pull-result (sem-git-sync--run-command
                                     "git" (list "pull" "--rebase" remote branch) sem-git-sync-org-roam-dir))
                       (pull-output (string-trim (cdr pull-result))))
                  (if (= (car pull-result) 0)
                      (progn
                        (sem-core-log "git-sync" "GIT-SYNC" "OK"
                                      "Pre-pull completed successfully"
                                      nil)
                        (message "SEM: Git pre-pull complete")
                        t)
                    (let ((classification (sem-git-sync--classify-git-failure pull-output)))
                      (sem-core-log "git-sync" "GIT-SYNC" "FAIL"
                                    (format "Pre-pull failed (%s): %s" classification pull-output)
                                    nil)
                      nil)))
              (sem-git-sync--teardown-ssh sem-git-sync--agent-spawned-this-cycle)))))
    (error
     (sem-core-log-error "git-sync" "GIT-SYNC"
                         (format "Pre-pull error: %s" (error-message-string err))
                         nil
                         nil)
     (message "SEM: Git pre-pull error: %s" (error-message-string err))
     nil)))

(provide 'sem-git-sync)
;;; sem-git-sync.el ends here
