#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

ROOT="$(project_root)"
VENDOR="${ROOT}/vendor"
PROFILES="${ROOT}/profiles"

usage() {
  cat <<'EOF'
Usage: import-rices.sh

Regenerate profiles/<slug>/ from every vendor/cosmic-<slug>-theme submodule.
Copies the COSMIC layer only: the desktop palette, fonts and window buttons
(theme), the icon theme (icons), and COSMIC Terminal settings and color
schemes (terminal). Generated profiles carry a SOURCE file; profiles without
one are never replaced. Generated profiles whose submodule is gone are removed.
EOF
}

case "${1:-}" in
  "") ;;
  -h|--help) usage; exit 0 ;;
  *) die "unknown argument: $1" ;;
esac

# Reads `key = "value"` from rice.toml.
rice_value() {
  local value
  value="$(sed -n "s/^$1 = \"\(.*\)\"\$/\1/p" "$2")"
  [[ -n "$value" ]] || die "$2 has no $1"
  printf '%s\n' "$value"
}

stage=""
trap '[[ -n "$stage" ]] && rm -rf -- "$stage"' EXIT

import_rice() {
  local repo="$1"
  local name slug mode other dest setting relative target
  name="$(basename -- "$repo")"
  slug="${name#cosmic-}"
  slug="${slug%-theme}"
  dest="${PROFILES}/${slug}"

  [[ -f "${repo}/rice.toml" ]] \
    || die "submodule not checked out: ${repo} (run: git submodule update --init)"
  [[ ! -e "$dest" || -f "${dest}/SOURCE" ]] \
    || die "refusing to replace hand-made profile: ${dest}"

  mode="$(rice_value mode "${repo}/rice.toml")"
  case "$mode" in
    dark) other=light ;;
    light) other=dark ;;
    *) die "${repo}/rice.toml: invalid mode: ${mode}" ;;
  esac

  stage="$(mktemp -d "${PROFILES}/.${slug}.XXXXXX")"
  chmod 0755 "$stage"

  install -D -m 0644 "${repo}/cosmic/$(rice_value theme "${repo}/rice.toml")" \
    "${stage}/theme/${slug}.ron"

  while IFS= read -r -d '' setting; do
    relative="${setting#"${repo}/cosmic/config/"}"
    case "$relative" in
      com.system76.CosmicTk/v1/icon_theme)
        target=icons
        tr -d '"\n' <"$setting" >"${stage}/icon-theme.tmp"
        ;;
      com.system76.CosmicTk/v1/*) target=theme ;;
      com.system76.CosmicTerm/v1/syntax_theme_"${other}") continue ;;
      com.system76.CosmicTerm/v1/*) target=terminal ;;
      *) die "unmapped upstream setting: ${setting}" ;;
    esac
    install -D -m 0644 "$setting" "${stage}/${target}/config/${relative}"
  done < <(find "${repo}/cosmic/config" -type f -print0 | sort -z)

  [[ -s "${stage}/icon-theme.tmp" ]] || die "${repo} sets no icon theme"
  printf '%s\n' "$(<"${stage}/icon-theme.tmp")" >"${stage}/icons/icon-theme"
  rm -f -- "${stage}/icon-theme.tmp"

  # Profiles such as sakura-night force the terminal to Dark; follow the
  # desktop mode instead so syntax_theme_<mode> takes effect.
  setting="${stage}/terminal/config/com.system76.CosmicTerm/v1/app_theme"
  [[ -e "$setting" ]] || printf 'System\n' >"$setting"

  install -m 0644 -t "${stage}/terminal" "${repo}"/cosmic-term/*.ron
  install -m 0644 "${repo}/LICENSE" "${stage}/LICENSE"
  printf 'name=%s\nmode=%s\npair=%s\nupstream=%s\ncommit=%s\n' \
    "$(rice_value name "${repo}/rice.toml")" "$mode" \
    "$(rice_value pair "${repo}/rice.toml")" \
    "$(git -C "$repo" remote get-url origin)" \
    "$(git -C "$repo" rev-parse HEAD)" >"${stage}/SOURCE"

  rm -rf -- "$dest"
  mv -- "$stage" "$dest"
  stage=""
  note "imported ${slug} (${mode})"
}

declare -a repos=()
for repo in "${VENDOR}"/cosmic-*-theme; do
  [[ -d "$repo" ]] && repos+=("$repo")
done
((${#repos[@]} > 0)) || die "no submodules in ${VENDOR}"

for repo in "${repos[@]}"; do
  import_rice "$repo"
done

for source in "${PROFILES}"/*/SOURCE; do
  [[ -f "$source" ]] || continue
  slug="$(basename -- "$(dirname -- "$source")")"
  if [[ ! -d "${VENDOR}/cosmic-${slug}-theme" ]]; then
    rm -rf -- "${PROFILES:?}/${slug}"
    note "removed ${slug}: its submodule is gone"
  fi
done

note "Imported ${#repos[@]} rices into ${PROFILES}."
