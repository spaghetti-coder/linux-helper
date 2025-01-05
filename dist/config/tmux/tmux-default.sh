#!/usr/bin/env bash

config_tmux_default() (
  { # Service vars

    # If not a file, default to ssh-gen.sh script name
    declare THE_SCRIPT=tmux-default.sh
    grep -q -m 1 -- '.' "${0}" 2>/dev/null && THE_SCRIPT="$(basename -- "${0}")"
  }

  declare CONFIG; CONFIG="$(text_nice "
    # default.conf
    
    set-option -g prefix C-Space
    set-option -g allow-rename off
    set -g history-limit 100000
    set -g renumber-windows on
    set -g base-index 1
    set -g display-panes-time 3000
    setw -g pane-base-index 1
    setw -g aggressive-resize on
  ")"

  # shellcheck disable=SC2317
  print_usage() { text_nice "
    ${THE_SCRIPT} [--] [CONFD=\"$(lh_params default-string CONFD)\"]
  "; }

  # shellcheck disable=SC2317
  print_help() { text_nice "
    Generate basic tmux configuration preset and source it to ~/.tmux.conf file. The
    config is with the following content:

    \`\`\`
    ${CONFIG}
    \`\`\`

    USAGE:
    =====
    $(print_usage | sed 's/^/,/')

    PARAMS:
    ======
    CONFD   Confd directory to store tmux custom configurations
    --      End of options

    DEMO:
    ====
    # Generate with all defaults to \"$(lh_params default-string CONFD)/default.conf\"
    ${THE_SCRIPT}

    # Generate to /etc/tmux/default.conf. Requires sudo for non-root user
    sudo ${THE_SCRIPT} /etc/tmux
  "; }

  main() {
    config_tmux_base "${@}" || return

    declare source_line="source-file ${CONFD_ALIAS}/default.conf"

    config_tmux_create_confd_file "$(lh_params get CONFD)/default.conf" "${CONFIG}" \
    && config_tmux_append_source_line "${source_line}"
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
      --usage       ) print_usage; exit ;;
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
  declare -f "lh_params_set_${1}" &>/dev/null && { "lh_params_set_${1}" "${2}"; return $?; }
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
  declare -F "lh_params_get_${1}" &>/dev/null && { "lh_params_get_${1}"; return; }
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

    # Exclude ':*' adaptor suffix from pname
    LH_PARAMS_ASK["${pname%:*}"]+="${LH_PARAMS_ASK["${pname%:*}"]+$'\n'}${ptext}"
  done
}

lh_params_ask() {
  [[ -n "${LH_PARAMS_ASK_EXCLUDE+x}" ]] && {
    LH_PARAMS_ASK_EXCLUDE="$(
      # shellcheck disable=SC2001
      sed -e 's/^\s*//' -e 's/\s*$//' <<< "${LH_PARAMS_ASK_EXCLUDE}" \
      | grep -v '^$'
    )"
  }

  declare confirm pname question handler_id
  while ! ${confirm-false}; do
    for pname in "${LH_PARAMS_ASK_PARAMS[@]}"; do
      handler_id="$(
        set -o pipefail
        grep -o ':[^:]\+$' <<< "${pname}" | sed -e 's/^://'
      )" || handler_id=default
      pname="${pname%:*}"

      # Don't prompt for params in LH_PARAMS_ASK_EXCLUDE (text) list
      grep -qFx -- "${pname}" <<< "${LH_PARAMS_ASK_EXCLUDE}" && continue

      question="${LH_PARAMS_ASK[${pname}]}"
      "lh_params_ask_${handler_id}_handler" "${pname}" "${question}"
    done

    echo '============================' >&2

    confirm=nobool
    while ! to_bool "${confirm}" >/dev/null; do
      read -rp "YES (y) for proceeding or NO (n) to repeat: " confirm
      confirm="$(to_bool "${confirm}")"
    done
  done
}

lh_params_ask_default_handler() {
  declare pname="${1}"
  declare question="${2}"
  declare answer

  read -erp "${question}" -i "$(lh_params_get "${pname}")" answer
  lh_params_set "${pname}" "${answer}"
}

lh_params_ask_pass_handler() {
  declare pname="${1}"
  declare question="${2}"
  declare answer answer_repeat
  while :; do
    read -srp "${question}" answer
    echo >&2
    read -srp "Confirm ${question}" answer_repeat
    echo >&2

    [[ "${answer}" == "${answer_repeat}" ]] || {
      echo "Confirm value doesn't match! Try again" >&2
      continue
    }

    [[ -n "${answer}" ]] && lh_params_set "${pname}" "${answer}"
    break
  done
}

lh_params_ask_bool_handler() {
  declare pname="${1}"
  declare question="${2}"
  declare answer
  while :; do
    read -erp "${question}" -i "$(lh_params_get "${pname}")" answer

    answer="$(to_bool "${answer}")" || {
      echo "'${answer}' is not a valid boolean value! Try again" >&2
      continue
    }

    lh_params_set "${pname}" "${answer}"
    break
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
# .LH_SOURCED: {{ lib/basic.sh }}
# https://stackoverflow.com/a/2705678
escape_sed_expr()  { sed -e 's/[]\/$*.^[]/\\&/g' <<< "${1-$(cat)}"; }
escape_sed_repl()  { sed -e 's/[\/&]/\\&/g' <<< "${1-$(cat)}"; }

escape_single_quotes()  { declare str="${1-$(cat)}"; cat <<< "${str//\'/\'\\\'\'}"; }
escape_double_quotes()  { declare str="${1-$(cat)}"; cat <<< "${str//\"/\"\\\"\"}"; }

to_bool() {
  [[ "${1,,}" =~ ^(1|y|yes|true)$ ]] && { echo true; return; }
  [[ "${1,,}" =~ ^(0|n|no|false)$ ]] && { echo false; return; }
  return 1
}

# https://unix.stackexchange.com/a/194790
uniq_ordered() {
  cat -n <<< "${1-$(cat)}" | sort -k2 -k1n  | uniq -f1 | sort -nk1,1 | cut -f2-
}

template_compile() {
  # echo 'text {{ KEY1 }} more {{ KEY2 }} text' \
  # | template_compile [KEY1 VAL1]...

  declare -a expr filter=(cat)
  declare key val
  while [[ ${#} -gt 0 ]]; do
    [[ "${1}" == *'='* ]] && {
      key="${1%%=*}" val="${1#*=}"
      shift
    } || {
      key="${1}" val="${2}"
      shift 2
    }
    expr+=(-e 's/{{\s*'"$(escape_sed_expr "${key}")"'\s*}}/'"$(escape_sed_repl "${val}")"'/g')
  done

  [[ ${#expr[@]} -lt 1 ]] || filter=(sed "${expr[@]}")

  "${filter[@]}"
}
# .LH_SOURCED: {{/ lib/basic.sh }}
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

# USAGE:
#   # Cache the download tool and use it
#   declare -a DL_TOOL
#   download_tool DL_TOOL
#   "${DL_TOOL[@]}" https://google.com > google.txt
#
#   # Just use it to download
#   download_tool https://google.com > google.txt
download_tool() {
  declare _dt_the_url

  if [[ "${1}" == *'://'* ]]; then
    _dt_the_url="${1}"
    declare -a _dt_the_tool
  else
    # shellcheck disable=SC2178
    declare -n _dt_the_tool="${1}"
  fi

  { curl -V &>/dev/null && _dt_the_tool=(curl -fsSL --); } \
  || { wget -V &>/dev/null &&  _dt_the_tool=(wget -qO- --); } \
  || return

  if [[ -n "${_dt_the_url}" ]]; then
    (set -x; "${_dt_the_tool[@]}" "${_dt_the_url}")
  fi
}
# .LH_SOURCED: {{/ lib/system.sh }}
# .LH_SOURCED: {{ lib/text.sh }}
# shellcheck disable=SC2001
# shellcheck disable=SC2120
text_ltrim() { sed -e 's/^\s\+//' <<< "${1-$(cat)}"; }
text_rtrim() { sed -e 's/\s\+$//' <<< "${1-$(cat)}"; }
text_trim() { text_ltrim <<< "${1-$(cat)}" | text_rtrim; }
text_rmblank() { grep -v '^\s*$' <<< "${1-$(cat)}"; return 0; }
text_nice() {
  text_trim <<< "${1-$(cat)}" \
  | sed -e '/^.\+$/,$!d' | tac \
  | sed -e '/^.\+$/,$!d' -e 's/^,//' | tac
}
# .LH_SOURCED: {{/ lib/text.sh }}
# .LH_SOURCED: {{/ config/tmux/tmux-base.ignore.sh }}

# .LH_NOSOURCE

(return &>/dev/null) || {
  config_tmux_default "${@}"
}
