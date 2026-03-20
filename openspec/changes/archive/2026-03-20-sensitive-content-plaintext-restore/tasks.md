## 1. Modify detokenization function

- [x] 1.1 Update `sem-security--detokenize` to restore sensitive content as plain text without `#begin_sensitive` / `#end_sensitive` markers
- [x] 1.2 Add 2-space indentation per line for multi-line content with leading/trailing newlines
- [x] 1.3 Keep single-line content at token position verbatim without newlines or indentation
- [x] 1.4 Add `blocks-alist` cleanup after successful restoration and write

## 2. Update unit tests

- [x] 2.1 Update `sem-security-test-tokenize-detokenize-roundtrip` to expect plain text restoration
- [x] 2.2 Update `sem-security-test-position-roundtrip` to expect plain text restoration
- [x] 2.3 Update `sem-router-test-security-block-round-trip` to expect plain text restoration
- [x] 2.4 Run unit tests to verify all affected tests pass

## 3. Update documentation

- [x] 3.1 Update `README.md` to reflect plain text restoration behavior
- [x] 3.2 Update architecture/design docs to reflect plain text restoration behavior

## 4. Update integration test resources

- [x] 4.1 Add multi-line sensitive block to `dev/integration/testing-resources/inbox-tasks.org`
- [x] 4.2 Add negative marker assertion to `dev/integration/run-integration-tests.sh`
- [x] 4.3 Add order verification assertion to `dev/integration/run-integration-tests.sh`

## 5. Final verification

- [x] 5.1 Human runs integration tests and provides results
- [x] 5.2 Confirm all tests pass and mark implementation complete
