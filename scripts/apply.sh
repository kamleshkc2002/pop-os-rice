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
Usage: apply.sh (--dry-run | --apply) [--category panel|terminal|all]

Preview or apply stable COSMIC configuration files. A verified user-config
backup is created before every real apply operation.
EOF
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
   "$category" == "all" ]] || die "invalid category: $category"

declare -a categories=()
if [[ "$category" == "all" ]]; then
  categories=(panel terminal)
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
  copy_profile "$current"
done

if [[ "$mode" == "dry-run" ]]; then
  note "Dry run complete; no settings changed."
else
  note "Profile applied. Log out and back in if COSMIC does not reload it."
  note "Theme imports remain manual; see README.md."
fi
