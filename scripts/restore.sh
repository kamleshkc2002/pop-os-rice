#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

archive_dir=""
mode=""

usage() {
  cat <<'EOF'
Usage:
  restore.sh --list
  restore.sh --archive DIR --dry-run
  restore.sh --archive DIR --restore

Restores only the appearance-related user paths captured by backup.sh.
--restore creates a new checkpoint before extracting the selected archive.
EOF
}

while (($#)); do
  case "$1" in
    --archive)
      (($# >= 2)) || die "--archive requires a value"
      archive_dir="$2"
      shift 2
      ;;
    --list)
      mode="list"
      shift
      ;;
    --dry-run)
      mode="dry-run"
      shift
      ;;
    --restore)
      mode="restore"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

if [[ "$mode" == "list" ]]; then
  if [[ ! -d "$BACKUP_ROOT_DEFAULT" ]]; then
    note "No backup directory found at ${BACKUP_ROOT_DEFAULT}"
    exit 0
  fi
  sudo find "$BACKUP_ROOT_DEFAULT" -mindepth 1 -maxdepth 1 -type d \
    -printf '%f\n' | sort
  exit 0
fi

[[ -n "$archive_dir" ]] || die "--archive DIR is required"
[[ "$mode" == "dry-run" || "$mode" == "restore" ]] \
  || die "choose exactly one of --dry-run or --restore"

archive_dir="$(realpath -- "$archive_dir")"
backup_root="$(realpath -- "$BACKUP_ROOT_DEFAULT")"
[[ "$archive_dir" == "${backup_root}/"* ]] \
  || die "archive must be inside ${backup_root}"

archive="${archive_dir}/user-appearance-config.tar.gz"
sudo test -f "$archive" || die "archive not found: $archive"
sudo test -f "${archive_dir}/SHA256SUMS" \
  || die "checksum manifest not found"

sudo env --chdir="$archive_dir" sha256sum --check SHA256SUMS
sudo gzip -t "$archive"

if [[ "$mode" == "dry-run" ]]; then
  note "Verified archive. Paths that would be restored:"
  sudo tar -tzf "$archive"
  exit 0
fi

"${SCRIPT_DIR}/backup.sh" --label pre-restore
note "Restoring files into ${HOME}"
sudo tar -xzf "$archive" -C "$HOME" --same-owner
sudo chown -R "${USER}:$(id -gn)" \
  "${HOME}/.config/cosmic" \
  "${HOME}/.config/gtk-3.0" \
  "${HOME}/.config/gtk-4.0"
note "Restore complete. Log out and back in to reload COSMIC settings."
