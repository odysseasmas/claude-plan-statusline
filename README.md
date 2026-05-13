# claude-plan-statusline

Show the current Claude Code session's plan as a clickable link in the
status line. Click it in the terminal and the plan opens straight in your
editor.

The plugin bundles two pieces:

- A `PostToolUse` hook (`hooks/plan-tracker.py`) that watches `Write`/`Edit`
  calls landing `.md` files in `~/.claude/plans/` and records
  `session_id → plan_path` in `~/.claude/plans/.session-map.json`.
- A status line script (`scripts/statusline-command.sh`) that reads the map
  and renders an OSC 8 hyperlink to your editor of choice (`vscode://`,
  `cursor://`, `zed://`, JetBrains `idea://` — configurable).

Requires `jq` on `PATH` (for the status line script). Python 3 is used by
the hook and ships with macOS.

## Install

### 1. Add the plugin

From within Claude Code:

```
/plugin marketplace add odysseasmas/claude-plan-statusline
/plugin install claude-plan-statusline@claude-plan-statusline
```

> The marketplace name and the plugin name are the same — that's the
> `<plugin>@<marketplace>` syntax above.

```

The plugin's `PostToolUse` hook activates automatically — nothing else needed
for the session-map to start populating.

### 2. Wire up the status line

Plugins can ship hooks but **cannot register a status line** (Claude Code
restriction; only the `agent` and `subagentStatusLine` keys are allowed in a
plugin's bundled `settings.json`). So you add one line yourself.

Edit `~/.claude/settings.json` and add:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash $HOME/.claude/plugins/marketplaces/claude-plan-statusline/scripts/statusline-command.sh"
  }
}
```

> **Path note**: `${CLAUDE_PLUGIN_ROOT}` is only expanded inside plugin-defined
> commands (hooks, MCP, monitors) — it does **not** expand in user-level
> `statusLine`, so use the absolute path above. After running
> `/plugin marketplace add odysseasmas/claude-plan-statusline`, the marketplace is
> cloned to `~/.claude/plugins/marketplaces/claude-plan-statusline/` and the
> script lives there.
>
> If you'd rather not bake the marketplace path into settings, symlink it:
>
> ```bash
> ln -s ~/.claude/plugins/marketplaces/claude-plan-statusline/scripts/statusline-command.sh \
>       ~/.claude/statusline-command.sh
> ```
>
> then point `command` at `bash ~/.claude/statusline-command.sh`.

Restart Claude Code (or run `/reload-plugins`) and you should see, after the
next plan is written, something like:

```
odymas:rainbow | claude-opus-4-7 | ctx: 34% | plan: my-feature-plan
                                                    ^^^^^^^^^^^^^^^ clickable
```

## Configure

Set these env vars in your shell or in `~/.claude/settings.json` under
`"env"`:

| Var                       | Default         | Description                                                                                       |
|---------------------------|-----------------|---------------------------------------------------------------------------------------------------|
| `CLAUDE_PLAN_LINK_EDITOR` | `vscode://file` | URI prefix prepended to the absolute plan path.                                                   |
| `CLAUDE_PLAN_LINK_ONLY`   | unset           | If `1`, emit only the `plan: <link>` fragment — useful for composing into your own status line.   |

### Editor URIs

| Editor                          | Value               |
|---------------------------------|---------------------|
| VS Code                         | `vscode://file`     |
| Cursor                          | `cursor://file`     |
| Zed                             | `zed://file`        |
| JetBrains (IntelliJ, GoLand, …) | `idea://open?file=` |

Example for Cursor users:

```json
{
  "env": {
    "CLAUDE_PLAN_LINK_EDITOR": "cursor://file"
  }
}
```

## Compose with your own status line

If you already have a status line script, set `CLAUDE_PLAN_LINK_ONLY=1` and
shell out to this plugin's script to get just the link fragment:

```sh
plan_fragment=$(CLAUDE_PLAN_LINK_ONLY=1 \
  bash ~/.claude/statusline-command.sh <<< "$input")
printf "%s | %s" "$your_existing_line" "$plan_fragment"
```

## How it works

```
Write/Edit any   →   PostToolUse hook        →   ~/.claude/plans/
.md file in          hooks/plan-tracker.py        .session-map.json
~/.claude/plans/     session_id + plan_path       {session: path, …}

                              │
                              ▼

Status line     ←    scripts/statusline-
renders OSC 8        command.sh
hyperlink to         looks up session_id,
the plan file        emits vscode:// link
```

The hook only triggers for `.md` files under `~/.claude/plans/`, so it has
no measurable impact on other Write/Edit calls.

## Uninstall

```
/plugin uninstall claude-plan-statusline
```

Then remove the `statusLine` block you added to `~/.claude/settings.json`
and delete `~/.claude/plans/.session-map.json` if you want.

## License

MIT — see [LICENSE](./LICENSE).
