#!/usr/bin/env bash
# .LH_SOURCED: {{ lib/basic.sh }}
# https://stackoverflow.com/a/2705678
escape_sed_expr()  { sed -e 's/[]\/$*.^[]/\\&/g' <<< "${1-$(cat)}"; }
escape_sed_repl()  { sed -e 's/[\/&]/\\&/g' <<< "${1-$(cat)}"; }

escape_single_quotes()  { declare str="${1-$(cat)}"; cat <<< "${str//\'/\'\\\'\'}"; }
escape_double_quotes()  { declare str="${1-$(cat)}"; cat <<< "${str//\"/\"\\\"\"}"; }
# .LH_SOURCED: {{/ lib/basic.sh }}
# .LH_SOURCED: {{ config/tmux/tmux-base.ignore.sh }}
# .LH_SOURCED: {{ lib/system.sh }}

is_user_root() { [[ "$(id -u)" -eq 0 ]]; }
is_user_privileged() { is_user_root && [[ -n "${SUDO_USER}" ]]; }

privileged_user_home() { eval echo ~"${SUDO_USER}"; }

alias_home_in_path() {
  declare path="${1}" home="${2:-${HOME}}"
  declare home_rex; home_rex="$(escape_sed_expr "${home%/}")"

  # shellcheck disable=SC2001
  sed -e 's/^'"${home_rex}"'/~/' <<< "${path}"
}
# .LH_SOURCED: {{/ lib/system.sh }}
# .LH_SOURCED: {{ lib/text.sh }}
# shellcheck disable=SC2001
# shellcheck disable=SC2120
text_ltrim() { sed -e 's/^\s\+//' <<< "${1-$(cat)}"; }
text_rtrim() { sed -e 's/\s\+$//' <<< "${1-$(cat)}"; }
text_trim() { text_ltrim <<< "${1-$(cat)}" | text_rtrim; }
text_rmblank() { grep -v '^\s*$' <<< "${1-$(cat)}"; return 0; }
text_nice() { text_trim <<< "${1-$(cat)}" | text_rmblank | sed -e 's/^,//'; }
# .LH_SOURCED: {{/ lib/text.sh }}
# .LH_SOURCED: {{ base.ignore.sh }}
# USAGE:
#   declare -A LH_DEFAULTS=([PARAM_NAME]=VALUE)
#   lh_params_apply_defaults
# If LH_PARAMS[PARAM_NAME] is not set, it gets the value from LH_DEFAULTS
lh_params_apply_defaults() {
  [[ "$(declare -p LH_PARAMS 2>/dev/null)" == "declare -A"* ]] || declare -Ag LH_PARAMS
  [[ "$(declare -p LH_DEFAULTS 2>/dev/null)" == "declare -A"* ]] || declare -Ag LH_DEFAULTS

  declare p_name; for p_name in "${!LH_DEFAULTS[@]}"; do
    [[ -n "${LH_PARAMS[${p_name}]+x}" ]] || LH_PARAMS["${p_name}"]="${LH_DEFAULTS[${p_name}]}"
  done
}

lh_params_reset() {
  unset LH_PARAMS LH_PARAMS_NOVAL
  declare -Ag LH_PARAMS
  declare -ag LH_PARAMS_NOVAL
}

# USAGE:
#   lh_param_set PARAM_NAME VALUE
# Produces global LH_PARAMS[PARAM_NAME]=VALUE.
# When VALUE is not provided returns 1 and puts PARAM_NAME to LH_PARAMS_NOVAL global array
lh_param_set() {
  declare name="${1}"

  [[ -n "${2+x}" ]] || { lh_params_noval "${name}"; return 1; }

  [[ "$(declare -p LH_PARAMS 2>/dev/null)" == "declare -A"* ]] || declare -Ag LH_PARAMS
  LH_PARAMS["${name}"]="${2}"
}

lh_params_noval() {
  [[ "$(declare -p LH_PARAMS_NOVAL 2>/dev/null)" == "declare -a"* ]] || {
    unset LH_PARAMS_NOVAL
    declare -ag LH_PARAMS_NOVAL
  }

  [[ ${#} -gt 0 ]] && { LH_PARAMS_NOVAL+=("${@}"); return; }

  [[ ${#LH_PARAMS_NOVAL[@]} -gt 0 ]] || return 1
  printf -- '%s\n' "${LH_PARAMS_NOVAL[@]}"
}

# shellcheck disable=SC2120
lh_params_unsupported() {
  [[ "$(declare -p LH_PARAMS_UNSUPPORTED 2>/dev/null)" == "declare -a"* ]] || {
    unset LH_PARAMS_UNSUPPORTED
    declare -ag LH_PARAMS_UNSUPPORTED
  }

  [[ ${#} -gt 0 ]] && { LH_PARAMS_UNSUPPORTED+=("${@}"); return; }

  [[ ${#LH_PARAMS_UNSUPPORTED[@]} -gt 0 ]] || return 1
  printf -- '%s\n' "${LH_PARAMS_UNSUPPORTED[@]}"
}

lh_params_flush_invalid() {
  declare -i rc=1

  # shellcheck disable=SC2119
  declare unsup; unsup="$(lh_params_unsupported)" && {
    echo "Unsupported params:"
    printf -- '%s\n' "${unsup}" | sed -e 's/^/* /'
    rc=0
  }

  # shellcheck disable=SC2119
  declare noval; noval="$(lh_params_noval)" && {
    echo "Values required for:"
    printf -- '%s\n' "${noval}" | sed -e 's/^/* /'
    rc=0
  }

  return ${rc}
}
# .LH_SOURCED: {{/ base.ignore.sh }}

config_tmux_base() {
  declare SELF="${FUNCNAME[0]}"

  HOME_DIR="${HOME}"
  INSTALLED_FILES_UMASK=0077
  CONFD_ALIAS=""

  if is_user_privileged; then
    HOME_DIR="$(privileged_user_home)"
    INSTALLED_FILES_UMASK=0022
  fi

  # shellcheck disable=SC2034
  declare -A LH_DEFAULTS=(
    [CONFD]="${HOME_DIR}/.tmux"
  )

  declare -a args
  declare endopts=false
  declare param
  while [[ ${#} -gt 0 ]]; do
    ${endopts} && param='*' || param="${1}"

    case "${param}" in
      --            ) endopts=true ;;
      -\?|-h|--help ) print_help; exit ;;
      --usage       ) print_help_usage | text_nice; exit ;;
      -*            ) lh_params_unsupported "${1}" ;;
      *             ) args+=("${1}") ;;
    esac

    shift
  done

  [[ ${#args[@]} -gt 0 ]] && lh_param_set CONFD "${args[0]}"
  [[ ${#args[@]} -lt 2 ]] || lh_params_unsupported "${args[@]:1}"

  lh_params_apply_defaults

  lh_params_flush_invalid >&2 && {
    echo "FATAL (${SELF})" >&2
    return 1
  }

  LH_PARAMS[CONFD]="$(realpath -m -- "${LH_PARAMS[CONFD]}")"
  CONFD_ALIAS="$(alias_home_in_path "${LH_PARAMS[CONFD]}")"
}

config_tmux_create_confd_file() (
  declare dest="${1}"
  declare conf="${2}"

  set -x
  umask -- "${INSTALLED_FILES_UMASK}"
  mkdir -p -- "${LH_PARAMS[CONFD]}" \
  && tee -- "${dest}" <<< "${conf}" >/dev/null
)

config_tmux_append_source_line() (
  declare source_line="${1}"
  declare -a tee_cmd_prefix=(tee -a --)
  declare -a tee_cmd=("${tee_cmd_prefix[@]}" "${HOME_DIR}/.tmux.conf")

  if is_user_privileged; then
    declare home; home="$(escape_single_quotes "${HOME_DIR}")"
    tee_cmd=(su -l "${SUDO_USER}" -c "umask 0077; ${tee_cmd_prefix[*]} '${home}/.tmux.conf'")
  fi

  grep -qFx -- "${source_line}" "${HOME_DIR}/.tmux.conf" 2>/dev/null \
  || printf -- '%s\n' "${source_line}" | (
    set -x; umask 0077; "${tee_cmd[@]}" >/dev/null
  )
)
# .LH_SOURCED: {{/ config/tmux/tmux-base.ignore.sh }}

# If not a file, default to ssh-gen.sh script name
declare THE_SCRIPT=tmux-plugins.sh
grep -q -m 1 -- '.' "${0}" 2>/dev/null && THE_SCRIPT="$(basename -- "${0}")"

CONFIG="$(cat <<'HEREDOC_END'
# plugins.conf

set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-sidebar'

# set-environment -g TMUX_PLUGIN_MANAGER_PATH '~/.tmux/plugins'
# run -b '~/.tmux/plugins/tpm/tpm'
HEREDOC_END
)"

CONFIG_APPENDIX="$(cat <<'HEREDOC_END'
# appendix.conf

set-environment -g TMUX_PLUGIN_MANAGER_PATH '~/.tmux/plugins'
run -b '~/.tmux/plugins/tpm/tpm'
HEREDOC_END
)"

print_help_usage() { echo "
  ${THE_SCRIPT} [--] [CONFD=\"\${HOME}/.tmux\"]
"; }

print_help() { text_nice "
  Generate plugins tmux configuration preset and source it to ~/.tmux.conf file.
  tmux and git are required to be installed for this script. The configs are with
  the following content:
 ,
  \`\`\`
  ${CONFIG}
  \`\`\`
 ,
  \`\`\`
  ${CONFIG_APPENDIX}
  \`\`\`
 ,
  USAGE:
  =====
  $(print_help_usage)
 ,
  PARAMS:
  ======
  CONFD   Confd directory to store tmux custom configurations
 ,
  DEMO:
  ====
  # Generate with all defaults to ~/.tmux/{appendix,plugins}.conf
  ${THE_SCRIPT}
 ,
  # Generate to /etc/tmux/{appendix,plugins}.conf. Requires sudo for non-root user
  sudo ${THE_SCRIPT} /etc/tmux
"; }

config_tmux_base "${@}" || exit

SOURCE_LINE="source-file ${CONFD_ALIAS}/plugins.conf"

config_tmux_create_confd_file "${LH_PARAMS[CONFD]}/plugins.conf" "${CONFIG}" \
&& config_tmux_append_source_line "${SOURCE_LINE}"

(
  declare -a mdkir_cmd_prefix=(mkdir -p --)
  declare -a mkdir_cmd=("${mdkir_cmd_prefix[@]}" ~/.tmux/plugins)
  is_user_privileged && {
    mkdir_cmd=(su -l "${SUDO_USER}" -c "umask 0077; ${mdkir_cmd_prefix[*]} ~/.tmux/plugins")
  }

  set -x
  rm -rf -- "${HOME_DIR}/.tmux/plugins/tpm"
  umask 0077
  "${mkdir_cmd[@]}"
)

SOURCE_LINE="source-file ${CONFD_ALIAS}/appendix.conf"
SOURCE_LINE_REX="$(escape_sed_expr "${SOURCE_LINE}")"

(
  declare -a clone_cmd_prefix=(git clone https://github.com/tmux-plugins/tpm --)
  declare -a clone_cmd=("${clone_cmd_prefix[@]}" ~/.tmux/plugins/tpm)
  is_user_privileged && {
    clone_cmd=(su -l "${SUDO_USER}" -c "umask 0077; ${clone_cmd_prefix[*]} ~/.tmux/plugins/tpm")
  }

  set -x
  umask 0077
  "${clone_cmd[@]}"
) && (
  set -x
  umask -- "${INSTALLED_FILES_UMASK}"
  tee -- "${LH_PARAMS[CONFD]}/appendix.conf" <<< "${CONFIG_APPENDIX}" >/dev/null \
  && sed -i -e '/^'"${SOURCE_LINE_REX}"'$/d' -- "${HOME_DIR}/.tmux.conf"
) && (
  declare -a reload_src_cmd=(true)
  [[ -n "${TMUX_PANE}" ]] && reload_src_cmd=(tmux source ~/.tmux.conf)
  declare -a install_cmd=(~/.tmux/plugins/tpm/scripts/install_plugins.sh)
  is_user_privileged && {
    install_cmd=(su -l "${SUDO_USER}" -c "umask 0077; ~/.tmux/plugins/tpm/scripts/install_plugins.sh")
  }

  set -x
  umask 0077
  tee -a "${HOME_DIR}/.tmux.conf" <<< "${SOURCE_LINE}" >/dev/null \
  && "${reload_src_cmd[@]}" \
  && "${install_cmd[@]}"
)
