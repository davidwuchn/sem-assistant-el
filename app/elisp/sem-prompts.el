;;; sem-prompts.el --- Prompts and cheat sheets for LLM interactions -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; This module provides centralized prompt constants for LLM interactions.
;; It has no runtime dependencies on other sem-* modules.

;;; Code:

(defconst sem-prompts-org-mode-cheat-sheet
  "=== ORG-MODE SYNTAX CHEAT SHEET ===

--- HEADINGS ---
Use asterisks for headings: `* Heading 1`, `** Heading 2`, `*** Heading 3`
BAD: `# Heading` → GOOD: `* Heading`

--- TEXT FORMATTING ---
Bold: `*bold text*`
Italic: `/italic text/`
Underline: `_underlined text_`
Strikethrough: `+strikethrough+`
Inline code: `=code=` or `~verbatim~`
BAD: `` `code` `` → GOOD: `=code=`
BAD: `**bold**` → GOOD: `*bold*`
BAD: `*italic*` → GOOD: `/italic/`

--- CODE BLOCKS ---
#+begin_src language
// code here
#+end_src
BAD: \`\`\`language\`\`\` → GOOD: `#+begin_src language`

--- BLOCK ELEMENTS ---
Blockquotes:
#+begin_quote
Quoted text here.
#+end_quote
BAD: `> quote` → GOOD: `#+begin_quote`

Example blocks:
#+begin_example
Example text here.
#+end_example

Verse blocks:
#+begin_verse
Poem or verse text here.
#+end_verse

--- LISTS ---
Unordered: `- item` or `+ item`
Ordered: `1. item` or `1) item`
Description: `- term :: description`

--- TABLES ---
| Column 1 | Column 2 |
|----------|----------|
| Cell 1   | Cell 2   |
|----------|----------|

--- LINKS ---
External: `[[https://example.com][Link description]]`
Internal: `[[*Heading][Description]]`
ID links: `[[id:UUID][Description]]`
File links: `[[file:path/to/file][Description]]`
BAD: `[desc](url)` → GOOD: `[[url][desc]]`

--- ORGZLY URI SCHEMES ---
mailto: `[[mailto:user@example.com][Email]]`
tel: `[[tel:1-800-555-0199][Phone]]`
geo: `[[geo:40.7128,-74.0060][Location]]`
geo with query: `[[geo:0,0?q=new+york+city][Search]]`
geo with zoom: `[[geo:40.7128,-74.0060?z=11][Map]]`

--- OUTPUT RULE ---
NEVER wrap your entire output in markdown code fences (e.g., do NOT start with \`\`\`org). Output raw org-mode text only."
  "Comprehensive org-mode syntax cheat sheet for LLM system prompts.
This constant is self-contained with no format specifiers.
It is used by sem-router.el and sem-url-capture.el for LLM prompts.")

(provide 'sem-prompts)
;;; sem-prompts.el ends here