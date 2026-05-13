# claude-plan-statusline

Show the current Claude Code session's plan as a clickable link in the
status line. Click it in the terminal and the plan opens straight in your
editor.

## Supported platforms

| Platform           | Supported | Notes                                                                |
|--------------------|-----------|----------------------------------------------------------------------|
| macOS              | yes       | Tested. `jq` via Homebrew if not present.                            |
| Linux              | yes       | Needs `jq` (apt/dnf/pacman) and a terminal with OSC 8 support — most modern ones (Kitty, WezTerm, GNOME Terminal, Konsole, Alacritty + config) qualify. |
| Windows (WSL)      | yes       | Run Claude Code inside WSL; the script lives on the Linux side.      |
| Windows (cmd/pwsh) | no        | The status line script is POSIX `sh`; there's no PowerShell port yet. |

OSC 8 hyperlink support is what makes the plan link clickable. If your
terminal doesn't render OSC 8, you'll still see the slug — it just won't
be clickable. Click-to-open also needs the editor URI scheme (`vscode://`,
`cursor://`, …) registered on your system; most editors register it on
install.

## Install

From within Claude Code:

```
/plugin marketplace add odysseasmas/claude-plan-statusline
/plugin install claude-plan-statusline@claude-plan-statusline
/reload-plugins
/claude-plan-statusline:setup
```

### What `:setup` does

Plugins can ship hooks but **cannot register a status line** (Claude
Code restriction; only the `agent` and `subagentStatusLine` keys are
allowed in a plugin's bundled `settings.json`). One line needs to land
in `~/.claude/settings.json`; the setup skill handles it for you:

- backs up your current `settings.json`,
- if no `statusLine` exists, adds one pointing at the plugin's script,
- if a `statusLine` is already there, **wraps** it — your existing
  command stays, and the plan link is appended on the end via
  `CLAUDE_PLAN_LINK_BASE`. Your dir / git / model / context rendering
  keeps working; the plan link sits at the end.

### Manual setup (if you'd rather skip the skill)

Edit `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash $HOME/.claude/plugins/marketplaces/claude-plan-statusline/scripts/statusline-command.sh"
  }
}
```

To wrap your existing status line by hand, move your old command into
`env.CLAUDE_PLAN_LINK_BASE`:

```json
{
  "env": {
    "CLAUDE_PLAN_LINK_BASE": "bash ~/.claude/statusline-command.sh"
  },
  "statusLine": {
    "type": "command",
    "command": "bash $HOME/.claude/plugins/marketplaces/claude-plan-statusline/scripts/statusline-command.sh"
  }
}
```

> **Path note**: `${CLAUDE_PLUGIN_ROOT}` is only expanded inside
> plugin-defined commands (hooks, MCP, monitors) — it does **not** expand
> in user-level `statusLine`, so use the absolute path above. After
> running `/plugin marketplace add odysseasmas/claude-plan-statusline`,
> the marketplace is cloned to
> `~/.claude/plugins/marketplaces/claude-plan-statusline/`.

## What's inside

The plugin bundles three pieces:

- A `PostToolUse` hook (`hooks/plan-tracker.py`) that watches `Write`/`Edit`
  calls landing `.md` files in `~/.claude/plans/` and records
  `session_id → plan_path` in `~/.claude/plans/.session-map.json`.
- A status line script (`scripts/statusline-command.sh`) that reads the map
  and renders an OSC 8 hyperlink to your editor of choice (`vscode://`,
  `cursor://`, `zed://`, JetBrains `idea://` — configurable). It can also
  **wrap** an existing status line so you don't lose your current one.
- A setup skill (`/claude-plan-statusline:setup`) that wires
  `~/.claude/settings.json` for you, non-destructively.

Requires `jq` on `PATH` (for the status line script) and Python 3 (for the
hook — ships with macOS, present by default on most Linux distros).

## Configure

Set these env vars in your shell or in `~/.claude/settings.json` under
`"env"`:

| Var                       | Default         | Description                                                                                       |
|---------------------------|-----------------|---------------------------------------------------------------------------------------------------|
| `CLAUDE_PLAN_LINK_EDITOR` | `vscode://file` | URI prefix prepended to the absolute plan path.                                                   |
| `CLAUDE_PLAN_LINK_BASE`   | unset           | Shell command to run as the base status line; its output is wrapped with `\| plan: <link>` appended. |
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

Two ways:

**Wrap mode (recommended)** — point Claude Code at the plugin's script,
and set `CLAUDE_PLAN_LINK_BASE` to your existing command. The plugin runs
your script first, then appends ` | plan: <link>` if a mapping exists.
The skill does this for you.

**Fragment mode** — keep your own status line as the entry point and
shell out to this plugin with `CLAUDE_PLAN_LINK_ONLY=1` to grab just the
link fragment:

```sh
plan_fragment=$(CLAUDE_PLAN_LINK_ONLY=1 \
  bash ~/.claude/plugins/marketplaces/claude-plan-statusline/scripts/statusline-command.sh <<< "$input")
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

The hook only triggers for `.md` files under `~/.claude/plans/`, so it
has no measurable impact on other Write/Edit calls.

## Uninstall

```
/plugin uninstall claude-plan-statusline
```

Then remove the `statusLine` block you added to `~/.claude/settings.json`
(or restore from the `settings.json.bak-*` file the setup skill left
behind) and delete `~/.claude/plans/.session-map.json` if you want.

## License

MIT — see [LICENSE](./LICENSE).
