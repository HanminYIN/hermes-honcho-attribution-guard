#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

require_command python3
require_command mktemp
load_compatibility

PACKAGE_NAME="$(json_get "$COMPATIBILITY_FILE" package name)"
RELEASE_ROOT="${HAG_RELEASE_DIR:-$PACKAGE_ROOT/dist}"
RELEASE_NAME="${PACKAGE_NAME}-v${PACKAGE_VERSION}"
ARCHIVE_NAME="${RELEASE_NAME}.tar.gz"

# This explicit allowlist is the release boundary. Do not replace it with a
# recursive copy: a Hermes checkout may contain a private identity profile and
# the repository may contain unrelated local audit material.
release_files=(
  .gitignore
  .github/workflows/ci.yml
  AGENTS.md
  AUDIT.md
  CONTRIBUTING.md
  CONTRIBUTING.en.md
  LICENSE
  QUICKSTART.zh-CN.md
  README.md
  README.en.md
  RELEASE_NOTES.md
  RELEASE_NOTES.en.md
  SECURITY.md
  SECURITY.en.md
  assets/readme-hero.svg
  compatibility.json
  examples/attribution.example.yaml
  honcho-guard
  patches/hermes-2026.8.31.patch
  scripts/build-release.sh
  scripts/check.sh
  scripts/identity.py
  scripts/install.sh
  scripts/lib.sh
  scripts/rollback.sh
  scripts/setup.sh
  scripts/status.sh
  tests/test_attribution_v2.py
)

for relative_path in "${release_files[@]}"; do
  case "$relative_path" in
    /*|*..*)
      die "unsafe release allowlist path: $relative_path"
      ;;
  esac
  source_path="$PACKAGE_ROOT/$relative_path"
  reject_symlink_components "$PACKAGE_ROOT" "$source_path" "release file"
  [[ -f "$source_path" && ! -L "$source_path" ]] \
    || die "release file is missing or unsafe: $relative_path"
done

mkdir -p -- "$RELEASE_ROOT"
[[ -d "$RELEASE_ROOT" && ! -L "$RELEASE_ROOT" ]] \
  || die "release output is not a safe directory: $RELEASE_ROOT"
RELEASE_ROOT="$(cd -- "$RELEASE_ROOT" && pwd -P)"

stage_root="$(mktemp -d "${TMPDIR:-/tmp}/honcho-guard-release.XXXXXX")"
cleanup() {
  case "$stage_root" in
    "${TMPDIR:-/tmp}"/honcho-guard-release.*)
      rm -rf -- "$stage_root"
      ;;
    *)
      printf 'warning: refusing to remove unexpected temporary path: %s\n' "$stage_root" >&2
      ;;
  esac
}
trap cleanup EXIT

package_stage="$stage_root/$RELEASE_NAME"
mkdir -p -- "$package_stage"
for relative_path in "${release_files[@]}"; do
  mkdir -p -- "$package_stage/$(dirname -- "$relative_path")"
  cp -p -- "$PACKAGE_ROOT/$relative_path" "$package_stage/$relative_path"
done

(
  cd -- "$package_stage"
  for relative_path in "${release_files[@]}"; do
    printf '%s  %s\n' "$(sha256_file "$relative_path")" "$relative_path"
  done | LC_ALL=C sort -k2 > MANIFEST.sha256
)

archive_stage="$stage_root/$ARCHIVE_NAME"
python3 - "$package_stage" "$archive_stage" "$RELEASE_NAME" <<'PY'
import gzip
import os
import sys
import tarfile

source_root, archive_path, archive_root = sys.argv[1:]


def normalized_info(tar: tarfile.TarFile, path: str, arcname: str) -> tarfile.TarInfo:
    info = tar.gettarinfo(path, arcname=arcname)
    info.uid = 0
    info.gid = 0
    info.uname = "root"
    info.gname = "root"
    info.mtime = 0
    if info.isdir():
        info.mode = 0o755
    elif info.isfile():
        info.mode = 0o755 if info.mode & 0o111 else 0o644
    return info


with open(archive_path, "wb") as raw:
    with gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=0) as zipped:
        with tarfile.open(fileobj=zipped, mode="w", format=tarfile.GNU_FORMAT) as tar:
            root_info = normalized_info(tar, source_root, archive_root)
            tar.addfile(root_info)
            for current_root, directories, files in os.walk(source_root):
                directories.sort()
                files.sort()
                relative_root = os.path.relpath(current_root, source_root)
                for directory in directories:
                    path = os.path.join(current_root, directory)
                    relative = os.path.normpath(os.path.join(relative_root, directory))
                    arcname = os.path.join(archive_root, relative)
                    tar.addfile(normalized_info(tar, path, arcname))
                for filename in files:
                    path = os.path.join(current_root, filename)
                    relative = os.path.normpath(os.path.join(relative_root, filename))
                    arcname = os.path.join(archive_root, relative)
                    info = normalized_info(tar, path, arcname)
                    with open(path, "rb") as handle:
                        tar.addfile(info, handle)
PY

archive_sha="$(sha256_file "$archive_stage")"
printf '%s  %s\n' "$archive_sha" "$ARCHIVE_NAME" > "$stage_root/SHA256SUMS"

mv -f -- "$archive_stage" "$RELEASE_ROOT/$ARCHIVE_NAME"
mv -f -- "$stage_root/SHA256SUMS" "$RELEASE_ROOT/SHA256SUMS"

info "release archive: $RELEASE_ROOT/$ARCHIVE_NAME"
info "archive SHA256: $archive_sha"
info "checksum file: $RELEASE_ROOT/SHA256SUMS"
info "contents manifest: $RELEASE_NAME/MANIFEST.sha256 (inside archive)"
