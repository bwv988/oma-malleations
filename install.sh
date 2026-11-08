#!/usr/bin/env bash
# install.sh - link oma-malleations into the live system
#
#   ./install.sh            link everything, reload menu, Hyprland and tmux
#   ./install.sh --dry-run  show what would happen
#   ./install.sh status     show link state
#
# Repo layout mirrors the home directory:
#   config/<path>  ->  ~/.config/<path>
#   bin/<name>     ->  ~/.local/bin/<name>
#
# Real files that are in the way are moved to
#   ~/.local/state/oma-malleations/backups/<timestamp>/
# so nothing is ever lost. Re-running is safe. A symlink in the way is moved
# too, never written through, so no other repo's file is ever modified.

set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
state="${XDG_STATE_HOME:-$HOME/.local/state}/oma-malleations"
backup="$state/backups/$(date +%Y%m%d-%H%M%S)"
dry_run=0
mode=install

case "${1:-}" in
  --dry-run | -n) dry_run=1 ;;
  status | --status) mode=status ;;
  -h | --help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  "") ;;
  *)
    printf 'install.sh: unknown argument %q\n' "$1" >&2
    exit 2
    ;;
esac

run() {
  if ((dry_run)); then
    printf 'would: %s\n' "$*"
  else
    "$@"
  fi
}

# stash <destination>: move a real file or symlink into this run's backup dir.
stash() {
  local dest=$1 rel
  rel=${dest#"$HOME"/}
  run mkdir -p "$backup/$(dirname "$rel")"
  run mv "$dest" "$backup/$rel"
  printf 'backup  %s -> %s\n' "$dest" "$backup/$rel"
}

# link <target-in-repo> <destination>
link() {
  local src="$repo/$1" dest="$2" current

  if [[ ! -e $src ]]; then
    printf 'missing in repo: %s\n' "$1" >&2
    return 1
  fi

  if [[ -L $dest ]]; then
    current=$(readlink -f "$dest")
    if [[ $current == "$(readlink -f "$src")" ]]; then
      printf 'linked  %s\n' "$dest"
      return 0
    fi
  fi

  if [[ -e $dest || -L $dest ]]; then
    stash "$dest"
  fi

  run mkdir -p "$(dirname "$dest")"
  run ln -sfn "$src" "$dest"
  printf 'new     %s -> %s\n' "$dest" "$src"
}

# layer <config-path> <include-line>
#
# Keep ~/.config/<config-path> as the shipped Omarchy default and have it end by
# sourcing <include-line> — the pattern for a config whose deltas are recorded
# in this repo instead of replacing the whole stock file. A symlink standing in
# the way is stashed and replaced by the default, so the snippet becomes the only
# source of the deltas; an existing real file is left alone, only appended to.
layer() {
  local rel=$1 include=$2 dest="$HOME/.config/$1"
  local stock="${OMARCHY_PATH:-/usr/share/omarchy}/config/$1"

  if [[ ! -f $stock ]]; then
    printf 'not a shipped config on this system: %s\n' "$rel" >&2
    return 1
  fi

  if [[ -L $dest ]]; then
    stash "$dest"
    run mkdir -p "$(dirname "$dest")"
    run cp "$stock" "$dest"
    printf 'default %s (replaced the symlink with the Omarchy default)\n' "$dest"
  elif [[ ! -e $dest ]]; then
    run mkdir -p "$(dirname "$dest")"
    run cp "$stock" "$dest"
    printf 'default %s\n' "$dest"
  fi

  if grep -qxF -- "$include" "$dest" 2>/dev/null; then
    printf 'sources %s\n' "$include"
    return 0
  fi

  if ((dry_run)); then
    printf 'would: append "%s" to %s\n' "$include" "$dest"
  else
    printf '\n%s\n' "$include" >>"$dest"
    printf 'append  %s (one line, sources the snippet)\n' "$dest"
  fi
}

show_status() {
  local dest
  for dest in "$HOME/.config/omarchy/extensions/omarchy-menu.jsonc" \
    "$HOME/.local/bin/fluxfm" \
    "$HOME/.local/bin/omarun" \
    "$HOME/.config/hypr/bindings.lua" \
    "$HOME/.config/tmux/oma-malleations.conf"; do
    if [[ -L $dest ]]; then
      printf '%-52s -> %s\n' "$dest" "$(readlink "$dest")"
    elif [[ -e $dest ]]; then
      printf '%-52s (real file, not linked)\n' "$dest"
    else
      printf '%-52s (missing)\n' "$dest"
    fi
  done

  local tmux_conf="$HOME/.config/tmux/tmux.conf"
  if [[ -L $tmux_conf ]]; then
    printf '%-52s (symlink to another repo: %s)\n' "$tmux_conf" "$(readlink "$tmux_conf")"
  elif grep -qxF -- "source-file ~/.config/tmux/oma-malleations.conf" "$tmux_conf" 2>/dev/null; then
    printf '%-52s (Omarchy default + oma-malleations.conf)\n' "$tmux_conf"
  elif [[ -e $tmux_conf ]]; then
    printf '%-52s (real file, does not source the snippet)\n' "$tmux_conf"
  else
    printf '%-52s (missing)\n' "$tmux_conf"
  fi
  if [[ -d ${state}/backups ]]; then
    printf '\nbackups in %s:\n' "$state/backups"
    ls -1 "$state/backups"
  fi
}

if [[ $mode == status ]]; then
  show_status
  exit 0
fi

link "config/omarchy/extensions/omarchy-menu.jsonc" \
  "$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"
link "bin/fluxfm" "$HOME/.local/bin/fluxfm"
link "bin/omarun" "$HOME/.local/bin/omarun"
link "config/hypr/bindings.lua" "$HOME/.config/hypr/bindings.lua"
# tmux: the snippet holds only the deltas, the stock file just sources it.
link "config/tmux/oma-malleations.conf" "$HOME/.config/tmux/oma-malleations.conf"
layer "tmux/tmux.conf" "source-file ~/.config/tmux/oma-malleations.conf"

if ((!dry_run)); then
  chmod +x "$repo/bin/fluxfm" "$repo/bin/omarun"
  # All-channels playlist, visible inside cliamp under Local Playlists.
  "$repo/bin/fluxfm" --sync-playlist
  # Re-read the JSONC extensions without restarting the bar.
  if command -v omarchy >/dev/null 2>&1; then
    omarchy menu refresh >/dev/null 2>&1 || \
      printf 'note: run "omarchy menu refresh" (or "omarchy restart shell") to reload the menu\n'
  fi
  # Keybindings are Lua: Hyprland reloads on save, then says what broke.
  if command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1 || true
    if hyprctl configerrors 2>&1 | grep -qv '^$'; then
      printf '\nHyprland config errors:\n'
      hyprctl configerrors
    fi
  fi
  # tmux: source the new config into the running server (no session is killed).
  if command -v omarchy-restart-tmux >/dev/null 2>&1; then
    omarchy-restart-tmux >/dev/null 2>&1 || true
  fi
  printf '\nDone. SUPER + R runs, SUPER + SHIFT + R runs again, tmux is on CTRL + A.\n'
fi
