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
if [[ "$current_sha" == "$PRISTINE_SHA256" ]]; then
  info "already rolled back: $RELEASE_TAG"
  exit 0
fi
if [[ "$current_sha" != "$PATCHED_SHA256" ]]; then
  die "target SHA256 is neither the supported patched nor pristine state; refusing to modify it"
fi

verify_backup

target_tmp="${TARGET_FILE}.honcho-attribution-guard.$$"
cleanup() {
  if [[ -e "$target_tmp" ]]; then
    rm -f -- "$target_tmp"
  fi
}
trap cleanup EXIT

cp -p -- "$BACKUP_FILE" "$target_tmp"
[[ "$(sha256_file "$target_tmp")" == "$PRISTINE_SHA256" ]] || die "temporary rollback SHA256 mismatch"
mv -f -- "$target_tmp" "$TARGET_FILE"

[[ "$(sha256_file "$TARGET_FILE")" == "$PRISTINE_SHA256" ]] || die "rolled-back target SHA256 mismatch"
info "rolled back $PACKAGE_VERSION for $RELEASE_TAG"
info "verified backup retained at: $BACKUP_FILE"
info "no service was restarted"
