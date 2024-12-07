#!/usr/bin/env bash

class() (
  declare SELF="${FUNCNAME[0]}"

  # If not a file, default to ssh-gen.sh script name
  declare THE_SCRIPT=class.sh
  grep -q -m 1 -- '.' "${0}" 2>/dev/null && THE_SCRIPT="$(basename -- "${0}")"

  # This is required for lh_params_apply_defaults
  # shellcheck disable=SC2034
  declare -A LH_DEFAULTS=(
    [AGE]="0"
  )

  print_help_usage() {
    echo "
      ${THE_SCRIPT} [--age AGE='${LH_DEFAULTS[age]}'] [--] NAME
    "
  }

  print_help() {
    text_nice "
      Get personal info
     ,
      USAGE:
      =====
      $(print_help_usage)
     ,
      PARAMS:
      ======
      NAME    Person's name
      --      End of options
      --age   Person's age
      --ask   Provoke a prompt for all params
     ,
      DEMO:
      ====
      # With default age
      ${THE_SCRIPT} Spaghetti
     ,
      # Provie info interactively
     ${THE_SCRIPT} --ask
    "
  }

  parse_params() {
    declare -a args

    lh_params_reset

    declare endopts=false
    declare param
    while [[ ${#} -gt 0 ]]; do
      ${endopts} && param='*' || param="${1}"

      case "${param}" in
        --            ) endopts=true ;;
        -\?|-h|--help ) print_help; exit ;;
        --usage       ) print_help_usage | text_nice; exit ;;
        --age         ) lh_param_set AGE "${@:2:1}"; shift ;;
        --ask         ) lh_param_set ASK true ;;
        -*            ) lh_params_unsupported "${1}" ;;
        *             ) args+=("${1}") ;;
      esac

      shift
    done

    [[ ${#args[@]} -gt 0 ]] && lh_param_set NAME "${args[0]}"
    [[ ${#args[@]} -lt 2 ]] || lh_params_unsupported "${args[@]:1}"
  }

  trap_ask() {
    ! ${LH_PARAMS[ASK]-false} && return 0

    declare confirm

    while ! [[ "${confirm:-n}" == y ]]; do
      confirm=""

      read -erp "Name: " -i "${LH_PARAMS[NAME]}" 'LH_PARAMS[NAME]'
      read -erp "Age: " -i "${LH_PARAMS[AGE]}" 'LH_PARAMS[AGE]'

      echo '============================'

      while [[ ! " y n " == *" ${confirm} "* ]]; do
        read -rp "YES (y) for proceeding or NO (n) to repeat: " confirm
        [[ "${confirm,,}" =~ ^(y|yes)$ ]] && confirm=y
        [[ "${confirm,,}" =~ ^(n|no)$ ]] && confirm=n
      done
    done
  }

  check_required_params() {
    [[ -n "${LH_PARAMS[NAME]}" ]] || lh_params_noval NAME
  }

  apply_defaults() {
    lh_params_apply_defaults

    # ... More complex defaults if required ...
  }

  main() {
    # shellcheck disable=SC2015
    parse_params "${@}"
    trap_ask
    check_required_params

    lh_params_flush_invalid >&2 && {
      echo "FATAL (${SELF})" >&2
      return 1
    }

    apply_defaults

    echo "Name: ${LH_PARAMS[NAME]}"
    echo "Age: ${LH_PARAMS[AGE]}"
  }

  main "${@}"
)
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

# .LH_NOSOURCE

(return &>/dev/null) || {
  class "${@}"
}
