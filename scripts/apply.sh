#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

ROOT="$(project_root)"
mode=""
category="all"

usage() {
  cat <<'EOF'
Usage: apply.sh (--dry-run | --apply) [--category panel|terminal|icons|all]

Preview or apply stable COSMIC configuration files. A verified user-config
backup is created before every real apply operation.
EOF
}
apply_icons() {
  local icon_theme_file="${ROOT}/profiles/cosmic/icons/icon-theme"
  local icon_theme
  require_command gsettings

  [[ -f "$icon_theme_file" ]] || die "icon profile missing: $icon_theme_file"
  icon_theme="$(<"$icon_theme_file")"
  [[ -d "/usr/share/icons/${icon_theme}" ||
     -d "${HOME}/.local/share/icons/${icon_theme}" ||
     -d "${HOME}/.icons/${icon_theme}" ]] \
    || die "icon theme is not installed: $icon_theme"

  if [[ "$mode" == "dry-run" ]]; then
    printf 'would set org.gnome.desktop.interface icon-theme -> %s\n' \
      "$icon_theme"
  else
    gsettings set org.gnome.desktop.interface icon-theme "$icon_theme"
  fi
}

restart_panel() {
  local old_pid new_pid attempt

  old_pid="$(pgrep -xo cosmic-panel || true)"
  [[ -n "$old_pid" ]] || {
    note "COSMIC panel is not running; log out and back in to load the profile."
    return
  }

  kill -TERM "$old_pid"
  for attempt in {1..30}; do
    sleep 0.2
    new_pid="$(pgrep -xo cosmic-panel || true)"
    if [[ -n "$new_pid" && "$new_pid" != "$old_pid" ]]; then
      note "COSMIC panel restarted: ${old_pid} -> ${new_pid}"
      return
    fi
  done
  note "COSMIC panel did not restart automatically; log out and back in."
}

while (($#)); do
  case "$1" in
    --dry-run)
      mode="dry-run"
      shift
      ;;
    --apply)
      mode="apply"
      shift
      ;;
    --category)
      (($# >= 2)) || die "--category requires a value"
      category="$2"
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

[[ "$mode" == "dry-run" || "$mode" == "apply" ]] \
  || die "choose exactly one of --dry-run or --apply"
[[ "$category" == "panel" || "$category" == "terminal" ||
   "$category" == "icons" ||
   "$category" == "all" ]] || die "invalid category: $category"

declare -a categories=()
if [[ "$category" == "all" ]]; then
  categories=(panel terminal icons)
else
  categories=("$category")
fi

copy_profile() {
  local current="$1"
  local source_root="${ROOT}/profiles/cosmic/${current}/config"
  local relative destination destination_dir temporary

  [[ -d "$source_root" ]] || die "profile directory missing: $source_root"

  while IFS= read -r -d '' source; do
    relative="${source#${source_root}/}"
    destination="${COSMIC_CONFIG_ROOT}/${relative}"
    if [[ "$mode" == "dry-run" ]]; then
      printf 'would install %s -> %s\n' "$source" "$destination"
    else
      destination_dir="$(dirname -- "$destination")"
      mkdir -p "$destination_dir"
      temporary="$(mktemp "${destination}.tmp.XXXXXX")"
      install -m 0644 "$source" "$temporary"
      mv -f "$temporary" "$destination"
    fi
  done < <(find "$source_root" -type f -print0 | sort -z)
}

if [[ "$mode" == "apply" ]]; then
  "${SCRIPT_DIR}/backup.sh" --label "pre-apply-${category}"
fi

for current in "${categories[@]}"; do
  if [[ "$current" == "icons" ]]; then
    apply_icons
  else
    copy_profile "$current"
  fi
done

if [[ "$mode" == "dry-run" ]]; then
  note "Dry run complete; no settings changed."
else
  if [[ " ${categories[*]} " == *" panel "* ]]; then
    restart_panel
  fi
  note "Profile applied. Log out and back in if COSMIC does not reload it."
  note "Theme imports remain manual; see README.md."
fi
