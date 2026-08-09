#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

usage() {
  printf 'Usage: %s [--identity-only] HERMES_ROOT\n' "${0##*/}"
}

identity_only=false
if [[ ${1:-} == "--identity-only" ]]; then
  identity_only=true
  shift
fi
if [[ $# -ne 1 || $1 == "-h" || $1 == "--help" ]]; then
  usage
  [[ $# -eq 1 ]] && exit 0
  exit 2
fi
if [[ ! -t 0 ]]; then
  die "setup requires an interactive terminal; use install/status scripts for automation"
fi

load_compatibility
resolve_hermes_root "$1"
verify_hermes_version

target_sha="$(sha256_file "$TARGET_FILE")"
if [[ "$target_sha" != "$PRISTINE_SHA256" && "$target_sha" != "$PATCHED_SHA256" ]]; then
  die "target has unknown local modifications; setup will not overwrite it"
fi

printf '\nHermes Honcho Attribution Guard setup / 设置向导\n'
"$SCRIPT_DIR/status.sh" "$HERMES_ROOT"

if [[ "$identity_only" == false ]]; then
  if [[ "$target_sha" == "$PRISTINE_SHA256" ]]; then
    printf '\nInstall the attribution patch now? / 现在安装身份归属补丁？ [Y/n] '
    IFS= read -r answer
    case "${answer:-y}" in
      y|Y|yes|YES|是)
        "$SCRIPT_DIR/install.sh" "$HERMES_ROOT"
        ;;
      *)
        info "setup stopped without changes / 设置已停止，未进行修改"
        exit 0
        ;;
    esac
  else
    verify_backup
    info "patch already installed / 补丁已经安装"
  fi
else
  [[ "$target_sha" == "$PATCHED_SHA256" ]] || {
    die "install the patch before editing identity aliases"
  }
  verify_backup
fi

profile_exists=false
if python3 "$SCRIPT_DIR/identity.py" exists "$HERMES_ROOT"; then
  profile_exists=true
  printf '\nCurrent identity profile / 当前身份档案：\n'
  python3 "$SCRIPT_DIR/identity.py" show "$HERMES_ROOT"
  printf '\nUpdate these identity aliases? / 是否修改这些身份称呼？ [y/N] '
else
  printf '\nConfigure optional identity aliases? / 是否配置可选身份称呼？ [y/N] '
fi
IFS= read -r configure_answer
case "${configure_answer:-n}" in
  y|Y|yes|YES|是)
    ;;
  *)
    if [[ "$profile_exists" == true ]]; then
      info "existing identity profile kept / 已保留现有身份档案"
    else
      info "identity aliases skipped / 已跳过身份称呼配置"
    fi
    printf '\nRestart Hermes with your existing service manager when convenient.\n'
    printf '请在方便时使用原有服务管理方式重启 Hermes。\n'
    exit 0
    ;;
esac

printf '\nThis v0.1 alias profile supports one human user per Hermes instance.\n'
printf 'v0.1 身份称呼档案仅支持每个 Hermes 实例对应一位人类用户。\n'
printf 'Is this a single-user Hermes instance? / 这是单用户 Hermes 实例吗？ [y/N] '
IFS= read -r single_user_answer
case "${single_user_answer:-n}" in
  y|Y|yes|YES|是)
    ;;
  *)
    info "identity aliases skipped for multi-user safety / 为避免多用户混淆，已跳过身份称呼"
    exit 0
    ;;
esac

printf '\nPrivacy notice: aliases are personal data. The profile file stays local,\n'
printf 'but its alias values are sent as structured metadata to your configured Honcho backend.\n'
printf '隐私提示：称呼属于个人信息。档案文件保留在本机，但称呼值会作为结构化 metadata\n'
printf '发送到你已经配置的 Honcho 后端。\n'
printf 'Continue with identity aliases? / 是否继续配置身份称呼？ [y/N] '
IFS= read -r privacy_answer
case "${privacy_answer:-n}" in
  y|Y|yes|YES|是)
    ;;
  *)
    info "identity profile not changed / 身份档案未修改"
    exit 0
    ;;
esac

user_primary=""
while [[ -z "${user_primary//[[:space:]]/}" ]]; do
  printf 'Your primary name / 你的主要称呼： '
  IFS= read -r user_primary
done
printf 'Other names for you, comma-separated / 你的其他称呼，逗号分隔： '
IFS= read -r user_aliases
printf 'Assistant primary name, optional / 助手主要称呼，可留空： '
IFS= read -r assistant_primary
printf 'Other assistant names, comma-separated / 助手其他称呼，逗号分隔： '
IFS= read -r assistant_aliases

printf '\nUser / 用户：%s\n' "$user_primary"
printf 'User aliases / 用户别名：%s\n' "${user_aliases:-<none / 无>}"
printf 'Assistant / 助手：%s\n' "${assistant_primary:-<none / 无>}"
printf 'Assistant aliases / 助手别名：%s\n' "${assistant_aliases:-<none / 无>}"
printf 'Save this private local profile? / 保存这份本机私有身份档案？ [Y/n] '
IFS= read -r save_answer
case "${save_answer:-y}" in
  y|Y|yes|YES|是)
    printf '%s\n%s\n%s\n%s\n' \
      "$user_primary" \
      "$user_aliases" \
      "$assistant_primary" \
      "$assistant_aliases" \
      | python3 "$SCRIPT_DIR/identity.py" write "$HERMES_ROOT"
    ;;
  *)
    info "identity profile not changed / 身份档案未修改"
    ;;
esac

printf '\nSetup complete / 设置完成。\n'
printf 'Peer IDs and message roles remain authoritative; aliases are hints only.\n'
printf 'Peer ID 与消息角色始终优先，称呼只作为理解提示。\n'
printf 'Restart Hermes with your existing service manager to load the changes.\n'
printf '请使用原有服务管理方式重启 Hermes 以加载更改。\n'
