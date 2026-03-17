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

;;; Test cl-block wrapper for parse-headlines (Task 6.1-6.2)

(ert-deftest sem-router-test-parse-headlines-cl-block ()
  "Test that sem-router--parse-headlines has cl-block wrapper and doesn't crash.
This proves the cl-block fix at runtime, not just parse time."
  (let ((test-file (make-temp-file "inbox-test-")))
    (unwind-protect
        (progn
          ;; Create temp inbox file with headlines
          (with-temp-file test-file
            (insert "* Headline 1 :link:\n")
            (insert "Body line 1\n")
            (insert "* Headline 2 :task:\n")
            (insert "Body line 2\n"))
          ;; Temporarily override inbox file path
          (let ((sem-router-inbox-file test-file))
            ;; This should NOT crash with cl-return-from
            (let ((headlines (sem-router--parse-headlines)))
              ;; Should return parsed headlines
              (should (listp headlines))
              (should (= (length headlines) 2)))))
      (sem-mock-cleanup-temp-file test-file))))

(ert-deftest sem-router-test-parse-headlines-missing-file ()
  "Test that sem-router--parse-headlines handles missing file gracefully."
  (let ((sem-router-inbox-file "/nonexistent/path/inbox-mobile.org"))
    ;; Should return nil without crashing
    (should (null (sem-router--parse-headlines)))))

;;; Tests for task LLM pipeline (Task 7.1-7.5)

(ert-deftest sem-router-test-task-validation-valid-response ()
  "Test validation of valid LLM task response.
Success path: valid Org TODO with valid tag should pass validation."
  (let ((response "* TODO Test Task
:PROPERTIES:
:ID: 550e8400-e29b-41d4-a716-446655440000
:FILETAGS: :work:
:END:
Task description here."))
    (should (sem-router--validate-task-response response))))

(ert-deftest sem-router-test-task-validation-invalid-tag ()
  "Test validation rejects invalid tag.
DLQ path: invalid tag should fail validation."
  (let ((response "* TODO Test Task
:PROPERTIES:
:ID: 550e8400-e29b-41d4-a716-446655440000
:FILETAGS: :invalidtag:
:END:
Task description here."))
    (should-not (sem-router--validate-task-response response))))

(ert-deftest sem-router-test-task-validation-missing-properties ()
  "Test validation rejects missing :PROPERTIES:.
DLQ path: missing properties drawer should fail validation."
  (let ((response "* TODO Test Task
:FILETAGS: :work:
Task description here."))
    (should-not (sem-router--validate-task-response response))))

(ert-deftest sem-router-test-task-validation-missing-id ()
  "Test validation rejects missing :ID:.
DLQ path: missing ID should fail validation."
  (let ((response "* TODO Test Task
:PROPERTIES:
:FILETAGS: :work:
:END:
Task description here."))
    (should-not (sem-router--validate-task-response response))))

(ert-deftest sem-router-test-task-validation-missing-filetags ()
  "Test validation rejects missing :FILETAGS:.
DLQ path: missing FILETAGS should fail validation."
  (let ((response "* TODO Test Task
:PROPERTIES:
:ID: 550e8400-e29b-41d4-a716-446655440000
:END:
Task description here."))
    (should-not (sem-router--validate-task-response response))))

(ert-deftest sem-router-test-task-tag-normalization-routine-default ()
  "Test that absent or invalid tag is substituted with :routine:.
Tag validation test: missing FILETAGS results in :routine: default."
  (let ((response "* TODO Test Task
:PROPERTIES:
:ID: 550e8400-e29b-41d4-a716-446655440000
:END:
Task description here."))
    (let ((normalized (sem-router--validate-and-normalize-tag response)))
      (should (string-match-p ":FILETAGS: :routine:" normalized)))))

(ert-deftest sem-router-test-task-tag-normalization-invalid-substituted ()
  "Test that invalid tag is substituted with :routine:.
Tag validation test: invalid tag substituted with :routine:."
  (let ((response "* TODO Test Task
:PROPERTIES:
:ID: 550e8400-e29b-41d4-a716-446655440000
:FILETAGS: :badtag:
:END:
Task description here."))
    (let ((normalized (sem-router--validate-and-normalize-tag response)))
      (should (string-match-p ":FILETAGS: :routine:" normalized))
      (should-not (string-match-p ":FILETAGS: :badtag:" normalized)))))

(ert-deftest sem-router-test-task-tag-normalization-valid-preserved ()
  "Test that valid tag is preserved.
Success path: valid tag from allowed list is preserved."
  (let ((response "* TODO Test Task
:PROPERTIES:
:ID: 550e8400-e29b-41d4-a716-446655440000
:FILETAGS: :opensource:
:END:
Task description here."))
    (let ((normalized (sem-router--validate-and-normalize-tag response)))
      (should (string-match-p ":FILETAGS: :opensource:" normalized)))))

(ert-deftest sem-router-test-task-write-creates-file ()
  "Test that tasks.org is created if absent.
Success path: tasks.org auto-created on first write."
  (let ((test-tasks-file (make-temp-file "tasks-test-")))
    (unwind-protect
        (progn
          (delete-file test-tasks-file)
          (let ((sem-router-tasks-file test-tasks-file))
            (let ((response "* TODO Test Task
:PROPERTIES:
:ID: 550e8400-e29b-41d4-a716-446655440000
:FILETAGS: :routine:
:END:
Task description here."))
              (should (sem-router--write-task-to-file response))
              ;; File should now exist
              (should (file-exists-p test-tasks-file)))))
      (when (file-exists-p test-tasks-file)
        (sem-mock-cleanup-temp-file test-tasks-file)))))

(provide 'sem-router-test)
;;; sem-router-test.el ends here
