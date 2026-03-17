## Why

Two bugs cause silent data loss and a completely broken feature:

1. **Sensitive content permanently lost in url-capture.** `sem-url-capture-process` strips `#+begin_sensitive...#+end_sensitive` blocks before sending content to the LLM (correct) but never restores them into the saved org-roam node. Any note the user embedded inside a sensitive block vanishes silently from the saved node. The `security-blocks` alist is captured into the context plist under `:security-blocks` but is never read back.

2. **GitHub sync is permanently dead.** `sem-init--load-modules` (`init.el:147-157`) never calls `(require 'sem-git-sync)`. The function `sem-git-sync-org-roam` is therefore always unbound. Every 6-hour cron invocation of `emacsclient -e "(sem-git-sync-org-roam)"` fails with `void-function`. No org-roam node has ever been pushed to GitHub.

## What Changes

- `sem-url-capture-process`: after the LLM callback receives a non-nil response, call `sem-security-restore-from-llm` on the raw LLM response string using the `security-blocks` from context before passing to `sem-url-capture--validate-and-save`. This restores sensitive block content inline, at the token positions, in the final org-roam node.
- `sem-init--load-modules`: add `(require 'sem-git-sync)` in the correct load order (after `sem-core`, before `sem-router`).
- `security-masking/spec.md`: reverse the "SHALL NOT be called" clause. Replace with: `sem-security-restore-from-llm` SHALL be called on the raw LLM response string, using the `:security-blocks` from context, before passing the result to `sem-url-capture--validate-and-save`.
- Tests: add ERT tests covering (a) round-trip restoration in the url-capture pipeline and (b) that `sem-git-sync-org-roam` is defined after module load.

## Capabilities

### Modified Capabilities

- `url-capture`: sensitive blocks stripped before LLM call are now restored into the saved org-roam node before write. The restore call uses the `security-blocks` alist stored in the LLM callback's `context` plist under `:security-blocks`. Tokens in the LLM response that have no corresponding entry in `security-blocks` are left as-is (no error, no crash). If `security-blocks` is nil or empty, the call to `sem-security-restore-from-llm` is still made — it returns the text unchanged.

- `security-masking`: the "SHALL NOT call restore in url-capture" constraint is removed and reversed. `sem-security-restore-from-llm` SHALL be called in `sem-url-capture-process`'s LLM callback, on the raw LLM response string, before any other processing. The `blocks` argument SHALL be `(plist-get context :security-blocks)`. The call order is: restore → validate-and-save.

- `sem-git-sync` module loading: `sem-git-sync` SHALL be loaded in `sem-init--load-modules` via `(require 'sem-git-sync)`. Load position: after `(require 'sem-url-capture)`, before `(require 'sem-router)`. No changes to `sem-git-sync.el` itself.

### New Capabilities

- `url-capture-sensitive-restore-test`: ERT test in `sem-url-capture-test.el` that verifies: given a raw LLM response containing a `<<SENSITIVE_1>>` token and a `security-blocks` alist `(("<<SENSITIVE_1>>" . "#+begin_sensitive\nSECRET\n#+end_sensitive"))`, calling `sem-security-restore-from-llm` on the response returns a string containing `SECRET` and not containing `<<SENSITIVE_1>>`.

- `url-capture-process-restore-integration-test`: ERT test that stubs `sem-llm-request` to return a response containing a `<<SENSITIVE_1>>` token, runs the full `sem-url-capture-process` callback path with a pre-populated `:security-blocks` in context, and asserts the saved file content contains the restored sensitive block text, not the token.

- `git-sync-module-load-test`: ERT test that calls `sem-init--load-modules` (with all `require` calls mocked to no-ops) and asserts that `sem-git-sync` is among the required modules — i.e., `fboundp 'sem-git-sync-org-roam` returns `t` after load.

## Impact

- `sem-url-capture.el`: one line added in the LLM callback, between the `response` nil-check and the `sem-url-capture--validate-and-save` call.
- `init.el`: one line added inside `sem-init--load-modules`.
- `openspec/specs/security-masking/spec.md`: requirement "Tokens restored in output before writing" updated; scenario "restore-from-llm NOT called in url-capture" removed and replaced with "restore-from-llm called before validate-and-save in url-capture".
- `app/elisp/tests/sem-url-capture-test.el`: two new ERT tests added.
- No changes to `sem-security.el`, `sem-git-sync.el`, or any other module.
- All existing tests must continue to pass unchanged.
