#!/usr/bin/env bash

set -euo pipefail

readonly PROJECT_NAME="pop-os-rice"
readonly BACKUP_ROOT_DEFAULT="/var/backups/${PROJECT_NAME}"
readonly COSMIC_CONFIG_ROOT="${HOME}/.config/cosmic"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

note() {
  printf '%s\n' "$*"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

project_root() {
  local script_dir
  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  dirname -- "$script_dir"
}
