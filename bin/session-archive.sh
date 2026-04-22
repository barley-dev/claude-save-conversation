#!/usr/bin/env bash
# session-archive — 將 Claude Code session jsonl 轉成可讀 markdown
#
# 用法：
#   session-archive                    # 列出最近 10 個 session
#   session-archive latest             # 存檔最新的 session（互動輸入主題）
#   session-archive latest <主題>      # 存檔最新 session，指定主題
#   session-archive <session-id前綴>   # 依 ID 前綴存檔
#   session-archive <session-id前綴> <主題>
#
# 輸出位置：$SESSION_ARCHIVE_DIR （預設 ~/claude-sessions/）/YYYY-MM-DD_<主題>.md
#
# 依賴：jq, bash (macOS / Linux)

set -euo pipefail

usage() {
  cat <<EOF
session-archive — convert Claude Code session jsonl to readable markdown

Usage:
  session-archive                      List recent 10 sessions
  session-archive latest               Archive latest session (prompts for topic)
  session-archive latest <topic>       Archive latest session with topic
  session-archive <id-prefix>          Archive by session-id prefix
  session-archive <id-prefix> <topic>  Archive by prefix with topic
  session-archive -h | --help          Show this help

Output: \$SESSION_ARCHIVE_DIR/YYYY-MM-DD_<topic>.md
  (default: ~/claude-sessions/, override with env var SESSION_ARCHIVE_DIR)

Project dir resolution:
  Derives from cwd using Claude Code's slug encoding
  (non-alphanumeric chars → '-'). Falls back to the dir of the globally
  newest session jsonl if cwd-derived dir has no sessions.

Dependencies: jq, bash (macOS / Linux)
EOF
}

PROJECTS_ROOT="$HOME/.claude/projects"
ARCHIVE_DIR="${SESSION_ARCHIVE_DIR:-$HOME/claude-sessions}"

# Handle help flags before any env checks
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: 'jq' is required but not installed." >&2
  echo "  macOS: brew install jq" >&2
  echo "  Debian/Ubuntu: sudo apt install jq" >&2
  echo "  Fedora/RHEL: sudo dnf install jq" >&2
  exit 1
fi

if [[ ! -d "$PROJECTS_ROOT" ]]; then
  echo "Error: Claude Code projects root not found: $PROJECTS_ROOT" >&2
  exit 1
fi

# Cross-platform mtime helpers: stat flags differ between macOS (BSD) and Linux (GNU)
case "$(uname -s)" in
  Darwin)
    _mtime_epoch() { stat -f '%m' "$1"; }
    _mtime_fmt()   { stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$1"; }
    ;;
  *)
    _mtime_epoch() { stat -c '%Y' "$1"; }
    _mtime_fmt()   { date -d "@$(stat -c '%Y' "$1")" '+%Y-%m-%d %H:%M'; }
    ;;
esac

# Derive project-slug dir from cwd using Claude Code's encoding rule
# (every non-[a-zA-Z0-9] char, including non-ASCII, becomes a single dash)
derive_project_dir() {
  local slug
  slug=$(pwd -P | awk '{gsub(/[^a-zA-Z0-9]/, "-"); print}')
  echo "$PROJECTS_ROOT/$slug"
}

# Find jsonl in any project dir, sorted by mtime desc (for fallback)
find_latest_jsonl_any() {
  find "$PROJECTS_ROOT" -maxdepth 2 -name '*.jsonl' -type f -print0 2>/dev/null \
    | while IFS= read -r -d '' f; do
        printf '%s %s\n' "$(_mtime_epoch "$f")" "$f"
      done \
    | sort -rn \
    | head -1 \
    | cut -d' ' -f2-
}

# Resolve PROJECT_DIR: derive from cwd; if empty or missing, fall back to
# whichever dir contains the globally newest jsonl, and warn.
resolve_project_dir() {
  local derived
  derived=$(derive_project_dir)
  if [[ -d "$derived" ]] && ls "$derived"/*.jsonl >/dev/null 2>&1; then
    echo "$derived"
    return 0
  fi
  local latest
  latest=$(find_latest_jsonl_any)
  if [[ -z "$latest" ]]; then
    echo "Error: No jsonl found under $PROJECTS_ROOT (derived dir: $derived)" >&2
    return 1
  fi
  local fallback_dir
  fallback_dir=$(dirname "$latest")
  echo "Note: cwd doesn't match a Claude Code project dir: $derived" >&2
  echo "  (are you running from a different cwd than the session's project root?)" >&2
  echo "  Falling back to dir of the globally newest session: $fallback_dir" >&2
  echo "$fallback_dir"
}

PROJECT_DIR=$(resolve_project_dir) || exit 1

mkdir -p "$ARCHIVE_DIR"

list_sessions() {
  echo "Recent sessions (newest first):"
  echo
  ls -lt "$PROJECT_DIR"/*.jsonl 2>/dev/null | head -10 | awk '{
    # $NF = full path, extract basename
    n = split($NF, parts, "/")
    fname = parts[n]
    gsub(/\.jsonl$/, "", fname)
    short = substr(fname, 1, 8)
    printf "  %s  %s %s %s  (%s bytes)\n", short, $6, $7, $8, $5
  }'
  echo
  echo "Usage: session-archive <id-prefix> [topic]"
  echo "       session-archive latest [topic]"
}

resolve_session() {
  local arg="$1"
  if [[ "$arg" == "latest" ]]; then
    ls -t "$PROJECT_DIR"/*.jsonl 2>/dev/null | head -1
  else
    # match by prefix
    local matches
    matches=$(ls "$PROJECT_DIR"/${arg}*.jsonl 2>/dev/null || true)
    if [[ -z "$matches" ]]; then
      echo "Error: No session matches prefix '$arg'" >&2
      return 1
    fi
    local count
    count=$(echo "$matches" | wc -l | tr -d ' ')
    if [[ "$count" -gt 1 ]]; then
      echo "Error: Multiple matches for '$arg':" >&2
      echo "$matches" >&2
      return 1
    fi
    echo "$matches"
  fi
}

convert_to_md() {
  local jsonl="$1"
  local out="$2"
  local topic="$3"
  local session_id
  session_id=$(basename "$jsonl" .jsonl)
  local session_date
  session_date=$(_mtime_fmt "$jsonl")

  {
    echo "---"
    echo "session_id: $session_id"
    echo "archived_at: $(date '+%Y-%m-%d %H:%M')"
    echo "session_modified: $session_date"
    echo "topic: $topic"
    echo "source: $jsonl"
    echo "---"
    echo
    echo "# Session: $topic"
    echo
    echo "> Session ID: \`$session_id\`"
    echo "> Last modified: $session_date"
    echo

    jq -r '
      if .type == "user" then
        if (.message.content | type) == "string" then
          "\n\n---\n\n## 👤 User\n\n" + .message.content
        else
          empty
        end
      elif .type == "assistant" then
        if (.message.content | type) == "array" then
          (.message.content | map(select(.type == "text") | .text) | join("\n\n")) as $txt |
          if $txt != "" then "\n\n## 🤖 Claude\n\n" + $txt else empty end
        else
          empty
        end
      else
        empty
      end
    ' "$jsonl"
  } > "$out"
}

main() {
  if [[ $# -eq 0 ]]; then
    list_sessions
    exit 0
  fi

  local id_arg="$1"
  local topic="${2:-}"

  local jsonl
  jsonl=$(resolve_session "$id_arg")
  if [[ -z "$jsonl" || ! -f "$jsonl" ]]; then
    echo "Error: session file not found for '$id_arg'" >&2
    exit 1
  fi

  if [[ -z "$topic" ]]; then
    echo "Session file: $jsonl"
    echo -n "Enter topic (used in filename): "
    read -r topic
    if [[ -z "$topic" ]]; then
      echo "Error: topic required" >&2
      exit 1
    fi
  fi

  local safe_topic
  safe_topic=$(echo "$topic" | tr ' /' '__')
  local date_str
  date_str=$(date '+%Y-%m-%d')
  local out="$ARCHIVE_DIR/${date_str}_${safe_topic}.md"

  if [[ -f "$out" ]]; then
    echo "Warning: $out already exists." >&2
    echo -n "Overwrite? [y/N] "
    read -r yn
    if [[ ! "$yn" =~ ^[Yy]$ ]]; then
      echo "Aborted."
      exit 0
    fi
  fi

  convert_to_md "$jsonl" "$out" "$topic"

  local lines
  lines=$(wc -l <"$out" | tr -d ' ')
  echo
  echo "✓ Archived: $out"
  echo "  Lines: $lines"
  echo "  Session: $(basename "$jsonl")"
}

main "$@"
