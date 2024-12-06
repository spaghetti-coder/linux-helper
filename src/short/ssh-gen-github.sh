#!/usr/bin/env bash

# .LH_SOURCE:bin/ssh-gen.sh
# .LH_SOURCE:lib/text.sh

ssh_gen_github() (
  # If not a file, default to ssh-gen.sh script name
  declare THE_SCRIPT=ssh-gen-github.sh
  grep -q -m 1 -- '.' "${0}" 2>/dev/null && THE_SCRIPT="$(basename -- "${0}")"

  declare -A DEFAULTS=(
    [account]=git
    [host]=github.com
  )

  declare -a UPSTREAM_PARAMS=("${DEFAULTS[account]}" "${DEFAULTS[host]}")

  print_help_usage() {
    echo "
      ${THE_SCRIPT} [--host HOST='${DEFAULTS[host]}'] \\
     ,  [--comment COMMENT=\"\$(id -un)@\$(hostname -f)\"] [--] [ACCOUNT='${DEFAULTS[account]}']
    "
  }

  print_help() {
    declare -r ACCOUNT=foo

    text_nice "
      Generate private and public key pair and configure ~/.ssh/config file to
      use them. It is a github centric shortcut of ssh-gen.sh tool.
     ,
      USAGE:
      =====
      $(print_help_usage)
     ,
      PARAMS:
      ======
      ACCOUNT   Github account, only used to form cert filename
      --        End of options
      --host    SSH host match pattern
      --comment Certificate comment
     ,
      DEMO:
      ====
      # Generate with all defaults to PK file ~/.ssh/${DEFAULTS[host]}/${DEFAULTS[account]}
      ${THE_SCRIPT}
     ,
      # Generate to ~/.ssh/${DEFAULTS[host]}/${ACCOUNT}
      ${THE_SCRIPT} ${ACCOUNT} --host github.com-${ACCOUNT} --comment Zoo
    "
  }

  parse_params() {
    declare -a args

    declare endopts=false
    declare param
    while [[ ${#} -gt 0 ]]; do
      ${endopts} && param='*' || param="${1}"

      case "${param}" in
        --            ) endopts=true ;;
        -\?|-h|--help ) print_help; exit ;;
        --usage       ) print_help_usage | text_nice; exit ;;
        --host        ) UPSTREAM_PARAMS+=(--host "${2}"); shift ;;
        --comment     ) UPSTREAM_PARAMS+=(--comment "${2}"); shift ;;
        *             ) args+=("${1}") ;;
      esac

      shift
    done

    [[ ${#args[@]} -gt 0 ]] && UPSTREAM_PARAMS+=(--filename "${args[0]}")
    [[ ${#args[@]} -lt 2 ]] || UPSTREAM_PARAMS+=(-- "${args[@]:1}")
  }

  main() {
    parse_params "${@}"

    ssh_gen "${UPSTREAM_PARAMS[@]}"
  }

  main "${@}"
)

# .LH_NOSOURCE

(return &>/dev/null) || {
  ssh_gen_github "${@}"
}
