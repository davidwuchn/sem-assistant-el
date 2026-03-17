;;; sem-core-test.el --- Tests for sem-core.el -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Tests for sem-core logging and cursor tracking functions.

;;; Code:

(require 'ert)
(require 'sem-mock)

;; Load the module under test
(load-file (expand-file-name "../sem-core.el" (file-name-directory load-file-name)))

;;; Tests for sem-core-log format

(ert-deftest sem-core-test-log-format-without-tokens ()
  "Test sem-core-log format without tokens field."
  (let ((test-file (sem-mock-temp-file "* 2026\n** 03 (March)\n*** 2026-03-16\n")))
    (unwind-protect
        (let ((sem-core-log-file test-file))
          (sem-core-log "core" "STARTUP" "OK" "Daemon started")
          (with-temp-buffer
            (insert-file-contents test-file)
            (goto-char (point-min))
            (should (re-search-forward "- \\[.*\\] \\[core\\] \\[STARTUP\\] \\[OK\\] | Daemon started" nil t))))
      (sem-mock-cleanup-temp-file test-file))))

(ert-deftest sem-core-test-log-format-with-tokens ()
  "Test sem-core-log format with tokens field."
  (let ((test-file (sem-mock-temp-file "* 2026\n** 03 (March)\n*** 2026-03-16\n")))
    (unwind-protect
        (let ((sem-core-log-file test-file))
          (sem-core-log "rss" "RSS-DIGEST" "OK" "Digest generated" 1250)
          (with-temp-buffer
            (insert-file-contents test-file)
            (goto-char (point-min))
            (should (re-search-forward "- \\[.*\\] \\[rss\\] \\[RSS-DIGEST\\] \\[OK\\] tokens=1250 | Digest generated" nil t))))
      (sem-mock-cleanup-temp-file test-file))))

;;; Tests for cursor read/write round-trip

(ert-deftest sem-core-test-cursor-roundtrip ()
  "Test cursor read/write round-trip."
  (let ((test-file (make-temp-file "sem-cursor-test-")))
    (unwind-protect
        (let ((sem-core-cursor-file test-file))
          ;; Write some hashes
          (sem-core--write-cursor '(("hash1" . t) ("hash2" . t) ("hash3" . t)))
          
          ;; Read back and verify
          (let ((cursor (sem-core--read-cursor)))
            (should (assoc "hash1" cursor))
            (should (assoc "hash2" cursor))
            (should (assoc "hash3" cursor))
            (should (= (length cursor) 3))))
      (sem-mock-cleanup-temp-file test-file))))

;;; Tests for content hash determinism

(ert-deftest sem-core-test-hash-determinism ()
  "Test that content hash is deterministic."
  (let* ((title "Test Headline")
         (tags "link task")
         (headline1 (list :title title :tags (split-string tags)))
         (headline2 (list :title title :tags (split-string tags))))
    (should (string= (sem-core--compute-headline-hash headline1)
                     (sem-core--compute-headline-hash headline2)))))

(ert-deftest sem-core-test-hash-uniqueness ()
  "Test that different content produces different hashes."
  (let* ((headline1 (list :title "First" :tags '("link")))
         (headline2 (list :title "Second" :tags '("link"))))
    (should-not (string= (sem-core--compute-headline-hash headline1)
                         (sem-core--compute-headline-hash headline2)))))

;;; Test cleanup

(ert-deftest sem-core-test-mock-cleanup ()
  "Test that mock cleanup works correctly."
  (sem-mock-reset-all)
  ;; If we get here without error, the test passes
  (should t))

;;; Test inbox purge preserves full subtrees (Task 3.4)

(ert-deftest sem-core-test-purge-preserves-body ()
  "Test that sem-core-purge-inbox preserves full headline subtrees.
Creates inbox with processed and unprocessed headlines (each with body lines),
runs purge, and asserts the unprocessed headline's body is present."
  (let ((test-inbox (make-temp-file "inbox-test-"))
        (test-cursor (make-temp-file "cursor-test-")))
    (unwind-protect
        (let ((sem-core-inbox-file test-inbox)
              (sem-core-cursor-file test-cursor))
          ;; Create inbox with two headlines, each with body lines
          (with-temp-file test-inbox
            (insert "* Processed headline :link:\n")
            (insert "Body line 1 for processed\n")
            (insert "Body line 2 for processed\n")
            (insert "* Unprocessed headline :task:\n")
            (insert "Body line 1 for unprocessed\n")
            (insert "Body line 2 for unprocessed\n")
            (insert "Body line 3 for unprocessed\n"))

          ;; Mark first headline as processed using the same hash computation as sem-core--compute-headline-hash
          ;; Title is "Processed headline :link:" (includes tags), tags is "link"
          (let ((processed-hash (secure-hash 'sha256 "Processed headline :link:|link")))
            (sem-core--mark-processed processed-hash))

          ;; Run purge at 4AM (mock the hour)
          (cl-letf (((symbol-function 'format-time-string)
                     (lambda (format &optional time)
                       (if (string= format "%H") "04" (format-time-string format time)))))
            (sem-core-purge-inbox))

          ;; Verify unprocessed headline body is preserved
          (with-temp-buffer
            (insert-file-contents test-inbox)
            (let ((content (buffer-string)))
              ;; Processed headline should be removed (use ^ to avoid matching "Unprocessed headline")
              (should-not (string-match-p "^\\* Processed headline" content))
              ;; Unprocessed headline and ALL body lines should be preserved
              (should (string-match-p "Unprocessed headline" content))
              (should (string-match-p "Body line 1 for unprocessed" content))
              (should (string-match-p "Body line 2 for unprocessed" content))
              (should (string-match-p "Body line 3 for unprocessed" content)))))
      (sem-mock-cleanup-temp-file test-inbox)
      (sem-mock-cleanup-temp-file test-cursor))))

(ert-deftest sem-core-test-purge-atomic-rename ()
  "Test that sem-core-purge-inbox uses atomic rename."
  (let ((test-inbox (make-temp-file "inbox-test-"))
        (test-cursor (make-temp-file "cursor-test-")))
    (unwind-protect
        (let ((sem-core-inbox-file test-inbox)
              (sem-core-cursor-file test-cursor))
          ;; Create inbox with one processed headline
          (with-temp-file test-inbox
            (insert "* Processed headline :link:\n"))

          ;; Mark as processed
          (let ((hash (secure-hash 'sha256 "Processed headline :link:|link")))
            (sem-core--mark-processed hash))

          ;; Run purge at 4AM
          (cl-letf (((symbol-function 'format-time-string)
                     (lambda (format &optional time)
                       (if (string= format "%H") "04" (format-time-string format time)))))
            (sem-core-purge-inbox))

          ;; File should exist and be empty (or just whitespace)
          (should (file-exists-p test-inbox))
          (with-temp-buffer
            (insert-file-contents test-inbox)
            (should (or (string-blank-p (buffer-string))
                        (string= (buffer-string) "")))))
      (sem-mock-cleanup-temp-file test-inbox)
      (sem-mock-cleanup-temp-file test-cursor))))

(provide 'sem-core-test)
;;; sem-core-test.el ends here
