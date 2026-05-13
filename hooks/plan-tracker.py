#!/usr/bin/env python3
"""PostToolUse hook: when Write/Edit lands a file in ~/.claude/plans/,
record session_id -> plan_path in ~/.claude/plans/.session-map.json
so the status line can display a link to the current session's plan.

Uses Python with json.loads(strict=False) because Claude Code's hook input
contains raw control characters (literal newlines from file content) inside
string values, which strict JSON parsers like jq reject.
"""
import json
import os
import sys
import tempfile

raw = sys.stdin.read()
try:
    data = json.loads(raw, strict=False)
except json.JSONDecodeError:
    sys.exit(0)

session_id = data.get("session_id") or ""
file_path = (data.get("tool_input") or {}).get("file_path") or ""

if not session_id or not file_path:
    sys.exit(0)

plans_dir = os.path.expanduser("~/.claude/plans")
if not (file_path.startswith(plans_dir + "/") and file_path.endswith(".md")):
    sys.exit(0)

# Skip the dotfiles we use ourselves (e.g. .session-map.json, .hook-debug.log)
if os.path.basename(file_path).startswith("."):
    sys.exit(0)

os.makedirs(plans_dir, exist_ok=True)
map_path = os.path.join(plans_dir, ".session-map.json")
try:
    with open(map_path) as f:
        m = json.load(f)
    if not isinstance(m, dict):
        m = {}
except (FileNotFoundError, json.JSONDecodeError):
    m = {}

m[session_id] = file_path

fd, tmp = tempfile.mkstemp(prefix=".session-map.", dir=plans_dir)
try:
    with os.fdopen(fd, "w") as f:
        json.dump(m, f, indent=2)
    os.replace(tmp, map_path)
except Exception:
    try:
        os.unlink(tmp)
    except Exception:
        pass
