---
name: save-conversation
description: "Save the current Claude Code conversation as a markdown archive. Default behavior is archive-only (no extraction). Triggers: save this conversation, save conversation, archive conversation, 存對話, 儲存對話, 保存對話. If the user's trigger phrase explicitly mentions extraction (lessons, highlights, automations, project decisions, etc.), extended extraction flow is loaded from personal-conventions.md if present."
allowed-tools: Bash, Read, Write, Edit, Glob
---

# save-conversation — archive the current Claude Code conversation

## Purpose

Extract user and assistant text from the current Claude Code session jsonl into a readable markdown file. By default: **archive-only** — no analysis, no extraction.

**Core principles:**
- Default mode is archive-only. Save and done.
- Do NOT proactively ask "want me to also extract lessons?" — cognitive overhead.
- Only enter extended-extraction mode if (a) the user's trigger explicitly asked for it, AND (b) `references/personal-conventions.md` exists and defines an extraction flow.
- Without `personal-conventions.md`, this skill only does Mode A (archive). That's intentional — extraction depends on personal memory-system conventions that don't generalize.

---

## Step 0 — Detect trigger mode

The user's trigger phrase determines the mode:

**Mode A: archive-only** (default)
- "save this conversation"
- "save conversation"
- "archive conversation"
- "存對話" / "儲存對話" / "保存對話"

→ Execute Steps 1-4, done.

**Mode B: archive + extraction** (requires `personal-conventions.md`)
- Trigger explicitly mentions extraction (e.g. "also extract lessons", "and save the learnings", "存對話並記一下踩雷")

→ Check `references/personal-conventions.md`:
- If present → execute Steps 1-4, then load and follow the extraction flow defined there.
- If absent → inform user that extraction requires a `personal-conventions.md` (point them to `references/example-conventions.md` as a template), then execute Steps 1-4 (archive-only) as graceful fallback.

**Judgment rule:** DO NOT enter Mode B based on your own judgment ("this conversation seems worth extracting"). Only enter on explicit user phrasing. This respects user agency.

---

## Step 1 — Locate current session jsonl

Use `session-archive` with no args to list recent sessions (it auto-derives project dir from cwd; prints a stderr note if falling back):

```bash
session-archive 2>&1 | head -15
```

Output includes session-id prefix (first 8 chars) and file timestamps. Pick the newest. To confirm it's the current conversation, read its last few messages:

```bash
PROJECT_DIR=$(pwd -P | awk '{gsub(/[^a-zA-Z0-9]/, "-"); print "'"$HOME"'/.claude/projects/" $0}')
LATEST=$(ls -t "$PROJECT_DIR"/*.jsonl 2>/dev/null | head -1)
tail -5 "$LATEST" | jq -r '
  if .type == "user" and (.message.content | type) == "string"
  then "USER: " + (.message.content | .[0:150])
  elif .type == "assistant" and (.message.content | type) == "array"
  then "ASSISTANT: " + ((.message.content | map(select(.type == "text") | .text) | join(" ")) | .[0:150])
  else empty
  end'
```

If the last user message is NOT the skill trigger, this is a different conversation — pick a different session id from the list.

## Step 2 — Suggest a topic

Read the first 3 and last 3 messages of the jsonl (~1K tokens). Suggest a topic based on content:

- **Prefer:** an explicit topic the user mentioned in the conversation
- **Otherwise:** the nature of the work ("debugging-auth-flow", "skill-design-session")
- **Format:** 5-15 chars, hyphens between words, no spaces or slashes

Present as:
```
Suggested topic: <topic>
```

If the user doesn't object, proceed to Step 3.

## Step 3 — Run the archive

```bash
session-archive <session-id-prefix> "<topic>"
```

- If file exists → script prompts to overwrite; usually `y` (new version has more turns).
- If it fails → check `jq` is installed, verify session jsonl exists.

## Step 4 — Report and stop

**Mode A ends here.** Output:

```
✓ Archived: <path>
  (lines: XXX)
```

**That's it. Don't ask anything else.** If the user wanted extraction, they'll say so.

**Mode B continues into the flow defined by `references/personal-conventions.md`.**

---

## Loading personal conventions (Mode B)

If Mode B is triggered AND `references/personal-conventions.md` exists, Read it and follow the extraction flow defined there. The conventions file specifies:

- What categories are extractable (bugs-caught, wins, automation-candidates, project-decisions, etc.)
- Where each category gets written (memory dir, inbox dir, project logs)
- Naming conventions for extracted files
- Confirmation UI for the user

This skill intentionally does not ship a default extraction flow. Extraction is tightly coupled to the user's memory system — generic extraction produces low-signal noise. See `references/example-conventions.md` for a working template.

---

## Principles

1. **Default is Mode A.** Never proactively enter Mode B.
2. **Topic inference is budget-aware.** Read only first/last 3 messages of the jsonl.
3. **Don't invent conventions.** If Mode B triggers but no `personal-conventions.md` exists, fall back to archive-only and point the user at the example template.
4. **Sonnet is sufficient** for this skill's judgment calls.

---

## Edge cases

### E1: Multiple jsonl updating concurrently
Step 1 lists top 3 — read last message of each to confirm which is current.

### E2: Archive file already exists
Script prompts to overwrite. Usually `y` (newer version is more complete).

### E3: Mode B triggered but no personal-conventions.md
Explicitly tell the user: "Extraction requires a personal-conventions.md that defines your memory system. See references/example-conventions.md for a template. I'll just do the archive for now." Then run Mode A.

### E4: Session very long (>3000 lines)
Topic inference: read only first 3 + last 3 messages (not the full file) to stay under token budget.

---

## Related

- Main script: `bin/session-archive.sh` (from the same repo)
- Archive location: `$SESSION_ARCHIVE_DIR` (default `~/claude-sessions/`, see `bin/README.md`)
- Extraction flow: `references/personal-conventions.md` (user-created, gitignored)
- Extraction template: `references/example-conventions.md` (shipped with repo)
