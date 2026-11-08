# oma-malleations

My Omarchy malleations: the small set of *user-layer* changes that make this
machine mine, kept in git so `omarchy update` can never quietly eat them.

Named after Omarchy's own sales pitch — a malleable OS. Everything here lives in
`~/.config/` or `~/.local/bin/`, nothing in `/usr/share/omarchy/`.

## What's in here

| Path | Installs to | What it does |
|---|---|---|
| `bin/fluxfm` | `~/.local/bin/fluxfm` | Plays FluxFM (Berlin) channels in `cliamp`, the TUI player Omarchy ships |
| `bin/omarun` | `~/.local/bin/omarun` | Windows+R "run now" box: `SUPER + R`, type a command, it runs detached and the box closes |
| `config/hypr/bindings.lua` | `~/.config/hypr/bindings.lua` | `SUPER + R` → Run now, `SUPER + SHIFT + R` → Run again (neither key was bound) |
| `config/omarchy/extensions/omarchy-menu.jsonc` | `~/.config/omarchy/extensions/omarchy-menu.jsonc` | `SUPER + SPACE` → **Run now**, **Run again**, **FluxFM** (one Enter) and **FluxFM Channels** (15 stations) |
| `install.sh` | – | Idempotent symlink installer with backups |

Menu icons are Material Design glyphs from the Nerd Font the bar resolves
(`fontFamily: monospace` → JetBrainsMono Nerd Font): `md-radio` U+F0439 on
**FluxFM**, `md-radio_tower` U+F043B on **FluxFM Channels**, `md-music_note`
U+F0387 on each channel, `md-run_fast` U+F046E on **Run now**, `md-history`
U+F02DA on **Run again**. Checked with `fc-list ':charset=f0439'` and the font's
own glyph names — not guessed, so no tofu boxes.

### Run now

`SUPER + R` opens the Omarchy menu's own input mode — one narrow themed field
(`--width 520`, override with `OMARUN_WIDTH`) — runs what you type, and is gone
before the app maps. Escape runs nothing; a second `SUPER + R` closes the box.

```bash
omarun                  # the box                      SUPER + R
omarun --history        # pick from what you ran      SUPER + SHIFT + R
omarun --list           # the remembered commands, newest first
omarun btop             # no box, just run it (what the menu rows do)
```

What a typed line means, in the order it is tried:

| Typed | Runs |
|---|---|
| `!lazygit` | leading `!` → in the default terminal (`omarchy-launch-tui`) |
| `https://omarchy.org`, `omarchy.org` | URL or bare host → default browser |
| `~/Develop`, `~/.config/hypr` | directory / non-executable file → `xdg-open` |
| `btop`, `cliamp`, `nvim` | desktop entry says `Terminal=true` → the terminal |
| `code ~/proj`, `firefox --new-window` | argv, no shell, via `uwsm-app --` |
| `make \| tee log`, `EDITOR=nvim git log` | shell operators or `VAR=` prefix → `bash -lc` |

So a browser lands in `app-graphical.slice` under systemd exactly like
`SUPER + SHIFT + B` does, and the keypress is never held open by the app:
every launch is `setsid --fork`'d, with its stdout/stderr appended to
`~/.local/state/omarun/run.log` because a detached program has no terminal left
to complain to. A command that cannot be found, or a line with an unbalanced
quote, answers with an Omarchy notification instead of nothing.

History is `~/.local/state/omarun/history`: last 200 commands, newest last,
earlier duplicates dropped. Entries holding a literal tab are kept but not
offered in the picker (tab is the menu's own field separator).

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
./install.sh             # link, write cliamp playlist, refresh menu + Hyprland
./install.sh status      # what is linked, what backups exist
```

Real files in the way are moved to
`~/.local/state/oma-malleations/backups/<timestamp>/`, so a first install
preserves whatever you had in `omarchy-menu.jsonc` or `bindings.lua`. Nothing is
deleted. After linking, `install.sh` reloads the menu, runs `hyprctl reload` and
prints `hyprctl configerrors` if Hyprland complained about the bindings.

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
- `omarchy-menu-input` / `omarchy-menu-select` (the menu's `input` and `select`
  modes, `--width`, and the `<glyph><TAB><label>` option form that returns only
  the label), `Menu.qml` `applyDmenuSelection` (Enter closes the box with the
  typed text, no matching row needed).
- `/usr/share/omarchy/shell/Commons/Util.qml` (`execDetached` is `bash -lc`;
  the comment there on keeping input out of a shell is why `omarun` splits argv
  itself), `/usr/share/omarchy/default/hypr/helpers.lua` (`{ launch = … }` wraps
  with `uwsm-app --`, so a plain `o.bind` string stays unwrapped).
- `uwsm-app --help` (accepts an executable name or path, blocks until the app
  exits — hence `setsid --fork`), `/usr/share/applications/*.desktop`
  `Terminal=true` (btop, cliamp, nvim: the terminal-app test),
  `omarchy-launch-tui`, `omarchy-notification-send`.
