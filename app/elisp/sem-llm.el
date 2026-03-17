;;; sem-llm.el --- LLM integration wrapper -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; This module wraps gptel-request with a standard callback interface.
;; All LLM calls must go through this module - no direct gptel-request calls.

;;; Code:

(require 'gptel)
(require 'sem-core)

;;; LLM Request Wrapper

(defun sem-llm-request (prompt system-prompt callback &optional context)
  "Request LLM with PROMPT and SYSTEM-PROMPT.

CALLBACK is a function of (response info context) where:
  - RESPONSE is the LLM response text (or nil on error)
  - INFO is a plist with :status, :error, :tokens, etc.
  - CONTEXT is the optional context passed through

This wrapper handles:
- condition-case wrapping for all callbacks
- Logging via sem-core-log on success/failure
- Retry vs DLQ decision logic"
  (condition-case err
      (gptel-request
          prompt
        :system system-prompt
        :callback (lambda (response info)
                    (condition-case cb-err
                        (funcall callback response info context)
                      (error
                       (sem-core-log-error "llm" "ERROR"
                                           (format "Callback error: %s"
                                                   (error-message-string cb-err))
                                           prompt
                                           (when response response))))))
    (error
     (sem-core-log-error "llm" "ERROR"
                         (error-message-string err)
                         prompt
                         nil)
     (funcall callback nil (list :error (error-message-string err)) context))))

(defun sem-llm--handle-api-error (info hash context)
  "Handle API error (429, timeout).
Increments retry count and moves to DLQ after 3 failures.
INFO is the gptel response info plist.
HASH is the content hash for cursor tracking.
CONTEXT contains module and other metadata."
  (let ((status (plist-get info :status))
        (error-msg (plist-get info :error))
        (module (plist-get context :module))
        (headline (plist-get context :headline)))
    ;; Increment retry count
    (let ((new-count (sem-core--increment-retry hash)))
      (if (>= new-count 3)
          ;; Max retries reached - move to DLQ
          (progn
            (sem-core-log (or module "llm") "INBOX-ITEM" "DLQ"
                          (format "Max retries (%d) reached, moving to DLQ: %s" new-count (or error-msg status))
                          nil)
            (sem-core--mark-dlq hash 
                                (when headline (plist-get headline :title))
                                (format "API error after %d retries: %s" new-count (or error-msg status)))
            (message "SEM: Max retries reached, moved to DLQ"))
        ;; Will retry
        (progn
          (sem-core-log (or module "llm") "INBOX-ITEM" "RETRY"
                        (format "API error (attempt %d/3): %s" new-count (or error-msg status))
                        nil)
          (message "SEM: API error, will retry (attempt %d/3): %s" new-count (or error-msg status)))))))

(defun sem-llm--handle-malformed-output (response hash context)
  "Handle malformed LLM output.
Clears retry count, marks hash as processed and sends to DLQ (errors.org).
RESPONSE is the raw LLM response.
HASH is the content hash for cursor tracking.
CONTEXT contains module, headline, and other metadata."
  (let ((module (plist-get context :module))
        (headline (plist-get context :headline)))
    (sem-core-log-error (or module "llm") "INBOX-ITEM"
                        "Malformed LLM output"
                        (when headline (prin1-to-string headline))
                        response)
    ;; Clear retry count (permanent failure)
    (when hash
      (sem-core--clear-retry hash))
    ;; Mark as processed to prevent infinite retry loop
    (when hash
      (sem-core--mark-processed hash))
    (message "SEM: Malformed output sent to DLQ")))

(defun sem-llm--handle-success (response hash context)
  "Handle successful LLM response.
Calls the success callback if provided.
RESPONSE is the LLM response text.
HASH is the content hash for cursor tracking.
CONTEXT contains module, success-callback, and other metadata."
  (let ((module (plist-get context :module))
        (success-callback (plist-get context :success-callback))
        (tokens (plist-get context :tokens)))
    (sem-core-log (or module "llm") "INBOX-ITEM" "OK"
                  "LLM request successful"
                  tokens)
    ;; Clear retry count on success
    (when hash
      (sem-core--clear-retry hash))
    ;; Mark as processed
    (when hash
      (sem-core--mark-processed hash))
    ;; Call success callback
    (when success-callback
      (funcall success-callback response context))))

(provide 'sem-llm)
;;; sem-llm.el ends here
