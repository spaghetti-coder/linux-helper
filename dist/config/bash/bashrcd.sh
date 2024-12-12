#!/usr/bin/env bash

# shellcheck disable=SC2317
bashrcd() (
  { # Service vars
    declare -r SELF="${FUNCNAME[0]}"

    # If not a file, default to bashrcd.sh script name
    declare THE_SCRIPT=bashrcd.sh
    grep -q -m 1 -- '.' "${0}" 2>/dev/null && THE_SCRIPT="$(basename -- "${0}")"
  }

  declare -r BASHRCD_HOME="${HOME}/.bashrc.d"
  declare -r INIT_PATH="${BASHRCD_HOME}/000-bashcd-init"
  # shellcheck disable=SC2016
  declare INIT_PATH_ENTRY; INIT_PATH_ENTRY=". $(alias_home_in_path "${INIT_PATH}")"

  declare CONFIG; CONFIG="$(cat <<'.LH_HEREDOC'
_BASHRCD_FILES="$(
  the_dir="$(dirname -- "${BASH_SOURCE[0]}")"
  find -- "${the_dir}" -maxdepth 1 -name '*.sh' -not -path "${BASH_SOURCE[0]}" -type f \
  | sort -n | grep '.'
)" && {
  mapfile -t _BASHRCD_FILES <<< "${_BASHRCD_FILES}"

  for _BASHRCD_FILE in "${_BASHRCD_FILES[@]}"; do
    # shellcheck disable=SC1090
    . "${_BASHRCD_FILE}"
  done
} || return 0
.LH_HEREDOC
)"

  print_usage() { echo "${THE_SCRIPT}"; }

  print_help() { text_nice "
    Create ~/.bashrc.d directory and source all its '*.sh' scripts to ~/.bashrc
   ,
    USAGE:
    =====
    $(print_usage)
   ,
    DEMO:
    ====
    ${THE_SCRIPT}
  "; }

  parse_params() {
    declare endopts=false
    declare param
    while [[ ${#} -gt 0 ]]; do
      ${endopts} && param='*' || param="${1}"

      case "${param}" in
        --            ) endopts=true ;;
        -\?|-h|--help ) print_help; exit ;;
        --usage       ) print_usage | text_nice; exit ;;
        *             ) lh_params unsupported "${1}" ;;
      esac

      shift
    done
  }

  home() { printf -- '%s\n' "${BASHRCD_HOME}";  }

  main() {
    parse_params "${@}"

    lh_params invalids >&2 && {
      echo "FATAL (${SELF})" >&2
      return 1
    }

    ( set -x
      umask 0077
      mkdir -p -- "${BASHRCD_HOME}"
      tee -- "${INIT_PATH}" <<< "${CONFIG}" >/dev/null
    ) && (
      grep -qFx -- "${INIT_PATH_ENTRY}" "${HOME}/.bashrc" && return
      set -x
      tee -a -- "${HOME}/.bashrc" <<< "${INIT_PATH_ENTRY}" >/dev/null
    )
  }

  declare -a EXPORTS=(
    main
    home
  )

  printf -- '%s\n' "${EXPORTS[@]}" | grep -qFx -- "${1//-/_}" && {
    "${1//-/_}" "${@:2}"
  }
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

  if grep -qF -- '://' <<< "${1}"; then
    _dt_the_url="${1}"
    declare -a _dt_the_tool
  else
    # shellcheck disable=SC2178
    declare -n _dt_the_tool="${1}"
  fi

  curl -V &>/dev/null && _dt_the_tool=(curl -sfL --) || _dt_the_tool=(wget -qO- --)
  "${_dt_the_tool[@]}" -V &>/dev/null || return

  if [[ -n "${_dt_the_url}" ]]; then
    (set -x; "${_dt_the_tool[@]}" "${_dt_the_url}")
  fi
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

# .LH_NOSOURCE

(return &>/dev/null) || {
  bashrcd main "${@}"
}
