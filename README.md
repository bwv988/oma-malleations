# oma-malleations

My Omarchy malleations: the small set of *user-layer* changes that make this
machine mine, kept in git so `omarchy update` can never quietly eat them.

Named after Omarchy's own sales pitch — a malleable OS. Everything here lives in
`~/.config/` or `~/.local/bin/`, nothing in `/usr/share/omarchy/`.

## What's in here

| Path | Installs to | What it does |
|---|---|---|
| `bin/fluxfm` | `~/.local/bin/fluxfm` | Plays FluxFM (Berlin) channels in `cliamp`, the TUI player Omarchy ships |
| `config/omarchy/extensions/omarchy-menu.jsonc` | `~/.config/omarchy/extensions/omarchy-menu.jsonc` | `SUPER + SPACE` → **FluxFM** (one Enter) and **FluxFM Channels** (15 stations) |
| `install.sh` | – | Idempotent symlink installer with backups |

### FluxFM usage

```bash
fluxfm                  # FluxFM Berlin 24/7
fluxfm 80s              # any channel, see: fluxfm --list
fluxfm --sync-playlist  # rewrite the all-channels playlist for the cliamp TUI
```

- Player already running → the station is switched over cliamp's IPC socket, no
  new window, the Omarchy audio panel (MPRIS) updates in place.
- Player not running → cliamp opens in a terminal on that station, using
  Omarchy's TUI app-id (`cliamp`) so it behaves like `SUPER + SHIFT + ALT + M`.
- Streaming URLs are the direct 320 kbps MP3s, verified against
  `fluxfm.streamabc.net` (unknown slugs silently fall back to Berlin, so each
  slug was checked by its resolved stream id, not by HTTP 200).

## Install

```bash
cd ~/Develop/oma-malleations
./install.sh --dry-run   # see what it would touch
./install.sh             # link, write cliamp playlist, refresh the menu
./install.sh status      # what is linked, what backups exist
```

Real files in the way are moved to
`~/.local/state/oma-malleations/backups/<timestamp>/`, so a first install
preserves whatever you had in `omarchy-menu.jsonc`. Nothing is deleted.

## How to keep track of customizations (what people actually do)

The core problem: Omarchy ships defaults in `/usr/share/omarchy/` (owned by the
package, replaced on update) and your overrides in `~/.config/` (yours). Only
track the second kind.

Three common patterns:

1. **Symlink farm** (what this repo does). Repo layout mirrors `$HOME`; a small
   installer links each file into place. Edits in `~/.config/` are edits in the
   repo — `git status` always shows the truth, no copy step to forget.
2. **`stow` / `chezmoi` / `yadm`.** Same idea, a mature tool on top: stow gives
   you per-package symlink trees, chezmoi adds templating and per-machine
   differences (`{{ .chezmoi.hostname }}`), yadm is "git on `$HOME`" with
   encryption. Worth switching to if this repo grows past one machine.
3. **Copy + install script** (no symlinks). Simple, but you must remember to copy
   back after editing — people drift. My old `~/Develop/dotfiles` is this style.

Omarchy-specific notes that matter more than the tooling:

- **Sanctioned extension points** — they survive updates by design:
  `~/.config/omarchy/extensions/omarchy-menu.jsonc` (menu rows),
  `~/.config/omarchy/hooks/<event>.d/` (automation hooks),
  `~/.config/hypr/bindings.lua` (`o.bind` / `o.rebind`),
  `~/.config/omarchy/themes/<name>/` (custom themes),
  `~/.config/omarchy/plugins/` (cloned shell plugins).
  Prefer these over hand-editing a stock config file.
- **`omarchy refresh <component>`** resets a config to defaults and backs up your
  version first — recover from a bad edit rather than by re-reading the defaults.
- **Migrations and updates** touch `/usr/share/omarchy/` and `~/.local/state/`,
  not your `~/.config/` files; the real risk is *stock* config gaining new
  options, which a wholesale copied file hides. Another reason to keep tracked
  files small and specific (this repo overrides only the menu extension).
- Committing the `/usr/share/omarchy/` file you edited "for reference" is the
  one anti-pattern: it will look authoritative later and be wrong.

## Adding a new malleation

1. Put the file in the repo under `config/...` or `bin/...` (mirror the real path).
2. Add a `link` line in `install.sh`.
3. `./install.sh`, commit.

Verified sources used while building this:

- `omarchy menu --help`, `/usr/share/omarchy/shell/plugins/menu/Menu.qml`
  (`action` rows run through `bash -lc`, dotted ids imply parent submenus).
- `/usr/share/omarchy/default/hypr/bindings/applications.lua` (cliamp is
  preinstalled and bound to `SUPER + SHIFT + ALT + M`).
- `cliamp --help`, `cliamp open --help` (`cliamp://play?url=…` plays over IPC or
  starts the player), `cliamp playlist create` (playlist TOML format).
