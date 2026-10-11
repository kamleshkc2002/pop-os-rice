#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

ROOT="$(project_root)"
mode=""
profile="sakura-night"
category="all"
readonly CATEGORIES=(theme panel applets terminal icons fetch)

usage() {
  cat <<'EOF'
Usage: apply.sh (--dry-run | --apply) [--profile NAME]
                [--category theme|panel|applets|terminal|icons|fetch|all]

Preview or apply a profile from profiles/NAME (default: sakura-night). The
"all" category applies every category the profile provides. A verified
user-config backup is created before every real apply operation.
EOF
}

install_tree() {
  local source_root="$1"
  local destination_root="$2"
  local source relative destination temporary

  while IFS= read -r -d '' source; do
    relative="${source#"${source_root}"/}"
    destination="${destination_root}/${relative}"
    if [[ "$mode" == "dry-run" ]]; then
      printf 'would install %s -> %s\n' "$source" "$destination"
    else
      mkdir -p "$(dirname -- "$destination")"
      temporary="$(mktemp "${destination}.tmp.XXXXXX")"
      install -m 0644 "$source" "$temporary"
      mv -f "$temporary" "$destination"
    fi
  done < <(find "$source_root" -type f -print0 | sort -z)
}

category_destination() {
  case "$1" in
    fetch) printf '%s\n' "${HOME}/.config/neofetch" ;;
    *) printf '%s\n' "$COSMIC_CONFIG_ROOT" ;;
  esac
}

apply_icons() {
  local icon_theme_file="${PROFILE_ROOT}/icons/icon-theme"
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

apply_theme() {
  local theme_file="${PROFILE_ROOT}/theme/${profile}.ron"
  require_command cosmic-settings

  [[ -f "$theme_file" ]] || die "COSMIC theme profile missing: $theme_file"
  if [[ "$mode" == "dry-run" ]]; then
    printf 'would import COSMIC desktop theme -> %s\n' "$theme_file"
  else
    cosmic-settings appearance import "$theme_file"
  fi
}

# Panel applets that are not installed are silently skipped by cosmic-panel.
check_panel_applets() {
  local applet data_dir found
  local -a data_dirs=()

  IFS=: read -r -a data_dirs <<<"${XDG_DATA_HOME:-${HOME}/.local/share}:${HOME}/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
  while IFS= read -r applet; do
    found=false
    for data_dir in "${data_dirs[@]}"; do
      if [[ -f "${data_dir}/applications/${applet}.desktop" ]]; then
        found=true
        break
      fi
    done
    "$found" || note "warning: panel applet not installed: ${applet}"
  done < <(find "${PROFILE_ROOT}/panel/config" -type f -name 'plugins_*' \
    -exec grep -ohE '"[^"]+"' {} + | tr -d '"' | sort -u)
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
    --profile)
      (($# >= 2)) || die "--profile requires a value"
      profile="$2"
      shift 2
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
[[ "$profile" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "invalid profile name: $profile"
PROFILE_ROOT="${ROOT}/profiles/${profile}"
[[ -d "$PROFILE_ROOT" ]] || die "profile not found: $PROFILE_ROOT"

declare -a categories=()
if [[ "$category" == "all" ]]; then
  for current in "${CATEGORIES[@]}"; do
    [[ -d "${PROFILE_ROOT}/${current}" ]] && categories+=("$current")
  done
  ((${#categories[@]} > 0)) || die "profile has no categories: $PROFILE_ROOT"
else
  [[ " ${CATEGORIES[*]} " == *" ${category} "* ]] \
    || die "invalid category: $category"
  [[ -d "${PROFILE_ROOT}/${category}" ]] \
    || die "profile ${profile} has no ${category} category"
  categories=("$category")
fi

if [[ "$mode" == "apply" ]]; then
  "${SCRIPT_DIR}/backup.sh" --label "pre-apply-${profile}-${category}"
fi

for current in "${categories[@]}"; do
  case "$current" in
    theme)
      apply_theme
      ;;
    icons)
      apply_icons
      ;;
    fetch)
      require_command neofetch
      ;;
  esac

  config_root="${PROFILE_ROOT}/${current}/config"
  if [[ -d "$config_root" ]]; then
    install_tree "$config_root" "$(category_destination "$current")"
  elif [[ "$current" != "theme" && "$current" != "icons" ]]; then
    die "profile directory missing: $config_root"
  fi

  if [[ "$current" == "panel" ]]; then
    check_panel_applets
  fi
done

if [[ "$mode" == "dry-run" ]]; then
  note "Dry run complete; no settings changed."
else
  if [[ " ${categories[*]} " == *" panel "* ||
        " ${categories[*]} " == *" applets "* ||
        " ${categories[*]} " == *" theme "* ]]; then
    restart_panel
  fi
  note "Profile applied. Log out and back in if COSMIC does not reload it."
  if [[ " ${categories[*]} " == *" terminal "* ]] &&
     compgen -G "${PROFILE_ROOT}/terminal/*.ron" >/dev/null; then
    note "The COSMIC Terminal color-scheme import remains manual; see README.md."
  fi
fi
