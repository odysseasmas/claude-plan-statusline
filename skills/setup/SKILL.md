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

2. **Detect mode** — is the plugin already wired up?
   - Treat the file as **already configured** when
     `statusLine.command` is a string and contains the substring
     `marketplaces/claude-plan-statusline/scripts/statusline-command.sh`.
   - Otherwise this is a first-time **install**.

3. **Back up** the file before any write:
   - Target path: `~/.claude/settings.json.bak-<UTC-timestamp>` where the
     timestamp is `YYYYMMDDTHHMMSSZ`.
   - Use `cp`; preserve permissions. Do this **only** if a write is about
     to happen (skip the backup on Reconfigure-no-change and on Case B-Skip).

4. **Ask the user** what to do, using a single `AskUserQuestion` call.

   Always include the **editor** question (one of four options; the tool
   auto-adds "Other" so users can paste a custom URI):

   | Option                | URI value           |
   |-----------------------|---------------------|
   | VS Code (Recommended) | `vscode://file`     |
   | Cursor                | `cursor://file`     |
   | Zed                   | `zed://file`        |
   | JetBrains             | `idea://open?file=` |

   Call the chosen value `EDITOR_URI`. If `env.CLAUDE_PLAN_LINK_EDITOR`
   is already present in `settings.json`, show its current value in the
   question description so the user knows what they'd be overwriting.

   **If this is an Install** *and* a `statusLine` key already exists,
   include a second question in the same `AskUserQuestion` call:

   - **Wrap (recommended)** — keep the existing line, just add the plan
     fragment on the end.
   - **Skip** — make no changes; print the manual snippet and exit.

   On a **Reconfigure** (already wired up), do **not** ask the Wrap/Skip
   question — the user just wants to change the editor. Skip it.

5. **Apply the chosen path**:

   ### Reconfigure — already wired up, only the editor changes
   - Compute `CURRENT_EDITOR_URI` = `env.CLAUDE_PLAN_LINK_EDITOR` if set,
     else `vscode://file` (the script's default).
   - If `EDITOR_URI == CURRENT_EDITOR_URI`: nothing to do. Skip the
     backup, skip the write, and tell the user "already set to
     `<EDITOR_URI>` — no change."
   - Otherwise: ensure `env` exists, set `env.CLAUDE_PLAN_LINK_EDITOR =
     EDITOR_URI`, leave `statusLine`, `env.CLAUDE_PLAN_LINK_BASE`, and
     every other key untouched. Write, report the URI change.

   ### Case A — no `statusLine` key
   - Add the statusLine block:
     ```json
     {
       "statusLine": {
         "type": "command",
         "command": "bash $HOME/.claude/plugins/marketplaces/claude-plan-statusline/scripts/statusline-command.sh"
       }
     }
     ```
   - Ensure a top-level `env` object exists; create one if not.
   - Set `env.CLAUDE_PLAN_LINK_EDITOR = EDITOR_URI`.
   - Preserve every other top-level key in the file.

   ### Case B-Wrap — existing `statusLine`, user chose Wrap
   - Read the existing `statusLine.command` string verbatim. Call it `EXISTING_CMD`.
   - Ensure a top-level `env` object exists; create one if not.
   - If `env.CLAUDE_PLAN_LINK_BASE` is already set, ask the user before
     overwriting it (show old vs. new). On confirm, overwrite.
   - Set `env.CLAUDE_PLAN_LINK_BASE = EXISTING_CMD`.
   - If `env.CLAUDE_PLAN_LINK_EDITOR` is already set to a value
     **different** from `EDITOR_URI`, ask once before overwriting.
     Otherwise overwrite silently.
   - Set `env.CLAUDE_PLAN_LINK_EDITOR = EDITOR_URI`.
   - Set `statusLine.command` = `bash $HOME/.claude/plugins/marketplaces/claude-plan-statusline/scripts/statusline-command.sh`.
   - Leave `statusLine.type` as `"command"` (set it if missing).

   ### Case B-Skip — existing `statusLine`, user chose Skip
   - Do not back up, do not write.
   - Print the absolute path of the plugin script and a manual settings
     snippet that already includes `env.CLAUDE_PLAN_LINK_EDITOR =
     EDITOR_URI`, so the user has a complete recipe even if they want
     to apply it by hand later.

6. **Write** the updated JSON back atomically:
   - Write to `~/.claude/settings.json.tmp-<UTC-timestamp>` first.
   - `mv` it over `~/.claude/settings.json`.
   - Preserve original indentation if possible; otherwise default to 2-space.

7. **Report** to the user:
   - Which path fired (Reconfigure / Case A / Case B-Wrap / Case B-Skip).
   - The chosen editor URI and whether it overwrote a previous value.
   - The backup path (if any).
   - The exact diff of `statusLine` and `env` keys, before vs. after.
   - The next step: "Restart Claude Code or run `/reload-plugins` for the
     status line to refresh."

## Important constraints

- Never silently overwrite an existing `CLAUDE_PLAN_LINK_BASE` value.
- Never silently overwrite an existing `CLAUDE_PLAN_LINK_EDITOR` value
  that differs from the user's new choice.
- Never proceed past step 2 without producing a backup.
- Never edit any file other than `~/.claude/settings.json` and the backup.
- If the user has `permissions.defaultMode: "plan"`, this skill should
  still run — it asks for permission via AskUserQuestion only on real
  branch points, and uses normal file writes (no destructive operations).

## Sanity checks before reporting success

- The written file is valid JSON (re-parse it).
- `statusLine.command` is a string that contains the absolute plugin path.
- `env.CLAUDE_PLAN_LINK_EDITOR` equals `EDITOR_URI`.
- If wrap mode was chosen, `env.CLAUDE_PLAN_LINK_BASE` is a non-empty
  string that matches `EXISTING_CMD`.
- The backup file exists and is non-empty.
