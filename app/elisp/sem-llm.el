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

(provide 'sem-llm)
;;; sem-llm.el ends here
