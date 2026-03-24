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
NEVER wrap your entire output in markdown code fences (e.g., do NOT start with \`\`\`org). Output raw org-mode text only.

--- SCHEDULED TIME RANGE FORMAT ---
When scheduling tasks with time ranges, use:
SCHEDULED: <YYYY-MM-DD HH:MM-HH:MM>

Examples:
- SCHEDULED: <2024-03-15 09:00-10:30>  (morning block)
- SCHEDULED: <2024-03-15 14:00-16:00>  (afternoon block)
- SCHEDULED: <2024-03-16 10:00-11:00>  (next day morning)

Format: date, start time, hyphen, end time (no spaces around hyphen).
Time is 24-hour format (HH:MM)."
  "Comprehensive org-mode syntax cheat sheet for LLM system prompts.
This constant is self-contained with no format specifiers.
It is used by sem-router.el and sem-url-capture.el for LLM prompts.")

(defconst sem-prompts-time-range-format
  "--- SCHEDULED TIME RANGE FORMAT ---
When scheduling tasks, use time ranges in the format:
SCHEDULED: <YYYY-MM-DD HH:MM-HH:MM>

Examples:
- SCHEDULED: <2024-03-15 09:00-10:30>  (morning block)
- SCHEDULED: <2024-03-15 14:00-16:00>  (afternoon block)
- SCHEDULED: <2024-03-16 10:00-11:00>  (next day morning)

The format is: date, start time, hyphen, end time (no spaces around hyphen).
Time is 24-hour format (HH:MM).
Always specify both start and end times for the time block."
  "Documentation for SCHEDULED time range format.
Used in Pass 1 prompts to instruct the LLM to output time ranges.")

(defconst sem-prompts-pass1-system-template
  "You are a Task Management assistant. Your ONLY task is to transform a raw capture note into a valid Org-mode TODO entry.

%%CHEAT_SHEET%%

=== REQUIRED OUTPUT FORMAT ===
Your output MUST follow this exact structure:

* TODO <Cleaned Task Title>
:PROPERTIES:
:ID: <injected-id-value>
:FILETAGS: :<one-of:work:family:routine:opensource>:
:END:
<Normalized task notes; may be multi-line when input has meaningful multi-line context>
<Optional: SCHEDULED: <YYYY-MM-DD HH:MM-HH:MM>>
<Optional: DEADLINE: <YYYY-MM-DD Day>>

=== RULES ===
1. :FILETAGS: MUST be exactly one of: :work:, :family:, :routine:, or :opensource:
2. :ID: MUST be the EXACT value provided in the template below - do not generate, modify, or substitute it
3. Output ONLY the Org entry - no explanations, no markdown wrappers
4. Normalize the note into a concise, actionable TODO title and useful body text
5. CRITICAL: Preserve ALL <<SENSITIVE_N>> tokens VERBATIM in your output. These tokens represent masked sensitive content and must appear unchanged.
6. CRITICAL: Tokens must appear at the SAME semantic position as the original sensitive content appeared in the input.
7. If you include SCHEDULED, it must use time range format: SCHEDULED: <YYYY-MM-DD HH:MM-HH:MM>
8. If timing intent is ambiguous or low-confidence, it is valid to omit SCHEDULED
9. Prefer adding priority in headline token format [#A]/[#B]/[#C], but priority may be omitted when uncertain
10. Priority strength mapping: urgent/asap/critical/important!! -> [#A], soon/high -> [#B], routine/normal -> [#C]

=== RELATIVE TIME ANCHOR ===
Treat relative phrases against runtime context provided in user prompt as CURRENT DATETIME.

=== EXAMPLES (NORMALIZATION TARGETS) ===
- Input: \"2morrow send draft to team important!!\"
  Output intent: cleaned title, [#A], schedule anchored to CURRENT DATETIME for tomorrow
- Input: \"next week sync with ops\"
  Output intent: best-effort schedule only if confident; otherwise unscheduled TODO is valid
- Input: \"wendsday call vendor about invoice\"
  Output intent: treat common misspelling as Wednesday when confidence is high; otherwise unscheduled
- Input: \"ASAP fix login bug but low urgency follow-up\"
  Output intent: conflicting urgency resolves to strongest signal ([#A] > [#B] > [#C])
- Input: \"Call +1-800-555-0199 re INC-7781\"
  Output intent: preserve identifiers and phone numbers verbatim in title/body

%%RULES%%
%%LANGUAGE%%"
  "Template for Pass 1 system prompt.
Uses %%CHEAT_SHEET%%, %%RULES%%, and %%LANGUAGE%% as placeholders
that are substituted at runtime by sem-router.")

(provide 'sem-prompts)
;;; sem-prompts.el ends here
