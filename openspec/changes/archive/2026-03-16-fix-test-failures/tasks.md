## 1. Fix sem-core-log cl-block Issue

- [x] 1.1 Wrap `sem-core-log` function body in `(cl-block sem-core-log ...)`
- [x] 1.2 Verify `cl-return-from` works correctly with the new block
- [x] 1.3 Run tests to confirm the sem-core-log test passes

## 2. Fix sem-url-capture--validate-and-save cl-block Issue

- [x] 2.1 Wrap `sem-url-capture--validate-and-save` function body in `(cl-block sem-url-capture--validate-and-save ...)`
- [x] 2.2 Verify tests pass for validate-and-save error handling

## 3. Route sem-url-capture-process Through sem-llm-request

- [x] 3.1 Modify `sem-url-capture-process` to call `sem-llm-request` instead of `gptel-request`
- [x] 3.2 Pass `sem-url-capture--validate-and-save` as the success callback via context plist
- [x] 3.3 Verify function signature of `sem-url-capture--validate-and-save` remains unchanged
- [x] 3.4 Run tests to confirm LLM routing works correctly

## 4. Fix DLQ Logging for Malformed Responses

- [x] 4.1 Ensure malformed LLM output marks headline hash as processed in `.sem-cursor.el`
- [x] 4.2 Ensure malformed output is logged to `/data/errors.org` (DLQ)
- [x] 4.3 Verify API errors (429, timeout) do NOT mark hash as processed
- [x] 4.4 Verify API errors are logged with `STATUS=RETRY`

## 5. Fix Trafilatura Mock Advice

- [x] 5.1 Change `sem-mock-trafilatura-success` from `:filter-args` to `:override` advice
- [x] 5.2 Change `sem-mock-trafilatura-failure` from `:filter-args` to `:override` advice
- [x] 5.3 Add `(string= (car args) "trafilatura")` guard to both mocks
- [x] 5.4 Ensure mocks pass through non-trafilatura calls via `apply #'call-process--original`

## 6. Add New Tests

- [x] 6.1 Add test for `sem-url-capture-process` happy path (successful LLM response)
- [x] 6.2 Add test for `sem-url-capture-process` DLQ path (malformed LLM response)
- [x] 6.3 Add test for `sem-url-capture-process` retry path (API error)
- [x] 6.4 Run full test suite to confirm all 4 failing tests now pass

## 7. Verification

- [x] 7.1 Run `make test` or equivalent to verify all tests pass
- [x] 7.2 Verify no new test failures introduced
- [x] 7.3 Confirm 100% test pass rate (45/45 tests)
