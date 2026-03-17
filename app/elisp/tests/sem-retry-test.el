;;; sem-retry-test.el --- Tests for retry mechanism -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Tests for verifying the bounded retry mechanism and DLQ behavior.
;; These tests ensure that:
;; 1. Retry counts are tracked correctly
;; 2. Items are moved to DLQ after 3 failures
;; 3. Retry counts are cleared on success
;; 4. The retry file format is correct

;;; Code:

(require 'ert)
(require 'sem-core)
(require 'sem-llm)

;;; Test Helpers

(defvar sem-retry-test--temp-retries-file nil
  "Temporary file for retry tests.")

(defvar sem-retry-test--temp-cursor-file nil
  "Temporary file for cursor tests.")

(defun sem-retry-test--setup ()
  "Set up test environment."
  (setq sem-retry-test--temp-retries-file
        (make-temp-file "sem-retries-test-"))
  (setq sem-retry-test--temp-cursor-file
        (make-temp-file "sem-cursor-test-"))
  ;; Override the retries file constant for testing
  (advice-add 'sem-core--read-retries :around #'sem-retry-test--read-retries-advice)
  (advice-add 'sem-core--write-retries :around #'sem-retry-test--write-retries-advice)
  ;; Override the cursor file constant for testing
  (advice-add 'sem-core--read-cursor :around #'sem-retry-test--read-cursor-advice)
  (advice-add 'sem-core--write-cursor :around #'sem-retry-test--write-cursor-advice))

(defun sem-retry-test--teardown ()
  "Clean up test environment."
  (advice-remove 'sem-core--read-retries #'sem-retry-test--read-retries-advice)
  (advice-remove 'sem-core--write-retries #'sem-retry-test--write-retries-advice)
  (advice-remove 'sem-core--read-cursor #'sem-retry-test--read-cursor-advice)
  (advice-remove 'sem-core--write-cursor #'sem-retry-test--write-cursor-advice)
  (when (and sem-retry-test--temp-retries-file
             (file-exists-p sem-retry-test--temp-retries-file))
    (delete-file sem-retry-test--temp-retries-file))
  (when (and sem-retry-test--temp-cursor-file
             (file-exists-p sem-retry-test--temp-cursor-file))
    (delete-file sem-retry-test--temp-cursor-file))
  (setq sem-retry-test--temp-retries-file nil)
  (setq sem-retry-test--temp-cursor-file nil))

(defun sem-retry-test--read-retries-advice (orig-fun &rest args)
  "Advice to use temp file for retries."
  (let ((sem-core-retries-file sem-retry-test--temp-retries-file))
    (apply orig-fun args)))

(defun sem-retry-test--write-retries-advice (orig-fun &rest args)
  "Advice to use temp file for retries."
  (let ((sem-core-retries-file sem-retry-test--temp-retries-file))
    (apply orig-fun args)))

(defun sem-retry-test--read-cursor-advice (orig-fun &rest args)
  "Advice to use temp file for cursor."
  (let ((sem-core-cursor-file sem-retry-test--temp-cursor-file))
    (apply orig-fun args)))

(defun sem-retry-test--write-cursor-advice (orig-fun &rest args)
  "Advice to use temp file for cursor."
  (let ((sem-core-cursor-file sem-retry-test--temp-cursor-file))
    (apply orig-fun args)))

;;; Retry Count Tests

(ert-deftest sem-retry-test-get-count-empty ()
  "Test that get-retry-count returns 0 for unknown hash."
  (sem-retry-test--setup)
  (unwind-protect
      (let ((count (sem-core--get-retry-count "unknown-hash")))
        (should (= count 0)))
    (sem-retry-test--teardown)))

(ert-deftest sem-retry-test-increment-creates-entry ()
  "Test that increment-retry creates a new entry."
  (sem-retry-test--setup)
  (unwind-protect
      (let ((hash "test-hash-123"))
        ;; Initially should be 0
        (should (= (sem-core--get-retry-count hash) 0))
        ;; After increment should be 1
        (let ((new-count (sem-core--increment-retry hash)))
          (should (= new-count 1))
          (should (= (sem-core--get-retry-count hash) 1))))
    (sem-retry-test--teardown)))

(ert-deftest sem-retry-test-increment-updates-count ()
  "Test that increment-retry updates existing entry."
  (sem-retry-test--setup)
  (unwind-protect
      (let ((hash "test-hash-456"))
        ;; Increment multiple times
        (sem-core--increment-retry hash)
        (sem-core--increment-retry hash)
        (let ((new-count (sem-core--increment-retry hash)))
          (should (= new-count 3))
          (should (= (sem-core--get-retry-count hash) 3))))
    (sem-retry-test--teardown)))

(ert-deftest sem-retry-test-clear-removes-entry ()
  "Test that clear-retry removes the entry."
  (sem-retry-test--setup)
  (unwind-protect
      (let ((hash "test-hash-789"))
        ;; Create entry
        (sem-core--increment-retry hash)
        (should (= (sem-core--get-retry-count hash) 1))
        ;; Clear entry
        (sem-core--clear-retry hash)
        (should (= (sem-core--get-retry-count hash) 0)))
    (sem-retry-test--teardown)))

(ert-deftest sem-retry-test-should-retry-p ()
  "Test should-retry-p logic."
  (sem-retry-test--setup)
  (unwind-protect
      (let ((hash "test-hash-retry"))
        ;; 0 retries - should retry
        (should (sem-core--should-retry-p hash))
        ;; 1 retry - should retry
        (sem-core--increment-retry hash)
        (should (sem-core--should-retry-p hash))
        ;; 2 retries - should retry
        (sem-core--increment-retry hash)
        (should (sem-core--should-retry-p hash))
        ;; 3 retries - should NOT retry
        (sem-core--increment-retry hash)
        (should-not (sem-core--should-retry-p hash)))
    (sem-retry-test--teardown)))

;;; File Format Tests

(ert-deftest sem-retry-test-file-format ()
  "Test that retry file is written in correct format."
  (sem-retry-test--setup)
  (unwind-protect
      (progn
        ;; Create some entries
        (sem-core--increment-retry "hash1")
        (sem-core--increment-retry "hash2")
        (sem-core--increment-retry "hash2")
        ;; Read file directly and verify format
        (with-temp-buffer
          (insert-file-contents sem-retry-test--temp-retries-file)
          (goto-char (point-min))
          ;; Should be a valid Lisp list
          (let ((content (read (current-buffer))))
            (should (listp content))
            (should (= (length content) 2))
            ;; Check first entry
            (let ((entry1 (assoc "hash1" content)))
              (should entry1)
              (should (= (cdr entry1) 1)))
            ;; Check second entry
            (let ((entry2 (assoc "hash2" content)))
              (should entry2)
              (should (= (cdr entry2) 2))))))
    (sem-retry-test--teardown)))

(ert-deftest sem-retry-test-read-invalid-file ()
  "Test that read-retries handles invalid files gracefully."
  (sem-retry-test--setup)
  (unwind-protect
      (progn
        ;; Write invalid content
        (with-temp-file sem-retry-test--temp-retries-file
          (insert "not valid lisp"))
        ;; Should return nil, not signal error
        (let ((result (sem-core--read-retries)))
          (should (null result))))
    (sem-retry-test--teardown)))

;;; DLQ Tests

(ert-deftest sem-retry-test-mark-dlq-clears-retry ()
  "Test that mark-dlq clears retry count."
  (sem-retry-test--setup)
  (unwind-protect
      (let ((hash "test-hash-dlq"))
        ;; Set up retries
        (sem-core--increment-retry hash)
        (sem-core--increment-retry hash)
        (should (= (sem-core--get-retry-count hash) 2))
        ;; Mark as DLQ
        (sem-core--mark-dlq hash "Test Title")
        ;; Retry count should be cleared
        (should (= (sem-core--get-retry-count hash) 0)))
    (sem-retry-test--teardown)))

(ert-deftest sem-retry-test-mark-dlq-marks-processed ()
  "Test that mark-dlq marks hash as processed."
  (sem-retry-test--setup)
  (unwind-protect
      (let ((hash "test-hash-dlq2"))
        ;; Mark as DLQ
        (sem-core--mark-dlq hash "Test Title")
        ;; Should be marked as processed
        (should (sem-core--is-processed hash)))
    (sem-retry-test--teardown)))

;;; LLM Handler Tests

(ert-deftest sem-retry-test-handle-api-error-increments ()
  "Test that handle-api-error increments retry count."
  (sem-retry-test--setup)
  (unwind-protect
      (let ((hash "test-hash-api"))
        ;; Mock headline
        (let ((context (list :hash hash :headline '(:title "Test"))))
          ;; First error
          (sem-llm--handle-api-error '(:error "Timeout") hash context)
          (should (= (sem-core--get-retry-count hash) 1))
          ;; Second error
          (sem-llm--handle-api-error '(:error "Timeout") hash context)
          (should (= (sem-core--get-retry-count hash) 2))
          ;; Third error - should move to DLQ
          (sem-llm--handle-api-error '(:error "Timeout") hash context)
          ;; Retry count cleared after DLQ
          (should (= (sem-core--get-retry-count hash) 0))
          ;; Should be marked as processed
          (should (sem-core--is-processed hash))))
    (sem-retry-test--teardown)))

(ert-deftest sem-retry-test-handle-success-clears ()
  "Test that handle-success clears retry count."
  (sem-retry-test--setup)
  (unwind-protect
      (let ((hash "test-hash-success"))
        ;; Set up retries
        (sem-core--increment-retry hash)
        (sem-core--increment-retry hash)
        (should (= (sem-core--get-retry-count hash) 2))
        ;; Handle success
        (let ((context (list :hash hash)))
          (sem-llm--handle-success "Response" hash context)
          ;; Retry count should be cleared
          (should (= (sem-core--get-retry-count hash) 0))))
    (sem-retry-test--teardown)))

(ert-deftest sem-retry-test-handle-malformed-clears ()
  "Test that handle-malformed clears retry count."
  (sem-retry-test--setup)
  (unwind-protect
      (let ((hash "test-hash-malformed"))
        ;; Set up retries
        (sem-core--increment-retry hash)
        (should (= (sem-core--get-retry-count hash) 1))
        ;; Handle malformed
        (let ((context (list :hash hash :headline '(:title "Test"))))
          (sem-llm--handle-malformed-output "Bad response" hash context)
          ;; Retry count should be cleared (permanent failure)
          (should (= (sem-core--get-retry-count hash) 0))))
    (sem-retry-test--teardown)))

;;; Run Tests

(defun sem-retry-test-run-all ()
  "Run all retry tests."
  (interactive)
  (ert-run-tests-batch "^sem-retry-test"))

(provide 'sem-retry-test)
;;; sem-retry-test.el ends here
