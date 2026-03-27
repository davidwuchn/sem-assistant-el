;;; sem-webdav-config-test.el --- Tests for WebDAV runtime config -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Tests for production and test WebDAV compose/config invariants.

;;; Code:

(require 'ert)

(defconst sem-webdav-config-test--repo-root
  (expand-file-name "../../.." (file-name-directory load-file-name))
  "Repository root for config-file assertions.")

(defun sem-webdav-config-test--read (relative-path)
  "Return file content for RELATIVE-PATH from repository root."
  (with-temp-buffer
    (insert-file-contents (expand-file-name relative-path sem-webdav-config-test--repo-root))
    (buffer-string)))

(ert-deftest sem-webdav-config-test-production-compose-uses-apache-runtime ()
  "Test that production compose uses Apache WebDAV with preserved cert mount."
  (let ((compose (sem-webdav-config-test--read "docker-compose.yml")))
    (should (string-match-p "image: .*httpd:2\\.4" compose))
    (should (string-match-p "/etc/letsencrypt:/certs:ro,z" compose))
    (should (string-match-p "WEBDAV_DOMAIN" compose))
    (should (string-match-p "WEBDAV_RUNTIME_MODE=.*production" compose))
    (should (string-match-p "WEBDAV_PASSWORD=.*ChangeMeStrongPassword2026" compose))
    (should (string-match-p "start-webdav\\.sh" compose))))

(ert-deftest sem-webdav-config-test-apache-template-enforces-conditional-writes ()
  "Test that Apache template rejects missing or weak write preconditions."
  (let ((template (sem-webdav-config-test--read
                   "webdav/apache/httpd-webdav.conf.template")))
    (should (string-match-p (regexp-quote "RewriteCond %{HTTP:If-Match} ^$") template))
    (should (string-match-p (regexp-quote "RewriteRule ^ - [R=428,L]") template))
    (should (string-match-p (regexp-quote "RewriteCond %{HTTP:If-Match} ^W/") template))
    (should (string-match-p (regexp-quote "RewriteRule ^ - [R=412,L]") template))))

(ert-deftest sem-webdav-config-test-integration-runtime-remains-non-tls ()
  "Test that integration override remains independent from production TLS/runtime."
  (let ((compose-test (sem-webdav-config-test--read "dev/integration/docker-compose.test.yml"))
        (webdav-test (sem-webdav-config-test--read "dev/integration/webdav-config.test.yml")))
    (should (string-match-p "image: hacdias/webdav:latest" compose-test))
    (should (string-match-p "webdav-config\\.test\\.yml" compose-test))
    (should (string-match-p "WEBDAV_RUNTIME_MODE=.*integration-test" compose-test))
    (should (string-match-p "tls: false" webdav-test))))

(ert-deftest sem-webdav-config-test-start-script-enforces-production-password-policy ()
  "Test WebDAV startup script enforces production password complexity policy."
  (let ((script (sem-webdav-config-test--read "webdav/apache/start-webdav.sh")))
    (should (string-match-p "WEBDAV_RUNTIME_MODE" script))
    (should (string-match-p "= \"production\"" script))
    (should (string-match-p "password_len" script))
    (should (string-match-p "[a-z]" script))
    (should (string-match-p "[A-Z]" script))
    (should (string-match-p "[0-9]" script))))

(ert-deftest sem-webdav-config-test-start-script-logs-remediation-for-policy-failures ()
  "Test WebDAV startup script emits explicit remediation guidance on failures."
  (let ((script (sem-webdav-config-test--read "webdav/apache/start-webdav.sh")))
    (should (string-match-p "Production password policy validation failed" script))
    (should (string-match-p "Remediation:" script))))

(provide 'sem-webdav-config-test)
;;; sem-webdav-config-test.el ends here
