---
name: setup
description: Wire claude-plan-statusline into ~/.claude/settings.json non-destructively. Backs up the existing file and wraps any existing statusLine command instead of replacing it.
---

# claude-plan-statusline setup

This skill performs the one settings.json edit the plugin needs (Claude Code
restricts plugins from registering a `statusLine` themselves). It is
non-destructive: any existing `statusLine.command` becomes the *base*
status line that the plugin wraps, with `plan: <link>` appended on the end.

## What "the plugin script" means

The status line script ships inside the marketplace clone at:

```
$HOME/.claude/plugins/marketplaces/claude-plan-statusline/scripts/statusline-command.sh
```

The `CLAUDE_PLUGIN_ROOT` plugin-root token does **not** expand inside a
user-level `statusLine.command`, so use the absolute path above (with
`$HOME` literal — Claude Code expands it).

The settings.json command we want to end up with is exactly:

```
bash $HOME/.claude/plugins/marketplaces/claude-plan-statusline/scripts/statusline-command.sh
```

## Steps Claude should take when this skill runs

1. **Read** `~/.claude/settings.json`.
   - If the file doesn't exist or is unreadable, ask the user whether to
     create a fresh `{}` and proceed. If they decline, stop.
   - Parse it as JSON. If it doesn't parse, stop and report the parse
     error — don't try to "fix" it.

2. **Back up** the file before any write:
   - Target path: `~/.claude/settings.json.bak-<UTC-timestamp>` where the
     timestamp is `YYYYMMDDTHHMMSSZ`.
   - Use `cp`; preserve permissions. Do this **only** if a write is about
     to happen (skip the backup if the user chooses Skip below).

3. **Branch on current state**:

   ### Case A — no `statusLine` key
   Add the block straight in:
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "bash $HOME/.claude/plugins/marketplaces/claude-plan-statusline/scripts/statusline-command.sh"
     }
   }
   ```
   Preserve every other top-level key in the file.

   ### Case B — `statusLine` already set
   Show the user the current `statusLine.command` value, then use
   **AskUserQuestion** to offer two options:

   - **Wrap (recommended)** — keep the existing line, just add the plan
     fragment on the end.
   - **Skip** — make no changes; print the manual snippet and exit.

   On **Wrap**:
   - Read the existing `statusLine.command` string verbatim. Call it `EXISTING_CMD`.
   - Ensure a top-level `env` object exists; create one if not.
   - If `env.CLAUDE_PLAN_LINK_BASE` is already set, ask the user before
     overwriting it (show old vs. new). On confirm, overwrite.
   - Set `env.CLAUDE_PLAN_LINK_BASE` = `EXISTING_CMD`.
   - Set `statusLine.command` = `bash $HOME/.claude/plugins/marketplaces/claude-plan-statusline/scripts/statusline-command.sh`.
   - Leave `statusLine.type` as `"command"` (set it if missing).

   On **Skip**:
   - Do not back up, do not write.
   - Print the absolute path of the plugin script and the manual snippet
     from the README's "Manual setup" section.

4. **Write** the updated JSON back atomically:
   - Write to `~/.claude/settings.json.tmp-<UTC-timestamp>` first.
   - `mv` it over `~/.claude/settings.json`.
   - Preserve original indentation if possible; otherwise default to 2-space.

5. **Report** to the user:
   - Which case fired (A or B-Wrap or B-Skip).
   - The backup path (if any).
   - The exact diff of `statusLine` and `env` keys, before vs. after.
   - The next step: "Restart Claude Code or run `/reload-plugins` for the
     status line to refresh."

## Important constraints

- Never silently overwrite an existing `CLAUDE_PLAN_LINK_BASE` value.
- Never proceed past step 2 without producing a backup.
- Never edit any file other than `~/.claude/settings.json` and the backup.
- If the user has `permissions.defaultMode: "plan"`, this skill should
  still run — it asks for permission via AskUserQuestion only on real
  branch points, and uses normal file writes (no destructive operations).

## Sanity checks before reporting success

- The written file is valid JSON (re-parse it).
- `statusLine.command` is a string that contains the absolute plugin path.
- If wrap mode was chosen, `env.CLAUDE_PLAN_LINK_BASE` is a non-empty
  string that matches `EXISTING_CMD`.
- The backup file exists and is non-empty.
