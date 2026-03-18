;;; sem-prompts-test.el --- Tests for sem-prompts.el -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Tests for sem-prompts.el module.

;;; Code:

(require 'ert)
(require 'sem-mock)

;; Load the module under test
(load-file (expand-file-name "../sem-prompts.el" (file-name-directory load-file-name)))

;;; Tests for sem-prompts-org-mode-cheat-sheet

(ert-deftest sem-prompts-test-cheat-sheet-exists ()
  "Test that sem-prompts-org-mode-cheat-sheet is defined."
  (should (boundp 'sem-prompts-org-mode-cheat-sheet)))

(ert-deftest sem-prompts-test-cheat-sheet-is-string ()
  "Test that sem-prompts-org-mode-cheat-sheet is a string."
  (should (stringp sem-prompts-org-mode-cheat-sheet)))

(ert-deftest sem-prompts-test-cheat-sheet-non-empty ()
  "Test that sem-prompts-org-mode-cheat-sheet is non-empty."
  (should (not (string-empty-p sem-prompts-org-mode-cheat-sheet))))

(ert-deftest sem-prompts-test-cheat-sheet-no-format-specifiers ()
  "Test that cheat sheet has no format specifiers (self-contained string)."
  (should-not (string-match-p "%s" sem-prompts-org-mode-cheat-sheet))
  (should-not (string-match-p "%d" sem-prompts-org-mode-cheat-sheet))
  (should-not (string-match-p "%[^{]" sem-prompts-org-mode-cheat-sheet))
  (should-not (string-match-p "%{" sem-prompts-org-mode-cheat-sheet)))

(ert-deftest sem-prompts-test-cheat-sheet-covers-headings ()
  "Test that cheat sheet covers headings syntax."
  (should (string-match-p "\\* Heading" sem-prompts-org-mode-cheat-sheet)))

(ert-deftest sem-prompts-test-cheat-sheet-covers-bold ()
  "Test that cheat sheet covers bold syntax."
  (should (string-match-p "\\*bold text\\*" sem-prompts-org-mode-cheat-sheet)))

(ert-deftest sem-prompts-test-cheat-sheet-covers-italic ()
  "Test that cheat sheet covers italic syntax."
  (should (string-match-p "/italic text/" sem-prompts-org-mode-cheat-sheet)))

(ert-deftest sem-prompts-test-cheat-sheet-covers-underline ()
  "Test that cheat sheet covers underline syntax."
  (should (string-match-p "_underlined text_" sem-prompts-org-mode-cheat-sheet)))

(ert-deftest sem-prompts-test-cheat-sheet-covers-strikethrough ()
  "Test that cheat sheet covers strikethrough syntax."
  (should (string-match-p "\\+strikethrough\\+" sem-prompts-org-mode-cheat-sheet)))

(ert-deftest sem-prompts-test-cheat-sheet-covers-inline-code ()
  "Test that cheat sheet covers inline code syntax."
  (should (string-match-p "=code=" sem-prompts-org-mode-cheat-sheet))
  (should (string-match-p "~verbatim~" sem-prompts-org-mode-cheat-sheet)))

(ert-deftest sem-prompts-test-cheat-sheet-covers-code-blocks ()
  "Test that cheat sheet covers code blocks syntax."
  (should (string-match-p "#\\+begin_src" sem-prompts-org-mode-cheat-sheet))
  (should (string-match-p "#\\+end_src" sem-prompts-org-mode-cheat-sheet)))

(ert-deftest sem-prompts-test-cheat-sheet-covers-blockquotes ()
  "Test that cheat sheet covers blockquotes syntax."
  (should (string-match-p "#\\+begin_quote" sem-prompts-org-mode-cheat-sheet))
  (should (string-match-p "#\\+end_quote" sem-prompts-org-mode-cheat-sheet)))

(ert-deftest sem-prompts-test-cheat-sheet-covers-example-blocks ()
  "Test that cheat sheet covers example blocks syntax."
  (should (string-match-p "#\\+begin_example" sem-prompts-org-mode-cheat-sheet))
  (should (string-match-p "#\\+end_example" sem-prompts-org-mode-cheat-sheet)))

(ert-deftest sem-prompts-test-cheat-sheet-covers-verse-blocks ()
  "Test that cheat sheet covers verse blocks syntax."
  (should (string-match-p "#\\+begin_verse" sem-prompts-org-mode-cheat-sheet))
  (should (string-match-p "#\\+end_verse" sem-prompts-org-mode-cheat-sheet)))

(ert-deftest sem-prompts-test-cheat-sheet-covers-lists ()
  "Test that cheat sheet covers list syntax."
  (should (string-match-p "- item" sem-prompts-org-mode-cheat-sheet))
  (should (string-match-p "+ item" sem-prompts-org-mode-cheat-sheet))
  (should (string-match-p "1\\. item" sem-prompts-org-mode-cheat-sheet)))

(ert-deftest sem-prompts-test-cheat-sheet-covers-tables ()
  "Test that cheat sheet covers table syntax."
  (should (string-match-p "| Column" sem-prompts-org-mode-cheat-sheet)))

(ert-deftest sem-prompts-test-cheat-sheet-covers-links ()
  "Test that cheat sheet covers link syntax."
  (should (string-match-p "\\[\\[" sem-prompts-org-mode-cheat-sheet))
  (should (string-match-p "\\]\\[" sem-prompts-org-mode-cheat-sheet)))

(ert-deftest sem-prompts-test-cheat-sheet-covers-mailto-uri ()
  "Test that cheat sheet covers mailto: URI scheme."
  (should (string-match-p "mailto:" sem-prompts-org-mode-cheat-sheet)))

(ert-deftest sem-prompts-test-cheat-sheet-covers-tel-uri ()
  "Test that cheat sheet covers tel: URI scheme."
  (should (string-match-p "tel:" sem-prompts-org-mode-cheat-sheet)))

(ert-deftest sem-prompts-test-cheat-sheet-covers-geo-uri ()
  "Test that cheat sheet covers geo: URI scheme."
  (should (string-match-p "geo:" sem-prompts-org-mode-cheat-sheet)))

(ert-deftest sem-prompts-test-cheat-sheet-covers-bad-good-callouts ()
  "Test that cheat sheet includes BAD/GOOD callouts for common mistakes."
  (should (string-match-p "BAD:" sem-prompts-org-mode-cheat-sheet))
  (should (string-match-p "GOOD:" sem-prompts-org-mode-cheat-sheet)))

(ert-deftest sem-prompts-test-cheat-sheet-covers-no-code-fence-wrapping ()
  "Test that cheat sheet includes rule against wrapping output in markdown code fences."
  (should (string-match-p "markdown code fence" sem-prompts-org-mode-cheat-sheet))
  (should (string-match-p "NEVER wrap" sem-prompts-org-mode-cheat-sheet)))

(provide 'sem-prompts-test)
;;; sem-prompts-test.el ends here