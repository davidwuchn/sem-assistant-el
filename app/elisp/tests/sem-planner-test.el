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

(ert-deftest sem-planner-test-anonymize-temp-tasks-flags-fixed-schedule-exception ()
  "Test that Pass 2 anonymized task lines flag the fixed-schedule exception."
  (let ((temp-tasks (concat "* TODO Process quarterly financial reports :routine:\n"
                            ":PROPERTIES:\n"
                            ":ID: fixed-123\n"
                            ":END:\n"
                            "SCHEDULED: <2026-03-20 Fri>\n"
                            "\n"
                            "* TODO Another task :work:\n"
                            ":PROPERTIES:\n"
                            ":ID: nonfixed-123\n"
                            ":END:\n"
                            "SCHEDULED: <2026-03-21 Sat 10:00-11:00>\n")))
    (let ((result (sem-planner--anonymize-temp-tasks temp-tasks)))
      (should (string-match-p "ID: fixed-123" result))
      (should (string-match-p "FIXED_SCHEDULE_EXCEPTION:true" result))
      (should-not
       (string-match-p "ID: nonfixed-123 | TAG:work | .*FIXED_SCHEDULE_EXCEPTION:true" result)))))

(ert-deftest sem-planner-test-merge-scheduling-keeps-fixed-schedule-unchanged ()
  "Test that merge does not alter the fixed-schedule exception task."
  (let* ((temp-tasks (concat "* TODO Process quarterly financial reports :routine:\n"
                             ":PROPERTIES:\n"
                             ":ID: fixed-456\n"
                             ":END:\n"
                             "SCHEDULED: <2026-03-20 Fri>\n"
                             "\n"
                             "* TODO Review pull request #452 :work:\n"
                             ":PROPERTIES:\n"
                             ":ID: work-456\n"
                             ":END:\n"))
         (decisions '(("fixed-456" . "<2099-01-01 Thu 10:00-11:00>")
                      ("work-456" . "<2099-01-02 Fri 12:00-13:00>")))
         (merged (sem-planner--merge-scheduling-into-tasks temp-tasks decisions)))
    (should (string-match-p "SCHEDULED: <2026-03-20 Fri>" merged))
    (should-not (string-match-p "SCHEDULED: <2099-01-01 Thu 10:00-11:00>" merged))
    (should (string-match-p "SCHEDULED: <2099-01-02 Fri 12:00-13:00>" merged))))

(ert-deftest sem-planner-test-build-pass2-prompt-includes-runtime-bounds-and-strict-rule ()
  "Test that Pass 2 prompt includes runtime bounds and strict greater-than semantics."
  (let ((prompt (sem-planner--build-pass2-prompt
                 "Tasks to schedule:\n- ID: abc | TAG:work | (unscheduled)\n"
                 "(No existing tasks)"
                 ""
                 "2026-03-24T12:00:00Z"
                 "2026-03-24T13:00:00Z")))
    (should (string-match-p "runtime_now: 2026-03-24T12:00:00Z" prompt))
    (should (string-match-p "runtime_min_start: 2026-03-24T13:00:00Z" prompt))
    (should (string-match-p "strictly greater than runtime_min_start" prompt))
    (should (string-match-p "SCHEDULED equal to runtime_min_start is NOT allowed" prompt))
    (should (string-match-p "Process quarterly financial reports" prompt))))

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
