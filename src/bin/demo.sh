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

  print_usage() { text_nice "
    ${THE_SCRIPT} [--ask] [--age AGE='$(lh_params default-string AGE)'] [--domain DOMAIN=\"$(lh_params default-string DOMAIN)\"] [--] NAME
  "; }

  print_help() { text_nice "
    Just a demo boilerplate project to get user info.

    USAGE:
    =====
    $(print_usage | sed 's/^/,/')

    PARAMS:
    ======
    NAME    Person's name
    --      End of options
    --ask     Provoke a prompt for all params
    --age     Person's age
    --domain  Person's domain

    DEMO:
    ====
    # With all defaults
    ${THE_SCRIPT} Spaghetti

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
        --usage       ) print_usage; exit ;;
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

# .LH_SOURCE:lib/lh-params.sh
# .LH_SOURCE:lib/text.sh

# .LH_NOSOURCE

(return &>/dev/null) || {
  demo "${@}"
}
