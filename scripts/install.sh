#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

usage() {
  printf 'Usage: %s HERMES_ROOT\n' "${0##*/}"
}

if [[ $# -ne 1 || $1 == "-h" || $1 == "--help" ]]; then
  usage
  [[ $# -eq 1 ]] && exit 0
  exit 2
fi

require_command mktemp
load_compatibility
resolve_hermes_root "$1"
verify_hermes_version

current_sha="$(sha256_file "$TARGET_FILE")"
if [[ "$current_sha" == "$PATCHED_SHA256" ]]; then
  verify_backup
  info "already installed: $PACKAGE_VERSION ($RELEASE_TAG)"
  exit 0
fi
if [[ "$current_sha" != "$PRISTINE_SHA256" ]]; then
  die "target SHA256 is neither the supported pristine nor patched state; refusing to modify it"
fi

if [[ -e "$BACKUP_FILE" ]]; then
  verify_backup
fi

stage_root="$(mktemp -d "${TMPDIR:-/tmp}/honcho-attribution-install.XXXXXX")"
target_tmp=""
cleanup() {
  case "$stage_root" in
    "${TMPDIR:-/tmp}"/honcho-attribution-install.*)
      rm -rf -- "$stage_root"
      ;;
    *)
      printf 'warning: refusing to remove unexpected temporary path: %s\n' "$stage_root" >&2
      ;;
  esac
  if [[ -n "$target_tmp" && -e "$target_tmp" ]]; then
    rm -f -- "$target_tmp"
  fi
}
trap cleanup EXIT

stage_target="$stage_root/$TARGET_REL"
mkdir -p -- "$(dirname -- "$stage_target")"
cp -p -- "$TARGET_FILE" "$stage_target"
apply_compatibility_patch "$stage_root"

stage_sha="$(sha256_file "$stage_target")"
[[ "$stage_sha" == "$PATCHED_SHA256" ]] || die "patched output SHA256 mismatch"

if [[ ! -e "$BACKUP_FILE" ]]; then
  mkdir -p -- "$(dirname -- "$BACKUP_FILE")"
  cp -p -- "$TARGET_FILE" "$BACKUP_FILE"
fi
verify_backup

target_tmp="${TARGET_FILE}.honcho-attribution-guard.$$"
cp -p -- "$stage_target" "$target_tmp"
[[ "$(sha256_file "$target_tmp")" == "$PATCHED_SHA256" ]] || die "temporary install SHA256 mismatch"
mv -f -- "$target_tmp" "$TARGET_FILE"
target_tmp=""

[[ "$(sha256_file "$TARGET_FILE")" == "$PATCHED_SHA256" ]] || die "installed target SHA256 mismatch"
info "installed $PACKAGE_VERSION for $RELEASE_TAG"
info "backup: $BACKUP_FILE"
info "no service was restarted"
