;;; sem-llm.el --- LLM integration wrapper -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; This module wraps gptel-request with a standard callback interface.
;; All LLM calls must go through this module - no direct gptel-request calls.

;;; Code:

(require 'gptel)
(require 'sem-core)

;;; LLM Request Wrapper

(defun sem-llm--empty-string-p (value)
  "Return non-nil when VALUE is nil or empty after trim."
  (or (null value)
      (and (stringp value)
           (string-empty-p (string-trim value)))))

(defun sem-llm--resolve-model-for-tier (&optional tier)
  "Resolve concrete model identifier for TIER.
TIER accepts symbols `weak' or `medium'. Any other value defaults to `medium'.
`OPENROUTER_MODEL' is always required for medium/default behavior.
Weak tier falls back to `OPENROUTER_MODEL' when `OPENROUTER_WEAK_MODEL' is
unset or empty.

Returns a plist with keys :tier, :model, and :weak-fallback." 
  (let* ((requested-tier (if (eq tier 'weak) 'weak 'medium))
         (medium-model (getenv "OPENROUTER_MODEL"))
         (weak-model (getenv "OPENROUTER_WEAK_MODEL"))
         (weak-fallback nil)
         resolved-model)
    (when (sem-llm--empty-string-p medium-model)
      (error "OPENROUTER_MODEL environment variable is not set or empty"))
    (setq resolved-model
          (if (eq requested-tier 'weak)
              (if (sem-llm--empty-string-p weak-model)
                  (progn
                    (setq weak-fallback t)
                    medium-model)
                weak-model)
            medium-model))
    (list :tier requested-tier :model resolved-model :weak-fallback weak-fallback)))

(defun sem-llm-request (prompt system-prompt callback &optional context tier)
  "Request LLM with PROMPT and SYSTEM-PROMPT.

 CALLBACK is a function of (response info context) where:
   - RESPONSE is the LLM response text (or nil on error)
   - INFO is a plist with :status, :error, :tokens, etc.
   - CONTEXT is the optional context passed through

This wrapper handles:
- condition-case wrapping for all callbacks
- Logging via sem-core-log on success/failure
- Retry vs DLQ decision logic"
  (let* ((prompt-length (length prompt))
         (token-estimate (floor (length prompt) 4))
         (resolution (sem-llm--resolve-model-for-tier tier))
         (resolved-tier (plist-get resolution :tier))
         (resolved-model (plist-get resolution :model))
         (weak-fallback (plist-get resolution :weak-fallback)))
    (sem-core-log "llm" "REQUEST" "OK"
                  (format "Prompt length: %d chars, token estimate: %d, tier=%s, model=%s%s"
                          prompt-length token-estimate resolved-tier resolved-model
                          (if weak-fallback " (weak->medium fallback)" ""))
                  nil)
    (condition-case err
        (let ((gptel-model (intern resolved-model)))
          (gptel-request
              prompt
            :system system-prompt
            :callback (lambda (response info)
                        (condition-case cb-err
                            (if response
                                (progn
                                  (sem-core-log "llm" "RESPONSE" "OK"
                                                (format "Response length: %d chars" (length response))
                                                nil)
                                  (funcall callback response info context))
                              (progn
                                (sem-core-log-error "llm" "ERROR"
                                                    (format "Empty response from LLM")
                                                    prompt
                                                    nil)
                                (funcall callback nil (list :error "Empty response") context)))
                          (error
                           (sem-core-log-error "llm" "ERROR"
                                               (format "Callback error: %s"
                                                       (error-message-string cb-err))
                                               prompt
                                               (when response response)))))))
      (error
       (sem-core-log-error "llm" "ERROR"
                           (error-message-string err)
                           prompt
                           nil)
       (funcall callback nil (list :error (error-message-string err)) context)))))

(provide 'sem-llm)
;;; sem-llm.el ends here
