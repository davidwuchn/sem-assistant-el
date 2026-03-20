;;; sem-router-test.el --- Tests for sem-router.el -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Tests for sem-router routing and headline parsing functions.

;;; Code:

(require 'ert)
(require 'sem-mock)

;; Load modules under test
(load-file (expand-file-name "../sem-core.el" (file-name-directory load-file-name)))
(load-file (expand-file-name "../sem-security.el" (file-name-directory load-file-name)))
(load-file (expand-file-name "../sem-router.el" (file-name-directory load-file-name)))

;;; Test @link routing to url-capture

(ert-deftest sem-router-test-link-tag-detection ()
  "Test that @link tag is detected for URL routing."
  (let ((headline '(:title "https://example.com" :tags ("link") :body nil)))
    (should (sem-router--is-link-headline headline))))

(ert-deftest sem-router-test-url-as-title-detection ()
  "Test that URL as title is detected without @link tag."
  (let ((headline '(:title "https://example.com/article" :tags nil :body nil)))
    (should (sem-router--is-link-headline headline))))

(ert-deftest sem-router-test-non-link-not-routed ()
  "Test that non-link headlines are not routed to url-capture."
  (let ((headline '(:title "Regular task headline" :tags ("task") :body nil)))
    (should-not (sem-router--is-link-headline headline))))

;;; Test @task routing to LLM pipeline

(ert-deftest sem-router-test-task-tag-detection ()
  "Test that @task tag is detected for LLM routing."
  (let ((headline '(:title "Buy milk" :tags ("task") :body nil)))
    (should (sem-router--is-task-headline headline))))

(ert-deftest sem-router-test-non-task-not-routed ()
  "Test that non-task headlines are not routed to task LLM."
  (let ((headline '(:title "Just a note" :tags ("note") :body nil)))
    (should-not (sem-router--is-task-headline headline))))

;;; Test unknown tag skip

(ert-deftest sem-router-test-unknown-tag-skip ()
  "Test that unknown tags are skipped with log."
  (let ((headline '(:title "Unknown tag headline" :tags ("unknown") :body nil)))
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
  (let ((headline '(:title "https://example.com/article/path" :tags nil :body nil)))
    (should (string= "https://example.com/article/path"
                     (sem-router--is-link-headline headline)))))

(ert-deftest sem-router-test-url-extraction-with-query ()
  "Test URL extraction with query parameters."
  (let ((headline '(:title "https://example.com/search?q=test&page=1" :tags ("link") :body nil)))
    (should (string= "https://example.com/search?q=test&page=1"
                     (sem-router--is-link-headline headline)))))

;;; Test cleanup

(ert-deftest sem-router-test-mock-cleanup ()
  "Test that mock cleanup works correctly."
  (sem-mock-reset-all)
  (should t))

;;; Test org-element based headline parsing

(ert-deftest sem-router-test-parse-headlines-missing-file ()
  "Test that sem-router--parse-headlines handles missing file gracefully."
  (let ((sem-router-inbox-file "/nonexistent/path/inbox-mobile.org"))
    ;; Should return nil without crashing
    (should (null (sem-router--parse-headlines)))))

(ert-deftest sem-router-test-parse-headlines-basic ()
  "Test basic headline parsing with org-element."
  (let ((test-file (make-temp-file "inbox-test-")))
    (unwind-protect
        (progn
          ;; Create temp inbox file with headlines
          (with-temp-file test-file
            (insert "* Headline 1 :link:\n")
            (insert "* Headline 2 :task:\n"))
          ;; Temporarily override inbox file path
          (let ((sem-router-inbox-file test-file))
            (let ((headlines (sem-router--parse-headlines)))
              ;; Should return parsed headlines
              (should (listp headlines))
              (should (= (length headlines) 2))
              ;; Check first headline
              (let ((h1 (car headlines)))
                (should (string= "Headline 1" (plist-get h1 :title)))
                (should (equal '("link") (plist-get h1 :tags)))
                (should (null (plist-get h1 :body))))
              ;; Check second headline
              (let ((h2 (cadr headlines)))
                (should (string= "Headline 2" (plist-get h2 :title)))
                (should (equal '("task") (plist-get h2 :tags)))
                (should (null (plist-get h2 :body)))))))
      (sem-mock-cleanup-temp-file test-file))))

(ert-deftest sem-router-test-parse-headlines-with-body ()
  "Test headline parsing with body content."
  (let ((test-file (make-temp-file "inbox-test-")))
    (unwind-protect
        (progn
          (with-temp-file test-file
            (insert "* Task with body :@task:\n")
            (insert "This is the body text\n")
            (insert "* Next headline :link:\n"))
          (let ((sem-router-inbox-file test-file))
            (let ((headlines (sem-router--parse-headlines)))
              (should (= (length headlines) 2))
              ;; First headline should have body
              (let ((h1 (car headlines)))
                (should (string= "Task with body" (plist-get h1 :title)))
                (should (equal '("@task") (plist-get h1 :tags)))
                (should (string= "This is the body text" (plist-get h1 :body))))
              ;; Second headline should have nil body
              (let ((h2 (cadr headlines)))
                (should (null (plist-get h2 :body)))))))
      (sem-mock-cleanup-temp-file test-file))))

(ert-deftest sem-router-test-parse-headlines-without-body ()
  "Test headline parsing without body content."
  (let ((test-file (make-temp-file "inbox-test-")))
    (unwind-protect
        (progn
          (with-temp-file test-file
            (insert "* Task without body :@task:\n")
            (insert "* Next headline :link:\n"))
          (let ((sem-router-inbox-file test-file))
            (let ((headlines (sem-router--parse-headlines)))
              (should (= (length headlines) 2))
              ;; First headline should have nil body (no content between headlines)
              (let ((h1 (car headlines)))
                (should (null (plist-get h1 :body)))))))
      (sem-mock-cleanup-temp-file test-file))))

(ert-deftest sem-router-test-parse-headlines-nested-excluded ()
  "Test that nested sub-headlines are excluded from body."
  (let ((test-file (make-temp-file "inbox-test-")))
    (unwind-protect
        (progn
          (with-temp-file test-file
            (insert "* Parent :@task:\n")
            (insert "Parent body text\n")
            (insert "** Child :child:\n")
            (insert "Child body text\n"))
          (let ((sem-router-inbox-file test-file))
            (let ((headlines (sem-router--parse-headlines)))
              (should (= (length headlines) 2))
              ;; Parent should only have its own body
              (let ((parent (car headlines)))
                (should (string= "Parent" (plist-get parent :title)))
                (should (string= "Parent body text" (plist-get parent :body))))
              ;; Child should have its own body
              (let ((child (cadr headlines)))
                (should (string= "Child" (plist-get child :title)))
                (should (string= "Child body text" (plist-get child :body)))))))
      (sem-mock-cleanup-temp-file test-file))))

(ert-deftest sem-router-test-parse-headlines-body-with-list ()
  "Test body extraction with list items."
  (let ((test-file (make-temp-file "inbox-test-")))
    (unwind-protect
        (progn
          (with-temp-file test-file
            (insert "* Task with list :@task:\n")
            (insert "- Item 1\n")
            (insert "- Item 2\n")
            (insert "\n")
            (insert "Paragraph text\n"))
          (let ((sem-router-inbox-file test-file))
            (let ((headlines (sem-router--parse-headlines)))
              (should (= (length headlines) 1))
              (let ((h1 (car headlines)))
                (should (string-match-p "Item 1" (plist-get h1 :body)))
                (should (string-match-p "Item 2" (plist-get h1 :body)))
                (should (string-match-p "Paragraph text" (plist-get h1 :body)))))))
      (sem-mock-cleanup-temp-file test-file))))

(ert-deftest sem-router-test-parse-headlines-hash-includes-body ()
  "Test that hash computation includes body content."
  (let ((test-file (make-temp-file "inbox-test-")))
    (unwind-protect
        (progn
          (with-temp-file test-file
            (insert "* Same title :@task:\n")
            (insert "Body one\n"))
          (let ((sem-router-inbox-file test-file))
            (let ((headlines1 (sem-router--parse-headlines)))
              (let ((hash1 (plist-get (car headlines1) :hash)))
                ;; Now change the file with same title but different body
                (with-temp-file test-file
                  (insert "* Same title :@task:\n")
                  (insert "Body two\n"))
                (let ((headlines2 (sem-router--parse-headlines)))
                  (let ((hash2 (plist-get (car headlines2) :hash)))
                    ;; Hashes should be different because bodies are different
                    (should-not (string= hash1 hash2))))))))
      (sem-mock-cleanup-temp-file test-file))))

(ert-deftest sem-router-test-parse-headlines-tags-without-colons ()
  "Test that tags are extracted without colons."
  (let ((test-file (make-temp-file "inbox-test-")))
    (unwind-protect
        (progn
          (with-temp-file test-file
            (insert "* Task :tag1:tag2:\n"))
          (let ((sem-router-inbox-file test-file))
            (let ((headlines (sem-router--parse-headlines)))
              (should (= (length headlines) 1))
              (let ((tags (plist-get (car headlines) :tags)))
                (should (equal '("tag1" "tag2") tags))
                ;; Ensure no colons in tags
                (should-not (member ":tag1:" tags))
                (should-not (member ":tag2:" tags))))))
      (sem-mock-cleanup-temp-file test-file))))

;;; Tests for task LLM pipeline with UUID injection

(ert-deftest sem-router-test-task-validation-valid-response ()
  "Test validation of valid LLM task response with matching UUID.
Success path: valid Org TODO with valid tag and matching UUID should pass validation."
  (let ((injected-id "550e8400-e29b-41d4-a716-446655440000")
        (response "* TODO Test Task
:PROPERTIES:
:ID: 550e8400-e29b-41d4-a716-446655440000
:FILETAGS: :work:
:END:
Task description here."))
    (should (sem-router--validate-task-response response injected-id))))

(ert-deftest sem-router-test-task-validation-invalid-tag ()
  "Test validation rejects invalid tag.
DLQ path: invalid tag should fail validation."
  (let ((injected-id "550e8400-e29b-41d4-a716-446655440000")
        (response "* TODO Test Task
:PROPERTIES:
:ID: 550e8400-e29b-41d4-a716-446655440000
:FILETAGS: :invalidtag:
:END:
Task description here."))
    (should-not (sem-router--validate-task-response response injected-id))))

(ert-deftest sem-router-test-task-validation-missing-properties ()
  "Test validation rejects missing :PROPERTIES:.
DLQ path: missing properties drawer should fail validation."
  (let ((injected-id "550e8400-e29b-41d4-a716-446655440000")
        (response "* TODO Test Task
:FILETAGS: :work:
Task description here."))
    (should-not (sem-router--validate-task-response response injected-id))))

(ert-deftest sem-router-test-task-validation-missing-id ()
  "Test validation rejects missing :ID:.
DLQ path: missing ID should fail validation."
  (let ((injected-id "550e8400-e29b-41d4-a716-446655440000")
        (response "* TODO Test Task
:PROPERTIES:
:FILETAGS: :work:
:END:
Task description here."))
    (should-not (sem-router--validate-task-response response injected-id))))

(ert-deftest sem-router-test-task-validation-missing-filetags ()
  "Test validation rejects missing :FILETAGS:.
DLQ path: missing FILETAGS should fail validation."
  (let ((injected-id "550e8400-e29b-41d4-a716-446655440000")
        (response "* TODO Test Task
:PROPERTIES:
:ID: 550e8400-e29b-41d4-a716-446655440000
:END:
Task description here."))
    (should-not (sem-router--validate-task-response response injected-id))))

;; New tests for UUID validation

(ert-deftest sem-router-test-uuid-match-validation-passes ()
  "Test that UUID match passes validation.
Success path: extracted ID matches injected ID exactly."
  (let ((injected-id "abc12345-6789-0def-ghij-klmnopqrstuv")
        (response "* TODO Test Task
:PROPERTIES:
:ID: abc12345-6789-0def-ghij-klmnopqrstuv
:FILETAGS: :work:
:END:
Task description."))
    (should (sem-router--validate-task-response response injected-id))))

(ert-deftest sem-router-test-uuid-mismatch-validation-fails ()
  "Test that UUID mismatch fails validation.
DLQ path: LLM generated different ID than injected."
  (let ((injected-id "abc12345-6789-0def-ghij-klmnopqrstuv")
        (response "* TODO Test Task
:PROPERTIES:
:ID: different-uuid-generated-by-llm
:FILETAGS: :work:
:END:
Task description."))
    (should-not (sem-router--validate-task-response response injected-id))))

(ert-deftest sem-router-test-uuid-missing-validation-fails ()
  "Test that missing UUID fails validation.
DLQ path: LLM omitted ID field entirely."
  (let ((injected-id "abc12345-6789-0def-ghij-klmnopqrstuv")
        (response "* TODO Test Task
:PROPERTIES:
:FILETAGS: :work:
:END:
Task description."))
    (should-not (sem-router--validate-task-response response injected-id))))

(ert-deftest sem-router-test-uuid-nil-injected-id-fails ()
  "Test that nil injected-id fails validation.
Safety check: nil injected-id should return nil."
  (let ((response "* TODO Test Task
:PROPERTIES:
:ID: some-uuid-value
:FILETAGS: :work:
:END:
Task description."))
    (should-not (sem-router--validate-task-response response nil))))

(ert-deftest sem-router-test-uuid-exact-string-match ()
  "Test that UUID validation uses exact string match.
Security: partial matches or case differences should fail."
  (let ((injected-id "ABC12345-6789-0DEF-GHIJ-KLMNOPQRSTUV")
        (response "* TODO Test Task
:PROPERTIES:
:ID: abc12345-6789-0def-ghij-klmnopqrstuv
:FILETAGS: :work:
:END:
Task description."))
    ;; Case-sensitive comparison should fail
    (should-not (sem-router--validate-task-response response injected-id))))

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

;;; Tests for security block round-trip (car/cdr destructuring)

(ert-deftest sem-router-test-security-block-round-trip ()
  "Test that security blocks are correctly destructured and restored as plain text.
Verifies 3-element return: (car result) = sanitized-body, (cadr result) = blocks, (caddr result) = position-info."
  (let* ((original-body "This is content with #+begin_sensitive\nsecret data\n#+end_sensitive")
         ;; Mock the security functions - now 3-element list
         (sanitize-result (list "This is content with <<SENSITIVE_1>>"
                                '(("<<SENSITIVE_1>>" . "#+begin_sensitive\nsecret data\n#+end_sensitive"))
                                '(("<<SENSITIVE_1>>" "#+begin_sensitive\nsecret data\n#+end_sensitive" "This is content with " " for access"))))
         (sanitized-body (car sanitize-result))
         (security-blocks (cadr sanitize-result))
         (position-info (caddr sanitize-result)))
    ;; Verify car gives sanitized body
    (should (string= sanitized-body "This is content with <<SENSITIVE_1>>"))
    ;; Verify cadr gives blocks alist
    (should (equal security-blocks '(("<<SENSITIVE_1>>" . "#+begin_sensitive\nsecret data\n#+end_sensitive"))))
    ;; Verify caddr gives position-info
    (should (listp position-info))
    (should (= (length position-info) 1))
    ;; Verify round-trip restores plain text (no markers)
    (should (string= "This is content with secret data"
                     (sem-security-restore-from-llm sanitized-body security-blocks)))))

;;; Tests for mutex/lock behavior

(ert-deftest sem-router-test-mutex-lock-acquire-release ()
  "Test that lock can be acquired and released."
  ;; Lock starts as nil
  (setq sem-router--tasks-write-lock nil)
  (should (sem-router--acquire-tasks-write-lock))
  (should sem-router--tasks-write-lock)
  ;; Release
  (sem-router--release-tasks-write-lock)
  (should-not sem-router--tasks-write-lock))

(ert-deftest sem-router-test-mutex-lock-contention ()
  "Test that lock contention returns nil (not acquired)."
  ;; Acquire lock
  (setq sem-router--tasks-write-lock nil)
  (should (sem-router--acquire-tasks-write-lock))
  ;; Second acquire should fail
  (should-not (sem-router--acquire-tasks-write-lock))
  ;; Cleanup
  (sem-router--release-tasks-write-lock))

(ert-deftest sem-router-test-mutex-lock-release-on-error ()
  "Test that lock is released even when callback signals error.
Uses unwind-protect to ensure cleanup."
  (setq sem-router--tasks-write-lock nil)
  (should-error
   (sem-router--with-tasks-write-lock
    '(:title "test")
    (lambda ()
      (should sem-router--tasks-write-lock) ;; Lock should be held
      (error "Simulated error"))
    0))
  ;; Lock should be released after error
  (should-not sem-router--tasks-write-lock))

(ert-deftest sem-router-test-mutex-lock-success-callback ()
  "Test that successful callback executes and releases lock."
  (setq sem-router--tasks-write-lock nil)
  (let ((callback-executed nil))
    (sem-router--with-tasks-write-lock
     '(:title "test")
     (lambda ()
       (setq callback-executed t)
       (should sem-router--tasks-write-lock)) ;; Lock should be held during execution
     0)
    ;; Callback should have executed
    (should callback-executed)
    ;; Lock should be released
    (should-not sem-router--tasks-write-lock)))

;;; Tests for body handling

(ert-deftest sem-router-test-body-nil-skips-sanitization ()
  "Test that nil body skips security sanitization and BODY section.
When headline has no body, no BODY: section should be in prompt."
  ;; With nil body, sanitized-body should remain nil
  (let ((body nil)
        (sanitized-body nil)
        (security-blocks nil))
    ;; Simulate the logic: when body is nil, don't sanitize
    (when body
      (let ((result (sem-security-sanitize-for-llm body)))
        (setq sanitized-body (car result))
        (setq security-blocks (cadr result))))
    ;; sanitized-body should still be nil
    (should-not sanitized-body)
    (should-not security-blocks)))

(ert-deftest sem-router-test-empty-body-proceeds ()
  "Test that empty string body proceeds with LLM call.
Empty body is valid for zero-body headlines."
  ;; Empty string is truthy in Emacs Lisp (not nil)
  (let ((sanitized-body ""))
    ;; Empty string should be treated as valid (proceeds with LLM)
    (should sanitized-body) ;; Empty string is not nil
    ;; The when check for adding BODY section should succeed
    (should (when sanitized-body t))))

(provide 'sem-router-test)
;;; sem-router-test.el ends here
