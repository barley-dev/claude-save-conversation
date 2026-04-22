# personal-conventions.md (example template)

> **How to use this file:**
> Copy to `personal-conventions.md` in this same directory and edit the placeholders to match your memory system. The skill only loads `personal-conventions.md` — `example-conventions.md` is the committed template.

This file defines Mode B (extraction) behavior for save-conversation. Without it, the skill only does archive-only.

---

## Categories to extract

Define which categories the skill should look for in conversations. Remove any you don't want.

### Category A: <your label, e.g. "lessons learned">

**What to look for:** <describe what counts, e.g. "moments where I corrected Claude's approach, or Claude self-corrected after a failure">

**Where to write:** `<absolute path or path pattern, e.g. ~/notes/claude-lessons/YYYY-MM-DD_<topic>.md>`

**Filename convention:** `<e.g. lesson_<short-kebab-name>.md>`

**Item format:**
```
### <category name> candidate N

**Situation:** <1 sentence: what Claude was doing>
**Correction/outcome:** <1 sentence: what user said or what happened>
**Why it matters:** <user's stated reason, or "not stated">
**When to apply:** <future scenarios where this is relevant>
```

### Category B: <your next category>

...

---

## Extraction rules

- **Max per category:** 2 candidates. Prefer fewer high-signal items over quantity.
- **Selection priority:**
  1. Generalizable (applies beyond this specific conversation)
  2. Novel (not already covered by existing memory)
  3. High-signal (strong user phrasing like "no", "actually", "should") over speculative Claude judgment
- **Empty is OK.** If no category has enough signal, report "nothing found for [category]" and don't pad.

---

## Confirmation flow

After listing candidates across all categories:

```
Total: N candidates across <categories>. Which to write?
  Reply with IDs (e.g. "a1,b2"), "all", or "none".
```

Write nothing until user confirms.

---

## Memory-system integration (optional)

If you maintain a structured memory index (e.g. `MEMORY.md`), define how extracted items update it:

- **Index file location:** `<path>`
- **Section header for each category:** `## <label>`
- **Entry format:** `- [<filename>](<filename>) — <one-line description>`

The skill will read the index, check for duplicate entries, and append new items under the right section header.

---

## Custom prompts (optional)

If you want the skill to ask specific questions before extracting, define them here. Example:

> Before extraction, ask: "Focus on which category? [a] lessons [b] wins [c] automation candidates"

Leave blank to extract from all defined categories by default.

---

## Notes

- Keep this file short and concrete. Vague conventions produce noisy extraction.
- Paths should be absolute (`$HOME/...` or `/Users/...`) — the skill runs in the cwd of the current Claude Code session, not this directory.
- If you change this file, the skill picks up the changes on next trigger (no restart needed).
