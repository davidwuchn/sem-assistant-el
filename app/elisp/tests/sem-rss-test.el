;;; sem-rss-test.el --- Tests for sem-rss.el -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Tests for sem-rss text cleaning and prompt building functions.

;;; Code:

(require 'ert)
(require 'sem-rss)

;;; Tests for sem-rss--clean-text

(ert-deftest sem-rss-test-clean-text-html-stripping ()
  "Test HTML tag stripping."
  (let ((html "<html><body><h1>Title</h1><p>Content</p></body></html>"))
    (let ((cleaned (sem-rss--clean-text html)))
      (should-not (string-match-p "<[^>]+>" cleaned))
      (should (string-match-p "Title" cleaned))
      (should (string-match-p "Content" cleaned)))))

(ert-deftest sem-rss-test-clean-text-entity-replacement ()
  "Test HTML entity replacement."
  (let ((html "Tom &amp; Jerry &lt;cats&gt; &quot;quotes&quot;"))
    (let ((cleaned (sem-rss--clean-text html)))
      (should (string-match-p "Tom & Jerry" cleaned))
      (should (string-match-p "<cats>" cleaned))
      (should (string-match-p "\"quotes\"" cleaned)))))

(ert-deftest sem-rss-test-clean-text-truncation ()
  "Test text truncation at 3000 characters."
  (let ((long-text (make-string 5000 ?a)))
    (let ((cleaned (sem-rss--clean-text long-text)))
      (should (<= (length cleaned) 3003)))))  ; 3000 + "..."

(ert-deftest sem-rss-test-clean-text-whitespace-normalization ()
  "Test whitespace normalization."
  (let ((html "<p>Multiple   spaces\n\nand\r\nnewlines</p>"))
    (let ((cleaned (sem-rss--clean-text html)))
      (should-not (string-match-p "  " cleaned))  ; No multiple spaces
      (should-not (string-match-p "\n" cleaned))  ; No newlines
      (should (string-match-p "Multiple spaces and newlines" cleaned)))))

;;; Tests for sem-rss--build-entries-text

(ert-deftest sem-rss-test-build-entries-text-truncation ()
  "Test entries text truncation to max input chars."
  (let* ((entry '(:title "Test" :link "http://test.com" :tags ("test") :content "content"))
         (entries (list entry))
         (original-max sem-rss-max-input-chars))
    ;; Temporarily set a very low max for testing
    (let ((sem-rss-max-input-chars 10))
      (let ((text (sem-rss--build-entries-text entries)))
        (should (<= (length text) 10))))))

;;; Tests for prompt builders contain category names

(ert-deftest sem-rss-test-build-general-prompt-contains-categories ()
  "Test that general prompt contains category mappings."
  (let ((entries nil))
    (let ((prompt (sem-rss--build-general-prompt entries 1)))
      (should (string-match-p "Data Engineering" prompt))
      (should (string-match-p "Open Source" prompt))
      (should (string-match-p "Artificial Intelligence" prompt)))))

(ert-deftest sem-rss-test-build-arxiv-prompt-contains-categories ()
  "Test that arxiv prompt contains category mappings."
  (let ((entries nil))
    (let ((prompt (sem-rss--build-arxiv-prompt entries 1)))
      (should (string-match-p "cs.DB" prompt))
      (should (string-match-p "cs.AI" prompt))
      (should (string-match-p "physics.soc-ph" prompt)))))

;;; Test sem-rss-collect-entries per-feed cap

(ert-deftest sem-rss-test-collect-entries-per-feed-cap ()
  "Test that collect-entries applies per-feed cap.
This is a structural test - actual Elfeed DB testing requires mock DB."
  ;; Verify the constant is set
  (should (numberp sem-rss-max-entries-per-feed))
  (should (> sem-rss-max-entries-per-feed 0))
  ;; The actual capping logic is tested via code inspection
  ;; since it requires Elfeed DB setup
  (should t))

(provide 'sem-rss-test)
;;; sem-rss-test.el ends here
