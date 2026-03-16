;;; sem-router-test.el --- Tests for sem-router.el -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Tests for sem-router routing and headline parsing functions.

;;; Code:

(require 'ert)
(require 'sem-mock)

;; Load modules under test
(load-file (expand-file-name "../sem-core.el" (file-name-directory load-file-name)))
(load-file (expand-file-name "../sem-router.el" (file-name-directory load-file-name)))

;;; Test @link routing to url-capture

(ert-deftest sem-router-test-link-tag-detection ()
  "Test that @link tag is detected for URL routing."
  (let ((headline '(:title "https://example.com" :tags ("link"))))
    (should (sem-router--is-link-headline headline))))

(ert-deftest sem-router-test-url-as-title-detection ()
  "Test that URL as title is detected without @link tag."
  (let ((headline '(:title "https://example.com/article" :tags nil)))
    (should (sem-router--is-link-headline headline))))

(ert-deftest sem-router-test-non-link-not-routed ()
  "Test that non-link headlines are not routed to url-capture."
  (let ((headline '(:title "Regular task headline" :tags ("task"))))
    (should-not (sem-router--is-link-headline headline))))

;;; Test @task routing to LLM pipeline

(ert-deftest sem-router-test-task-tag-detection ()
  "Test that @task tag is detected for LLM routing."
  (let ((headline '(:title "Buy milk" :tags ("task"))))
    (should (sem-router--is-task-headline headline))))

(ert-deftest sem-router-test-non-task-not-routed ()
  "Test that non-task headlines are not routed to task LLM."
  (let ((headline '(:title "Just a note" :tags ("note"))))
    (should-not (sem-router--is-task-headline headline))))

;;; Test unknown tag skip

(ert-deftest sem-router-test-unknown-tag-skip ()
  "Test that unknown tags are skipped with log."
  (let ((headline '(:title "Unknown tag headline" :tags ("unknown"))))
    (should-not (sem-router--is-link-headline headline))
    (should-not (sem-router--is-task-headline headline))))

;;; Test already-processed hash skip

(ert-deftest sem-router-test-processed-hash-skip ()
  "Test that already-processed hashes are skipped."
  (let ((hash "test-hash-12345")
        (test-file (make-temp-file "sem-cursor-test-")))
    (unwind-protect
        (let ((sem-core-cursor-file test-file))
          ;; Mark as processed
          (sem-core--mark-processed hash)
          ;; Should be detected as processed
          (should (sem-router--is-processed hash)))
      (sem-mock-cleanup-temp-file test-file))))

;;; Test URL extraction from headline title

(ert-deftest sem-router-test-url-extraction ()
  "Test URL extraction from headline title."
  (let ((headline '(:title "https://example.com/article/path" :tags nil)))
    (should (string= "https://example.com/article/path"
                     (sem-router--is-link-headline headline)))))

(ert-deftest sem-router-test-url-extraction-with-query ()
  "Test URL extraction with query parameters."
  (let ((headline '(:title "https://example.com/search?q=test&page=1" :tags ("link"))))
    (should (string= "https://example.com/search?q=test&page=1"
                     (sem-router--is-link-headline headline)))))

;;; Test cleanup

(ert-deftest sem-router-test-mock-cleanup ()
  "Test that mock cleanup works correctly."
  (sem-mock-reset-all)
  (should t))

(provide 'sem-router-test)
;;; sem-router-test.el ends here
