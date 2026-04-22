# session-archive

Convert Claude Code session JSONL files to readable markdown.

Claude Code stores every session as `~/.claude/projects/<slug>/<session-id>.jsonl`. These files contain the full conversation, including tool use and internal state — not easy to read. `session-archive` extracts user and assistant text into a clean markdown file with frontmatter.

## Requirements

- `bash` 3.2+ (works on macOS default bash and Linux)
- [`jq`](https://stedolan.github.io/jq/)
  - macOS: `brew install jq`
  - Debian/Ubuntu: `sudo apt install jq`
  - Fedora/RHEL: `sudo dnf install jq`

## Install

Drop `session-archive.sh` anywhere on your `$PATH`, or keep it in place and use an alias:

```bash
# Option 1: add to PATH
install -m 0755 session-archive.sh ~/.local/bin/session-archive

# Option 2: alias in your shell rc
alias session-archive="bash /path/to/session-archive.sh"
```

## Usage

```bash
session-archive                      # list recent 10 sessions
session-archive latest               # archive the latest session (prompts for topic)
session-archive latest my-topic      # archive latest with an explicit topic
session-archive abc123               # archive by session-id prefix
session-archive abc123 my-topic      # same, with topic
session-archive -h | --help          # show help
```

Output is saved to `$SESSION_ARCHIVE_DIR/YYYY-MM-DD_<topic>.md`.

## Configuration

| Env var | Default | Purpose |
|---------|---------|---------|
| `SESSION_ARCHIVE_DIR` | `~/claude-sessions` | Where archived markdown files are written |

Example:

```bash
export SESSION_ARCHIVE_DIR="$HOME/notes/claude-archives"
session-archive latest my-topic
# → ~/notes/claude-archives/2026-04-22_my-topic.md
```

## How project dir resolution works

Claude Code encodes your cwd into a slug directory name under `~/.claude/projects/`. The encoding rule: every non-alphanumeric character (including `/`, space, `-`, and non-ASCII) becomes a single `-`. For example:

- cwd `/home/alice/work` → `~/.claude/projects/-home-alice-work/`
- cwd `/Users/bob/my project` → `~/.claude/projects/-Users-bob-my-project/`

`session-archive` runs `pwd -P` (resolving symlinks, matching what Claude Code sees) and derives the slug the same way. If the derived dir has no session jsonl — usually because you're running the script from a different cwd than the one where Claude Code was launched — it falls back to the project dir containing the globally newest session, and prints a note to stderr.

## Output format

Archived files are markdown with YAML frontmatter:

```markdown
---
session_id: abc123...
archived_at: 2026-04-22 14:30
session_modified: 2026-04-22 13:05
topic: my-topic
source: /Users/.../abc123.jsonl
---

# Session: my-topic

> Session ID: `abc123...`
> Last modified: 2026-04-22 13:05

---

## 👤 User

<first user message>

## 🤖 Claude

<first assistant text response>

...
```

Only plain text messages are included. Tool calls, tool results, and internal thinking blocks are filtered out — this is intentional: the goal is a readable transcript, not a full session replay.

## Caveats

- Assumes the standard `~/.claude/projects/` location. If Claude Code changes where sessions are stored, edit `PROJECTS_ROOT` at the top of the script.
- The slug-encoding rule was observed empirically (Claude Code does not document it). If Anthropic changes the rule, the script will fall back to mtime-based scanning and still work, but the fallback notice will appear every time.
- `stat` flag syntax differs between macOS (BSD) and Linux (GNU). The script detects OS via `uname -s` and picks the right syntax. Tested on macOS 25.x; Linux paths use standard GNU coreutils.

## License

MIT — see `LICENSE`.
