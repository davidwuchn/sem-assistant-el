# Specification: inbox-upload

## Purpose

Define requirements for uploading test inbox to WebDAV via HTTP PUT.

## ADDED Requirements

### Requirement: WebDAV upload path uses root-scoped inbox file
The system SHALL construct WebDAV upload URLs for inbox upload as `${WEBDAV_BASE_URL}/inbox-mobile.org`.

#### Scenario: WebDAV URL uses root-scoped inbox path
- **WHEN** uploading the inbox file
- **THEN** the URL path is `${WEBDAV_BASE_URL}/inbox-mobile.org`

#### Scenario: WebDAV URL path structure
- **WHEN** the WebDAV base URL is `https://dav.example.com/webdav`
- **THEN** the upload URL is `https://dav.example.com/webdav/inbox-mobile.org`



### Requirement: Test inbox is uploaded via HTTP PUT
The system SHALL upload the test inbox file to WebDAV using HTTP PUT.

#### Scenario: Inbox upload uses curl with authentication
- **WHEN** uploading the test inbox
- **THEN** the script MUST use `curl` with `-u` flag using `${WEBDAV_USERNAME:-orgzly}:${WEBDAV_PASSWORD:-changeme}`

#### Scenario: Inbox upload uses correct HTTP method
- **WHEN** uploading the test inbox
- **THEN** the script MUST use HTTP PUT via curl's `-T` flag

#### Scenario: Inbox upload fails on non-2xx response
- **WHEN** uploading the test inbox and WebDAV returns non-2xx
- **THEN** curl MUST exit non-zero due to `--fail` flag
- **AND** the script MUST abort immediately due to `set -e`
