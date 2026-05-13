#!/bin/sh
# Claude Code status line: shows session info plus a clickable link to the
# current session's plan file (recorded by the plan-tracker hook).
#
# Configurable via env vars (set in ~/.claude/settings.json under "env",
# or your shell rc):
#   CLAUDE_PLAN_LINK_EDITOR    URI prefix prepended to the absolute plan path.
#                              Default: "vscode://file"
#                              Examples:
#                                cursor://file
#                                zed://file
#                                idea://open?file=    (JetBrains)
#   CLAUDE_PLAN_LINK_ONLY      If "1", emit ONLY the plan link (no user/dir/
#                              model/ctx). Useful for composing into a custom
#                              status line.
#   CLAUDE_PLAN_LINK_BASE      A shell command to run as the "base" status
#                              line. When set, the same stdin is piped into
#                              it and its stdout is rendered, with the plan
#                              link appended as " | plan: <link>" when a
#                              mapping exists. Lets the plugin wrap an
#                              existing status line non-destructively.

input=$(cat)

editor_uri="${CLAUDE_PLAN_LINK_EDITOR:-vscode://file}"

session_id=$(echo "$input" | jq -r '.session_id // empty')

# ANSI / OSC building blocks — literal control bytes, NOT escape sequences,
# so we can use %s in printf and avoid %b re-interpreting backslashes.
ESC=$(printf '\033')
ST="${ESC}\\"
CYAN="${ESC}[0;36m"
YELLOW="${ESC}[0;33m"
MAGENTA="${ESC}[0;35m"
GREEN="${ESC}[0;32m"
RESET="${ESC}[0m"

# Build the plan link fragment (OSC 8 hyperlink) if we have a mapping.
plan_info=""
map="$HOME/.claude/plans/.session-map.json"
if [ -n "$session_id" ] && [ -f "$map" ]; then
  plan_path=$(jq -r --arg s "$session_id" '.[$s] // empty' "$map" 2>/dev/null)
  if [ -n "$plan_path" ] && [ -f "$plan_path" ]; then
    slug=$(basename "$plan_path" .md)
    link="${ESC}]8;;${editor_uri}${plan_path}${ST}${slug}${ESC}]8;;${ST}"
    plan_info="${GREEN}plan:${RESET} ${link}"
  fi
fi

if [ "$CLAUDE_PLAN_LINK_ONLY" = "1" ]; then
  printf "%s" "$plan_info"
  exit 0
fi

# Wrap mode: if a base status line command is provided, run it with the
# same stdin and append the plan link. Lets users keep their existing
# status line and just add the plan link onto it.
if [ -n "$CLAUDE_PLAN_LINK_BASE" ]; then
  base_output=$(printf "%s" "$input" | eval "$CLAUDE_PLAN_LINK_BASE")
  if [ -n "$plan_info" ]; then
    printf "%s | %s" "$base_output" "$plan_info"
  else
    printf "%s" "$base_output"
  fi
  exit 0
fi

model=$(echo "$input" | jq -r '.model.display_name // "unknown"')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
user=$(whoami)
short_dir=$(basename "$cwd")

ctx_info=""
if [ -n "$used_pct" ]; then
  ctx_info=" | ctx: ${used_pct}%"
fi

sep_plan=""
if [ -n "$plan_info" ]; then
  sep_plan=" | "
fi

printf "%s%s%s:%s%s%s | %s%s%s%s%s" \
  "$CYAN" "$user" "$RESET" \
  "$YELLOW" "$short_dir" "$RESET" \
  "$MAGENTA" "$model" "$RESET" \
  "$ctx_info" "$sep_plan" "$plan_info"
