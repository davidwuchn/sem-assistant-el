## Why

Task titles generated in the `:task:` flow are not normalized, which creates inconsistent naming and reduces scanability in Org files. URL-capture titles generated in the `:link:` flow are often too long, making Org-roam retrieval harder and degrading visualization in Org-roam UI consumers.

## What Changes

Introduce deterministic lowercase normalization for generated task titles in the `:task:` flow. Update URL-capture prompt guidance in the `:link:` flow to request shorter, concise node names with examples, while keeping title generation LLM-driven (no strict truncation rules).

## Capabilities

### New Capabilities

- `task-title-lowercase-normalization`: Generated titles in the `:task:` pipeline are normalized to lowercase before write; normalization applies only to the title field, preserves non-title content, and must be idempotent across retries.

### Modified Capabilities

- `url-capture-title-generation`: Prompt instructions for `:link:` title generation are updated to prefer shorter names with semantic compression examples (for example, long headline to concise "topic: contrast" form) without enforcing hard character limits or regex rules.

## Impact

- Affects title-handling behavior in inbox-to-task routing and prompt text in URL-capture.
- Improves consistency for task discovery and reduces visual clutter in downstream Org-roam views.
- Out of scope: retroactive renaming of existing stored nodes/tasks, language detection/translation rules, punctuation normalization policy beyond lowercase transformation, and any non-title metadata changes.
