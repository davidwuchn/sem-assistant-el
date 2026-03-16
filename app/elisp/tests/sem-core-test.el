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

(provide 'sem-core-test)
;;; sem-core-test.el ends here
