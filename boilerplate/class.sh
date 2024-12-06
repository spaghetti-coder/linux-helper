#!/usr/bin/env bash

# .LH_SOURCE:lib/text.sh
# .LH_SOURCE:base.ignore.sh

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

# .LH_NOSOURCE

(return &>/dev/null) || {
  class "${@}"
}
