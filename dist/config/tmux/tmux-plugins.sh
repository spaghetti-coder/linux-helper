#!/usr/bin/env bash

config_tmux_plugins() (
  { # Service vars

    # If not a file, default to ssh-gen.sh script name
    declare THE_SCRIPT=tmux-plugins.sh
    grep -q -m 1 -- '.' "${0}" 2>/dev/null && THE_SCRIPT="$(basename -- "${0}")"
  }

  declare CONFIG; CONFIG="$(text_nice "
    # plugins.conf
    
    set -g @plugin 'tmux-plugins/tpm'
    set -g @plugin 'tmux-plugins/tmux-sensible'
    set -g @plugin 'tmux-plugins/tmux-resurrect'
    set -g @plugin 'tmux-plugins/tmux-sidebar'
    
    # set-environment -g TMUX_PLUGIN_MANAGER_PATH '~/.tmux/plugins'
    # run -b '~/.tmux/plugins/tpm/tpm'
  ")"
  declare CONFIG_APPENDIX; CONFIG_APPENDIX="$(text_nice "
    # appendix.conf
    
    set-environment -g TMUX_PLUGIN_MANAGER_PATH '~/.tmux/plugins'
    run -b '~/.tmux/plugins/tpm/tpm'
  ")"

  # shellcheck disable=SC2317
  print_usage() { echo "
    ${THE_SCRIPT} [--] [CONFD=\"$(lh_params default-string CONFD)\"]
  "; }

  # shellcheck disable=SC2317
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
    $(print_usage)
   ,
    PARAMS:
    ======
    CONFD   Confd directory to store tmux custom configurations
    --      End of options
   ,
    DEMO:
    ====
    # Generate with all defaults to \"$(lh_params default-string CONFD)\"/{appendix,plugins}.conf
    ${THE_SCRIPT}
   ,
    # Generate to /etc/tmux/{appendix,plugins}.conf. Requires sudo for non-root user
    sudo ${THE_SCRIPT} /etc/tmux
  "; }

  install_conf() {
    declare source_line="source-file ${CONFD_ALIAS}/plugins.conf"

    config_tmux_create_confd_file "$(lh_params get CONFD)/plugins.conf" "${CONFIG}" \
    && config_tmux_append_source_line "${source_line}"
  }

  reset_tpm_directory() {
    declare -a mdkir_cmd_prefix=(mkdir -p --)
    declare -a mkdir_cmd=("${mdkir_cmd_prefix[@]}" ~/.tmux/plugins)
    is_user_privileged && {
      mkdir_cmd=(su -l "${SUDO_USER}" -c "umask 0077; ${mdkir_cmd_prefix[*]} ~/.tmux/plugins")
    }

    ( set -x
      rm -rf -- "${HOME_DIR}/.tmux/plugins/tpm"
      umask 0077
      "${mkdir_cmd[@]}"
    )
  }

  install_tpm() {
    declare -a clone_cmd_prefix=(git clone https://github.com/tmux-plugins/tpm --)
    declare -a clone_cmd=("${clone_cmd_prefix[@]}" ~/.tmux/plugins/tpm)
    is_user_privileged && {
      clone_cmd=(su -l "${SUDO_USER}" -c "umask 0077; ${clone_cmd_prefix[*]} ~/.tmux/plugins/tpm")
    }

    (
      set -x
      umask 0077
      "${clone_cmd[@]}"
    )
  }

  do_the_rest() {
    declare SOURCE_LINE="source-file ${CONFD_ALIAS}/appendix.conf"
    declare SOURCE_LINE_REX; SOURCE_LINE_REX="$(escape_sed_expr "${SOURCE_LINE}")"
    declare CONFD; CONFD="$(lh_params get CONFD)"

    (
      set -x
      umask -- "${INSTALLED_FILES_UMASK}"
      tee -- "${CONFD}/appendix.conf" <<< "${CONFIG_APPENDIX}" >/dev/null \
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
  }

  main() {
    config_tmux_base "${@}" || return

    install_conf \
    && reset_tpm_directory \
    && install_tpm \
    && do_the_rest
  }

  main "${@}"
)
# .LH_SOURCED: {{ config/tmux/tmux-base.ignore.sh }}
config_tmux_base() {
  { # Service vars
    declare SELF="${FUNCNAME[0]}"

    HOME_DIR="${HOME}"
    INSTALLED_FILES_UMASK=0077
    CONFD_ALIAS=""
  }

  _config_tmux_base_init
  _config_tmux_base_parse_params "${@}"
  _config_tmux_base_check_params

  lh_params invalids >&2 && {
    echo "FATAL (${SELF})" >&2
    return 1
  }

  CONFD_ALIAS="$(alias_home_in_path "$(lh_params get CONFD)")"
}

# shellcheck disable=SC2317
_config_tmux_base_init() {
  # Ensure clean environment
  lh_params reset

  if is_user_privileged; then
    HOME_DIR="$(privileged_user_home)"
    INSTALLED_FILES_UMASK=0022
  fi

  # shellcheck disable=SC2016
  lh_params defaults \
    CONFD='${HOME}/.tmux'

  lh_params_default_CONFD() { cat <<< "${HOME_DIR}/.tmux"; }
}

_config_tmux_base_parse_params() {
  declare -a args

  declare endopts=false
  declare param
  while [[ ${#} -gt 0 ]]; do
    ${endopts} && param='*' || param="${1}"

    case "${param}" in
      --            ) endopts=true ;;
      -\?|-h|--help ) print_help; exit ;;
      --usage       ) print_usage | text_nice; exit ;;
      -*            ) lh_params unsupported "${1}" ;;
      *             ) args+=("${1}") ;;
    esac

    shift
  done

  [[ ${#args[@]} -gt 0 ]] && lh_params set CONFD "$(realpath -m -- "${args[0]}" 2>/dev/null)"
  [[ ${#args[@]} -lt 2 ]] || lh_params unsupported "${args[@]:1}"
}

_config_tmux_base_check_params() {
  lh_params is-blank CONFD && lh_params errbag "CONFD can't be blank"
}

config_tmux_create_confd_file() (
  declare dest="${1}"
  declare conf="${2}"
  declare confd; confd="$(lh_params get CONFD)"

  set -x
  umask -- "${INSTALLED_FILES_UMASK}"
  mkdir -p -- "${confd}" \
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
# .LH_SOURCED: {{ lib/lh-params.sh }}
lh_params() { lh_params_"${1//-/_}" "${@:2}"; }

lh_params_reset() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  declare vname vtype
  for vname in "${!_lh_params_map[@]}"; do
    unset "${vname}"
    declare -"${vtype}"g "${vname}"
  done
}

lh_params_set() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  [[ -n "${2+x}" ]] || { lh_params_noval "${1}"; return 1; }
  # shellcheck disable=SC2034
  LH_PARAMS["${1}"]="${2}"
}

# lh_params_get NAME [DEFAULT]
#
# # Try to get $LH_PARAMS[NAME], fall back to invokation of lh_params_default_NAME,
# # then fallback to $LH_PARAMS_DEFAULTS[NAME] and if doesn't exist RC 1
# lh_params_get NAME
#
# # Try to get $LH_PARAMS[NAME], fall back to DEFAULT_VAL
# lh_params_get NAME DEFAULT_VAL
lh_params_get() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  [[ -n "${LH_PARAMS[${1}]+x}" ]] && { cat <<< "${LH_PARAMS[${1}]}"; return; }
  [[ -n "${2+x}" ]] && { cat <<< "${2}"; return; }
  declare -F "lh_params_default_${1}" &>/dev/null && { "lh_params_default_${1}"; return; }
  [[ -n "${LH_PARAMS_DEFAULTS[${1}]+x}" ]] && { cat <<< "${LH_PARAMS_DEFAULTS[${1}]}"; return; }
  return 1
}

lh_params_is_blank() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  [[ -n "${LH_PARAMS[${1}]+x}" ]] && [[ -z "${LH_PARAMS[${1}]:+x}" ]]
}

lh_params_noval() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  # https://stackoverflow.com/a/13216833
  declare -a issues=("${@/%/ requires a value}")
  lh_params_errbag "${issues[@]}"
}

lh_params_unsupported() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  # https://stackoverflow.com/a/13216833
  declare -a issues=("${@/%/\' param is unsupported}")
  lh_params_errbag "${issues[@]/#/\'}"
}

lh_params_errbag() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  LH_PARAMS_ERRBAG+=("${@}")
}

# lh_params_defaults PARAM_NAME1='DEFAULT_VAL'...
lh_params_defaults() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  declare kv pname pval
  for kv in "${@}"; do
    kv="${kv}="
    pname="${kv%%=*}"
    pval="${kv#*=}"; pval="${pval::-1}"
    LH_PARAMS_DEFAULTS["${pname}"]="${pval}"
  done
}

lh_params_default_string() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  cat <<< "${LH_PARAMS_DEFAULTS[${1}]}"
}

lh_params_ask_config() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }

  declare pname ptext prev_comma=false
  for ptext in "${@}"; do
    [[ "${ptext}" == ',' ]] && { prev_comma=true; continue; }

    ${prev_comma} || [[ -z "${pname}" ]] && {
      pname="${ptext}"
      LH_PARAMS_ASK_PARAMS+=("${pname}")
      prev_comma=false
      continue
    }

    LH_PARAMS_ASK["${pname}"]+="${LH_PARAMS_ASK["${pname}"]+$'\n'}${ptext}"
  done
}

lh_params_ask() {
  declare confirm pname ptext

  [[ -n "${LH_PARAMS_ASK_EXCLUDE+x}" ]] && {
    LH_PARAMS_ASK_EXCLUDE="$(
      # shellcheck disable=SC2001
      sed -e 's/^\s*//' -e 's/\s*$//' <<< "${LH_PARAMS_ASK_EXCLUDE}" \
      | grep -v '^$'
    )"
  }

  while ! [[ "${confirm:-n}" == y ]]; do
    confirm=""

    for pname in "${LH_PARAMS_ASK_PARAMS[@]}"; do
      # Don't prompt for params in LH_PARAMS_ASK_EXCLUDE (text) list
      grep -qFx -- "${pname}" <<< "${LH_PARAMS_ASK_EXCLUDE}" && continue

      read  -erp "${LH_PARAMS_ASK[${pname}]}" \
            -i "$(lh_params_get "${pname}")" "LH_PARAMS[${pname}]"
    done

    echo '============================' >&2

    while [[ ! " y n " == *" ${confirm} "* ]]; do
      read -rp "YES (y) for proceeding or NO (n) to repeat: " confirm
      [[ "${confirm,,}" =~ ^(y|yes)$ ]] && confirm=y
      [[ "${confirm,,}" =~ ^(n|no)$ ]] && confirm=n
    done
  done
}

lh_params_invalids() {
  declare -i rc=1

  [[ ${#LH_PARAMS_ERRBAG[@]} -lt 1 ]] || {
    echo "Issues:"
    printf -- '* %s\n' "${LH_PARAMS_ERRBAG[@]}"
    rc=0
  }

  return ${rc}
}

_lh_params_init() {
  declare -A _lh_params_map=(
    [LH_PARAMS]=A
    [LH_PARAMS_DEFAULTS]=A
    [LH_PARAMS_ASK]=A
    [LH_PARAMS_ASK_PARAMS]=a
    [LH_PARAMS_ERRBAG]=a
  )

  # Ensure global variables
  declare vname vtype
  for vname in "${!_lh_params_map[@]}"; do
    vtype="${_lh_params_map[${vname}]}"
    [[ "$(declare -p "${vname}" 2>/dev/null)" == "declare -${vtype}"* ]] && continue

    unset "${vname}"
    declare -"${vtype}"g "${vname}"
  done

  [[ "${FUNCNAME[1]}" != lh_params_* ]] || {
    unset vname vtype
    "${FUNCNAME[1]}" "${@}"
  }
}
# .LH_SOURCED: {{/ lib/lh-params.sh }}
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

is_port_valid() {
  grep -qx -- '[0-9]\+' <<< "${1}" \
  && [[ "${1}" -ge 0 ]] \
  && [[ "${1}" -le 65535 ]]
}
# .LH_SOURCED: {{ lib/basic.sh }}
# https://stackoverflow.com/a/2705678
escape_sed_expr()  { sed -e 's/[]\/$*.^[]/\\&/g' <<< "${1-$(cat)}"; }
escape_sed_repl()  { sed -e 's/[\/&]/\\&/g' <<< "${1-$(cat)}"; }

escape_single_quotes()  { declare str="${1-$(cat)}"; cat <<< "${str//\'/\'\\\'\'}"; }
escape_double_quotes()  { declare str="${1-$(cat)}"; cat <<< "${str//\"/\"\\\"\"}"; }
# .LH_SOURCED: {{/ lib/basic.sh }}
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
# .LH_SOURCED: {{/ config/tmux/tmux-base.ignore.sh }}

# .LH_NOSOURCE

(return &>/dev/null) || {
  config_tmux_plugins "${@}"
}
