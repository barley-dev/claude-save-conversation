# claude-save-conversation

Tools for archiving Claude Code conversations as readable markdown.

Two pieces:

1. **`bin/session-archive.sh`** — bash script that converts a Claude Code session JSONL into clean markdown. Runs standalone.
2. **`skill/save-conversation/`** — a Claude Code skill that wraps the script with smart trigger detection (save a conversation by just asking Claude to do it).

Use the script on its own if you just want the markdown. Install the skill if you want Claude to handle it during a conversation.

## Quick start

### Just the script

```bash
# Install jq (macOS: brew, Debian: apt, Fedora: dnf)
brew install jq

# Put the script somewhere on your PATH
install -m 0755 bin/session-archive.sh ~/.local/bin/session-archive

# Use it
session-archive                    # list recent sessions
session-archive latest my-topic    # archive the latest conversation
```

Full docs: [`bin/README.md`](bin/README.md).

### The skill (requires Claude Code)

1. Make sure `session-archive` is on your `$PATH` (see above).
2. Symlink the skill into Claude Code's skills dir:
   ```bash
   ln -s "$(pwd)/skill/save-conversation" ~/.claude/skills/save-conversation
   ```
3. In a Claude Code conversation, say any of:
   - "save this conversation"
   - "save conversation"
   - "archive conversation"
   - 「存對話」 / 「儲存對話」 / 「保存對話」

Claude will archive the conversation to `$SESSION_ARCHIVE_DIR` (default `~/claude-sessions/`).

### Optional: Mode B extraction

The skill has a second mode that goes beyond archiving — it can extract lessons, wins, automation candidates, and project decisions into your personal memory system. This is off by default because it depends on conventions you define.

To enable:

1. Copy `skill/save-conversation/references/example-conventions.md` to `personal-conventions.md` (same directory).
2. Edit `personal-conventions.md` — define your categories, where they get written, filename conventions, and confirmation flow.
3. Trigger extraction by saying e.g. "save this conversation and extract lessons".

Without a `personal-conventions.md`, the skill falls back to archive-only (Mode A).

## Why separate script and skill

The script has no Claude Code dependency — you can cron-job it, pipe it, use it from any editor. The skill is a thin wrapper that adds "save a conversation by just asking." They share the repo because they're designed together, but either can be used alone.

## Compatibility

- **macOS** (tested on Darwin 25.x): yes
- **Linux** (tested on Ubuntu 22.04 equivalent): yes — the script detects `stat` flag differences between BSD and GNU
- **Windows (WSL)**: should work (standard Linux paths), untested

## License

MIT — see `LICENSE`.
