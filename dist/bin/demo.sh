#!/usr/bin/env bash

demo() (
  { # Service vars
    declare -r SELF="${FUNCNAME[0]}"

    # If not a file, default to demo.sh script name
    declare THE_SCRIPT=demo.sh
    grep -q -m 1 -- '.' "${0}" 2>/dev/null && THE_SCRIPT="$(basename -- "${0}")"
  }

  # shellcheck disable=SC2317
  # shellcheck disable=SC2016
  init() {
    # Ensure clean environment
    lh_params reset

    # Configure defaults
    lh_params defaults \
      AGE=0 \
      DOMAIN='$(hostname -f)' \
      ASK=false

    # Configure custom defaults
    lh_params_default_DOMAIN() { hostname -f; }
  }

  print_usage() { echo "
    ${THE_SCRIPT} [--ask] [--age AGE='$(lh_params default-string AGE)'] [--domain DOMAIN=\"$(lh_params default-string DOMAIN)\"] [--] NAME
  "; }

  print_help() { text_nice "
    Just a demo boilerplate project to get user info.
   ,
    USAGE:
    =====
    $(print_usage)
   ,
    PARAMS:
    ======
    NAME    Person's name
    --      End of options
    --ask     Provoke a prompt for all params
    --age     Person's age
    --domain  Person's domain
   ,
    DEMO:
    ====
    # With all defaults
    ${THE_SCRIPT} Spaghetti
   ,
    # Provie info interactively
    ${THE_SCRIPT} --ask
  "; }

  parse_params() {
    declare -a args

    declare endopts=false
    declare param
    while [[ ${#} -gt 0 ]]; do
      ${endopts} && param='*' || param="${1}"

      case "${param}" in
        --            ) endopts=true ;;
        -\?|-h|--help ) print_help; exit ;;
        --usage       ) print_usage | text_nice; exit ;;
        --age         ) lh_params set AGE "${@:2:1}"; shift ;;
        --ask         ) lh_params set ASK true ;;
        -*            ) lh_params unsupported "${1}" ;;
        *             ) args+=("${1}") ;;
      esac

      shift
    done

    [[ ${#args[@]} -gt 0 ]] && lh_params set NAME "${args[0]}"
    [[ ${#args[@]} -lt 2 ]] || lh_params unsupported "${args[@]:1}"
  }

  trap_ask() {
    "$(lh_params get ASK)" || return 0

    lh_params ask-config \
      , NAME "Choose any name for your user" "Name: " \
      , AGE "Age: "
    lh_params ask-config DOMAIN "Domain: "

    lh_params ask
  }

  check_params() {
    lh_params get NAME >/dev/null || lh_params noval NAME
    lh_params is-blank NAME && lh_params errbag "NAME can't be blank"
  }

  main() {
    init
    parse_params "${@}"
    trap_ask
    check_params

    lh_params invalids >&2 && {
      echo "FATAL (${SELF})" >&2
      return 1
    }

    echo "Name: $(lh_params get NAME)"
    echo "Age: $(lh_params get AGE)"
    echo "Domain: $(lh_params get DOMAIN)"
  }

  main "${@}"
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
  demo "${@}"
}
