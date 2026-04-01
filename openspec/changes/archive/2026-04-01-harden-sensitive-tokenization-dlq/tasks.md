## 1. Strict sensitive preflight parsing

- [x] 1.1 Implement strict delimiter validation in `sem-security-tokenize-sensitive` for malformed begin/end structures
- [x] 1.2 Support case-insensitive sensitive delimiters while enforcing standalone-line markers
- [x] 1.3 Ensure malformed-sensitive parsing errors fail before any LLM request path

## 2. Terminal DLQ routing semantics

- [x] 2.1 Update task router flow to classify malformed-sensitive sanitize failures as terminal DLQ without retry
- [x] 2.2 Update URL-capture flow and callback context to classify malformed-sensitive preflight failures as `security-malformed`
- [x] 2.3 Ensure malformed-sensitive terminal handling bypasses retry-counter increment paths

## 3. Security error metadata and logging

- [x] 3.1 Extend `sem-core-log-error` to accept optional metadata for `:priority` and `:tags`
- [x] 3.2 Log malformed-sensitive failures with `[#A]` priority and `:security:` tag metadata
- [x] 3.3 Keep legacy `sem-core-log-error` call sites compatible without metadata changes

## 4. Remove obsolete post-response verification

- [x] 4.1 Remove post-response token-expansion verification logic from routing flow
- [x] 4.2 Remove dead tests tied to removed expansion-verification behavior
- [x] 4.3 Confirm restoration and write flow remains intact with strict preflight gate

## 5. Test and assertion coverage updates

- [x] 5.1 Add unit tests for malformed marker cases (missing end, end without begin, inline marker, nested markers)
- [x] 5.2 Add unit tests verifying case-insensitive delimiter acceptance
- [x] 5.3 Add router and URL-capture tests confirming malformed-sensitive preflight fails before LLM calls and routes terminally
- [x] 5.4 Update integration fixtures and assertions for malformed-sensitive exclusion, security-tagged errors, and DLQ evidence
- [x] 5.5 Run unit test suite and delimiter lint checks for changed Elisp files
