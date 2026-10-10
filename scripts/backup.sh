#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

backup_root="$BACKUP_ROOT_DEFAULT"
label="manual"

usage() {
  cat <<'EOF'
Usage: backup.sh [--destination DIR] [--label LABEL]

Create and verify a root-owned archive of appearance-related user settings.
This complements Timeshift, which commonly excludes home directories.
EOF
}

while (($#)); do
  case "$1" in
    --destination)
      (($# >= 2)) || die "--destination requires a value"
      backup_root="$2"
      shift 2
      ;;
    --label)
      (($# >= 2)) || die "--label requires a value"
      label="$2"
      shift 2
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

require_command dpkg-query
require_command gzip
require_command sha256sum
require_command sudo
require_command tar

safe_label="${label//[^[:alnum:]._-]/-}"
timestamp="$(date +%Y%m%d-%H%M%S)"
destination="${backup_root}/${timestamp}-${safe_label}"
staging="$(mktemp -d)"
trap 'rm -rf -- "$staging"' EXIT

declare -a candidates=(
  ".config/cosmic"
  ".config/gtk-3.0"
  ".config/gtk-4.0"
  ".config/fontconfig"
  ".config/neofetch"
  ".local/share/themes"
  ".local/share/icons"
  ".local/share/fonts"
  ".local/share/backgrounds"
  ".fonts"
  "Pictures/Wallpapers"
)
declare -a included=()

for path in "${candidates[@]}"; do
  [[ -e "${HOME}/${path}" ]] && included+=("$path")
done

((${#included[@]} > 0)) || die "no appearance configuration paths found"

printf '%s\n' "${included[@]}" >"${staging}/included-paths.txt"
dpkg-query -W -f='${binary:Package}\t${Version}\n' \
  >"${staging}/packages.tsv"
printf 'created_at=%s\nhost=%s\nuser=%s\nlabel=%s\n' \
  "$(date --iso-8601=seconds)" "$(hostname)" "$USER" "$label" \
  >"${staging}/metadata.txt"
if command -v dconf >/dev/null 2>&1; then
  dconf dump /org/gnome/desktop/interface/ \
    >"${staging}/gnome-interface.dconf"
fi

archive="${staging}/user-appearance-config.tar.gz"
tar -C "$HOME" -czf "$archive" "${included[@]}"
gzip -t "$archive"
(
  cd "$staging"
  sha256sum user-appearance-config.tar.gz >SHA256SUMS
  if [[ -f gnome-interface.dconf ]]; then
    sha256sum gnome-interface.dconf >>SHA256SUMS
  fi
)

sudo install -d -m 0700 "$destination"
sudo install -m 0600 \
  "$archive" \
  "${staging}/packages.tsv" \
  "${staging}/included-paths.txt" \
  "${staging}/metadata.txt" \
  "${staging}/SHA256SUMS" \
  "${destination}/"
if [[ -f "${staging}/gnome-interface.dconf" ]]; then
  sudo install -m 0600 "${staging}/gnome-interface.dconf" "${destination}/"
fi

sudo env --chdir="$destination" sha256sum --check SHA256SUMS
sudo gzip -t "${destination}/user-appearance-config.tar.gz"
sudo tar -tzf "${destination}/user-appearance-config.tar.gz" >/dev/null

note "Verified backup: ${destination}"
