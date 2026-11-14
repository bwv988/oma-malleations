#!/usr/bin/env bash
# install.sh - link oma-malleations into the live system
#
#   ./install.sh            link everything, install the fan-control root bits,
#                           reload the menu, Hyprland and tmux
#   ./install.sh --dry-run  show what would happen
#   ./install.sh --user-only
#                           skip the root-owned fan-control pieces
#   ./install.sh status     show link state
#
# Repo layout mirrors the home directory:
#   config/<path>  ->  ~/.config/<path>
#   bin/<name>     ->  ~/.local/bin/<name>
# Root-owned files live under system/ and are copied, never symlinked, because
# a sudoers rule must not point at a file the user can edit.
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
user_only=0
fan_system_ok=1
mode=install

while (($#)); do
  case $1 in
    --dry-run | -n) dry_run=1 ;;
    --user-only) user_only=1 ;;
    status | --status) mode=status ;;
    -h | --help)
      sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      printf 'install.sh: unknown argument %q\n' "$1" >&2
      exit 2
      ;;
  esac
  shift
done

if ((EUID == 0)); then
  printf 'install.sh: run as your user, not with sudo; it asks for sudo when needed.\n' >&2
  exit 1
fi

run() {
  if ((dry_run)); then
    printf 'would: %s\n' "$*"
  else
    "$@"
  fi
}

sudo_run() {
  if ((dry_run)); then
    printf 'would: sudo %s\n' "$*"
  else
    sudo "$@"
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

# show_installed <repo-file> <installed-path>
show_installed() {
  local src=$1 dest=$2
  if [[ -L $dest ]]; then
    printf '%-52s (symlink, not a root-owned copy)\n' "$dest"
  elif [[ ! -e $dest ]]; then
    printf '%-52s (missing)\n' "$dest"
  elif cmp -s "$src" "$dest"; then
    printf '%-52s (installed, up to date)\n' "$dest"
  else
    printf '%-52s (installed, differs from repo)\n' "$dest"
  fi
}

# The fan-control pieces that must be root-owned. The user-facing command is a
# copy, not a symlink, so `sudo fancontrol` can never execute user-writable code.
install_fancontrol_system() {
  local template tmp sudoers_tmp fan_control reply
  printf '\nfancontrol: installing the root-owned pieces\n'

  if ! command -v sudo >/dev/null 2>&1; then
    printf 'sudo is not available; fan control needs these files installed as root:\n' >&2
    printf '  /usr/local/bin/fancontrol\n' >&2
    printf '  /usr/local/lib/oma-malleations/fancontrol-root\n' >&2
    printf '  /etc/systemd/system/fancontrol-guard.service\n' >&2
    printf '  /etc/modprobe.d/oma-malleations-fancontrol.conf\n' >&2
    printf '  /etc/sudoers.d/oma-malleations-fancontrol\n' >&2
    return 1
  fi

  sudo_run install -Dm0755 "$repo/bin/fancontrol" /usr/local/bin/fancontrol
  sudo_run install -Dm0755 "$repo/bin/fancontrol-root" \
    /usr/local/lib/oma-malleations/fancontrol-root
  sudo_run install -Dm0644 "$repo/system/systemd/fancontrol-guard.service" \
    /etc/systemd/system/fancontrol-guard.service
  sudo_run install -Dm0644 "$repo/system/modprobe.d/oma-malleations-fancontrol.conf" \
    /etc/modprobe.d/oma-malleations-fancontrol.conf

  template="$repo/system/sudoers.d/oma-malleations-fancontrol.in"
  sudoers_tmp=/etc/sudoers.d/.oma-malleations-fancontrol.new
  tmp=$(mktemp)
  sed "s|@USER@|$(id -un)|g" "$template" >"$tmp"
  if ((dry_run)); then
    printf 'would: install -Dm0440 <rendered %s> /etc/sudoers.d/oma-malleations-fancontrol\n' \
      "$(basename "$template")"
    sed 's/^/    /' "$tmp"
  else
    if ! sudo install -Dm0440 "$tmp" "$sudoers_tmp"; then
      rm -f "$tmp"
      printf 'could not stage the sudoers file\n' >&2
      return 1
    fi
    if ! sudo visudo -cf "$sudoers_tmp" >/dev/null; then
      sudo rm -f "$sudoers_tmp"
      rm -f "$tmp"
      printf 'generated sudoers file failed visudo validation; not installing\n' >&2
      return 1
    fi
    sudo mv "$sudoers_tmp" /etc/sudoers.d/oma-malleations-fancontrol
    sudo chmod 0440 /etc/sudoers.d/oma-malleations-fancontrol
  fi
  rm -f "$tmp"

  sudo_run systemctl daemon-reload
  if systemctl is-active --quiet fancontrol-guard.service 2>/dev/null; then
    sudo_run systemctl restart fancontrol-guard.service
  fi

  fan_control=missing
  if [[ -r /sys/module/thinkpad_acpi/parameters/fan_control ]]; then
    fan_control=$(</sys/module/thinkpad_acpi/parameters/fan_control)
  fi

  if [[ $fan_control != Y ]]; then
    printf '\nthinkpad_acpi is loaded with fan_control=%s.\n' "$fan_control"
    if ((dry_run)); then
      printf 'The module option would be installed; it takes effect after a reboot, or now with:\n'
    else
      printf 'The module option is installed; it takes effect after a reboot, or now with:\n'
    fi
    printf '  sudo modprobe -r thinkpad_acpi && sudo modprobe thinkpad_acpi\n'
    if ((dry_run)); then
      printf 'would: ask to reload thinkpad_acpi now\n'
    elif [[ -t 0 ]]; then
      printf '\nReload thinkpad_acpi now to enable fan control? [y/N] '
      read -r reply || reply=
      case $reply in
        [Yy]*)
          if sudo modprobe -r thinkpad_acpi && sudo modprobe thinkpad_acpi; then
            if [[ -r /sys/module/thinkpad_acpi/parameters/fan_control ]]; then
              fan_control=$(</sys/module/thinkpad_acpi/parameters/fan_control)
            fi
            if [[ $fan_control == Y ]]; then
              printf 'reloaded thinkpad_acpi; fan_control=1\n'
            else
              printf 'reloaded, but fan_control is still %s; reboot instead\n' "$fan_control" >&2
            fi
          else
            printf 'reload failed; reboot instead\n' >&2
          fi
          ;;
      esac
    fi
  else
    printf 'thinkpad_acpi fan_control is enabled\n'
  fi
}

show_status() {
  local dest fan_control tmux_conf
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

  tmux_conf="$HOME/.config/tmux/tmux.conf"
  if [[ -L $tmux_conf ]]; then
    printf '%-52s (symlink to another repo: %s)\n' "$tmux_conf" "$(readlink "$tmux_conf")"
  elif grep -qxF -- "source-file ~/.config/tmux/oma-malleations.conf" "$tmux_conf" 2>/dev/null; then
    printf '%-52s (Omarchy default + oma-malleations.conf)\n' "$tmux_conf"
  elif [[ -e $tmux_conf ]]; then
    printf '%-52s (real file, does not source the snippet)\n' "$tmux_conf"
  else
    printf '%-52s (missing)\n' "$tmux_conf"
  fi

  printf '\nfancontrol (root-owned copies, not symlinks):\n'
  show_installed "$repo/bin/fancontrol" "/usr/local/bin/fancontrol"
  show_installed "$repo/bin/fancontrol-root" "/usr/local/lib/oma-malleations/fancontrol-root"
  show_installed "$repo/system/systemd/fancontrol-guard.service" "/etc/systemd/system/fancontrol-guard.service"
  show_installed "$repo/system/modprobe.d/oma-malleations-fancontrol.conf" "/etc/modprobe.d/oma-malleations-fancontrol.conf"
  if sudo -n -l 2>/dev/null | grep -q '/usr/local/lib/oma-malleations/fancontrol-root'; then
    printf '%-52s (NOPASSWD rule active)\n' "/etc/sudoers.d/oma-malleations-fancontrol"
  else
    printf '%-52s (not detected; inspect with "sudo -n -l")\n' "/etc/sudoers.d/oma-malleations-fancontrol"
  fi
  printf '%-52s %s\n' "fancontrol resolves to" "$(command -v fancontrol 2>/dev/null || printf 'not found')"
  if [[ -r /sys/module/thinkpad_acpi/parameters/fan_control ]]; then
    fan_control=$(</sys/module/thinkpad_acpi/parameters/fan_control)
    printf '%-52s fan_control=%s\n' "thinkpad_acpi" "$fan_control"
  else
    printf '%-52s (not loaded)\n' "thinkpad_acpi"
  fi
  printf '%-52s %s\n' "fancontrol-guard.service" "$(systemctl is-active fancontrol-guard.service 2>/dev/null || true)"

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

if ((user_only)); then
  fan_system_ok=0
  printf '\nskipping the root-owned fan-control pieces (--user-only)\n'
else
  install_fancontrol_system || {
    fan_system_ok=0
    printf '\nwarning: fan control is not fully installed; the keybindings will report the problem.\n' >&2
  }
fi

if ((!dry_run)); then
  chmod +x "$repo/bin/fluxfm" "$repo/bin/omarun" "$repo/bin/fancontrol" "$repo/bin/fancontrol-root"
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
  if ((!fan_system_ok)); then
    printf '\nDone (user files only). Fan control is not fully installed; run ./install.sh without --user-only.\n'
  else
    printf '\nDone. SUPER + R runs, SUPER + SHIFT + R runs again, tmux is on CTRL + A.\n'
    printf 'Fan: SUPER + CTRL + ALT + EQUAL faster, SUPER + CTRL + ALT + MINUS slower, SUPER + CTRL + ALT + 0 auto.\n'
  fi
fi
