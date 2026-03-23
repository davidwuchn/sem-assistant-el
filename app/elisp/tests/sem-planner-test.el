;;; sem-planner-test.el --- Tests for sem-planner.el -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Tests for sem-planner functions: anonymization, barrier, retry, atomic update.

;;; Code:

(require 'ert)
(require 'sem-mock)

(load-file (expand-file-name "../sem-core.el" (file-name-directory load-file-name)))
(load-file (expand-file-name "../sem-rules.el" (file-name-directory load-file-name)))
(load-file (expand-file-name "../sem-prompts.el" (file-name-directory load-file-name)))
(load-file (expand-file-name "../sem-planner.el" (file-name-directory load-file-name)))

;;; Helpers

(defun sem-planner-test--create-temp-tasks-file (content)
  "Create a temp tasks.org file with CONTENT and set sem-planner-tasks-file."
  (let ((tmp (sem-mock-temp-file content)))
    (setq sem-planner-tasks-file tmp)
    tmp))

;;; Anonymization Tests

(ert-deftest sem-planner-test-anonymize-tasks-returns-empty-when-no-file ()
  "Test that anonymize returns empty string when tasks file does not exist."
  (let ((sem-planner-tasks-file "/nonexistent/tasks.org"))
    (should (string-empty-p (sem-planner--anonymize-tasks)))))

(ert-deftest sem-planner-test-anonymize-tasks-strips-titles ()
  "Test that anonymize removes task titles and IDs."
  (let* ((tasks-content "* TODO Test task with a very long title that should be stripped :work:
:PROPERTIES:
:ID: abc-123
:SCHEDULED: <2024-03-15 09:00-10:30>
:END:
Some description here")
         (tmp (sem-planner-test--create-temp-tasks-file tasks-content)))
    (unwind-protect
        (let ((result (sem-planner--anonymize-tasks)))
          (should (stringp result))
          (should-not (string-match-p "Test task" result))
          (should-not (string-match-p "abc-123" result))
          (should-not (string-match-p "Some description" result)))
      (sem-mock-cleanup-temp-file tmp))))

(ert-deftest sem-planner-test-anonymize-tasks-preserves-time-priority-tag ()
  "Test that anonymize preserves time, priority, and tag."
  (let* ((tasks-content "* TODO Another task :routine:
:PROPERTIES:
:ID: def-456
:SCHEDULED: <2024-03-15 14:00-16:00>
:END:")
         (tmp (sem-planner-test--create-temp-tasks-file tasks-content)))
    (unwind-protect
        (let ((result (sem-planner--anonymize-tasks)))
          (should (string-match-p "2024-03-15" result))
          (should (string-match-p "14:00-16:00" result))
          (should (string-match-p "PRIORITY:" result))
          (should (string-match-p "TAG:routine" result)))
      (sem-mock-cleanup-temp-file tmp))))

;;; Temp File Path Tests

(ert-deftest sem-planner-test-temp-file-path-format ()
  "Test that temp file path follows expected format."
  (let ((sem-core--batch-id 42))
    (should (string-match-p "tasks-tmp-42.org" (sem-planner--temp-file-path)))))

;;; Validation Tests

(ert-deftest sem-planner-test-validate-planned-tasks-accepts-valid-simple-format ()
  "Test that validation passes for valid simple scheduling format."
  (let ((valid-response "ID: 5e7bc77c-0f40-41c8-b5a4-dcfeb28de8be | SCHEDULED: <2024-06-01 09:00-10:00>
ID: b96db7b3-e2cd-4983-ba79-5dd26a6d5215 | (unscheduled)"))
    (should (sem-planner--validate-planned-tasks valid-response))))

(ert-deftest sem-planner-test-validate-planned-tasks-rejects-invalid-response ()
  "Test that validation fails for invalid response."
  (let ((invalid-response "This is not org-mode"))
    (should-not (sem-planner--validate-planned-tasks invalid-response))))

(ert-deftest sem-planner-test-validate-planned-tasks-rejects-empty-response ()
  "Test that validation fails for empty response."
  (should-not (sem-planner--validate-planned-tasks ""))
  (should-not (sem-planner--validate-planned-tasks nil)))

;;; Atomic Update Tests

(ert-deftest sem-planner-test-atomic-update-creates-file-if-nonexistent ()
  "Test that atomic update creates tasks.org if it doesn't exist."
  (let* ((tmp-dir (make-temp-file "sem-test-" t))
         (tasks-file (expand-file-name "tasks.org" tmp-dir))
         (planned-tasks "* TODO New task :routine:
:PROPERTIES:
:ID: new-123
:END:")
         (sem-planner-tasks-file tasks-file))
    (unwind-protect
        (progn
          (should-not (file-exists-p tasks-file))
          (should (sem-planner--atomic-tasks-org-update planned-tasks))
          (should (file-exists-p tasks-file))
          (with-temp-buffer
            (insert-file-contents tasks-file)
            (goto-char (point-min))
            (should (re-search-forward "TODO" nil t))))
      (delete-directory tmp-dir t))))

;;; Fallback Tests

(ert-deftest sem-planner-test-fallback-reads-temp-file ()
  "Test that fallback reads content from temp file."
  (let* ((sem-core--batch-id 99)
         (temp-file (sem-planner--temp-file-path))
         (content "* TODO Fallback task :work:\n:PROPERTIES:\n:ID: fb-123\n:END:"))
    (unwind-protect
        (progn
          (make-directory (file-name-directory temp-file) t)
          (write-region content nil temp-file nil 'silent)
          (should (stringp (sem-planner--read-temp-file)))
          (should (string-match-p "Fallback task" (sem-planner--read-temp-file))))
      (when (file-exists-p temp-file)
        (delete-file temp-file)))))

(provide 'sem-planner-test)
;;; sem-planner-test.el ends here
