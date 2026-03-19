## Why

The `emacs-package-provisioning` spec mandates "no runtime package installation" and "`init.el` only calls `(require ...)`, never `straight-use-package`". This assumption is false: straight.el's `load-path` modifications are process-local and are lost when the batch build process exits. Packages installed at Docker build time are not visible to the Emacs daemon at runtime unless `straight-use-package` is called to re-activate them in the daemon process.

## What Changes

1. **`openspec/specs/emacs-package-provisioning/spec.md`**: Revise the "no runtime package installation" requirement to permit `straight-use-package` calls whose only effect is adding pre-built packages to `load-path` (no network access, no re-downloading).

2. **`app/elisp/init.el`**: Modify `sem-init--bootstrap-straight` to call `straight-use-package` for each build-time-installed package after bootstrapping straight.el. This makes packages visible to `(require ...)` in the daemon process.

3. **`openspec/specs/emacs-package-provisioning/spec.md`**: Update bootstrapPackages.el separation requirement to clarify that only package installation (network downloads) belongs in bootstrap-packages.el; load-path activation belongs in init.el.

## Capabilities

### Modified Capabilities

- `emacs-package-provisioning`: Revise Requirement "No runtime package installation" to allow `straight-use-package` calls that add pre-built packages to `load-path` without network access. Clarify that `init.el` MAY call `straight-use-package` for activation, not installation.
