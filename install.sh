#!/usr/bin/env bash
# install.sh - link oma-malleations into the live system
#
#   ./install.sh            link everything, refresh the menu
#   ./install.sh --dry-run  show what would happen
#   ./install.sh status     show link state
#
# Repo layout mirrors the home directory:
#   config/<path>  ->  ~/.config/<path>
#   bin/<name>     ->  ~/.local/bin/<name>
#
# Real files that are in the way are moved to
#   ~/.local/state/oma-malleations/backups/<timestamp>/
# so nothing is ever lost. Re-running is safe.

set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
state="${XDG_STATE_HOME:-$HOME/.local/state}/oma-malleations"
backup="$state/backups/$(date +%Y%m%d-%H%M%S)"
dry_run=0
mode=install

case "${1:-}" in
  --dry-run | -n) dry_run=1 ;;
  status | --status) mode=status ;;
  -h | --help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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
    run mkdir -p "$backup/$(dirname "${dest#"$HOME"/}")"
    run mv "$dest" "$backup/${dest#"$HOME"/}"
    printf 'backup  %s -> %s\n' "$dest" "$backup/${dest#"$HOME"/}"
  fi

  run mkdir -p "$(dirname "$dest")"
  run ln -sfn "$src" "$dest"
  printf 'new     %s -> %s\n' "$dest" "$src"
}

show_status() {
  local dest
  for dest in "$HOME/.config/omarchy/extensions/omarchy-menu.jsonc" \
    "$HOME/.local/bin/fluxfm"; do
    if [[ -L $dest ]]; then
      printf '%-52s -> %s\n' "$dest" "$(readlink "$dest")"
    elif [[ -e $dest ]]; then
      printf '%-52s (real file, not linked)\n' "$dest"
    else
      printf '%-52s (missing)\n' "$dest"
    fi
  done
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

if ((!dry_run)); then
  chmod +x "$repo/bin/fluxfm"
  # All-channels playlist, visible inside cliamp under Local Playlists.
  "$repo/bin/fluxfm" --sync-playlist
  # Re-read the JSONC extensions without restarting the bar.
  if command -v omarchy >/dev/null 2>&1; then
    omarchy menu refresh >/dev/null 2>&1 || \
      printf 'note: run "omarchy menu refresh" (or "omarchy restart shell") to reload the menu\n'
  fi
  printf '\nDone. SUPER + SPACE, then type "flux".\n'
fi
