#!/usr/bin/env bash

ssh_gen_github() (
  { # Service vars
    # declare -r SELF="${FUNCNAME[0]}"

    # If not a file, default to ssh-gen-github script name
    declare THE_SCRIPT="ssh-gen-github.sh"
    grep -q -m 1 -- '.' "${0}" 2>/dev/null && THE_SCRIPT="$(basename -- "${0}")"
  }


  # shellcheck disable=SC2016
  declare -A DEFAULTS=(
    [account]=git
    [host]=github.com
    [comment]='$(id -un)@$(hostname -f)'
  )

  declare -a DOWNSTREAM=(ssh_gen_vc "${DEFAULTS[host]}")

  print_usage() { echo "
    ${THE_SCRIPT} [--ask] [--host HOST='${DEFAULTS[host]}'] \\
    ,  [--comment COMMENT=\"${DEFAULTS[comment]}\"] [--] [ACCOUNT='${DEFAULTS[account]}']
  "; }

  print_help() {
    declare -r ACCOUNT=foo

    text_nice "
      github.com centric shortcut of ssh-gen.sh tool. Generate private and public key
      pair and configure ~/.ssh/config file to use them.
     ,
      USAGE:
      =====
      $(print_usage)
     ,
      PARAMS:
      ======
      ACCOUNT   Github account name, only used to make cert filename, for SSH
     ,          connection 'git' user will be used.
      --        End of options
      --ask     Provoke a prompt for all params
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
    declare -a invals

    declare endopts=false
    declare param
    while [[ ${#} -gt 0 ]]; do
      ${endopts} && param='*' || param="${1}"

      case "${param}" in
        --            ) endopts=true ;;
        -\?|-h|--help ) print_help; exit ;;
        --usage       ) print_usage | text_nice; exit ;;
        --ask         ) DOWNSTREAM+=(--ask) ;;
        --host        ) DOWNSTREAM+=(--host "${@:2:1}"); shift ;;
        --comment     ) DOWNSTREAM+=(--comment "${@:2:1}"); shift ;;
        -*            ) invals+=("${1}") ;;
        *             ) DOWNSTREAM+=("${1}") ;;
      esac

      shift
    done

    DOWNSTREAM+=(-- "${invals[@]}")
  }

  main() {
    parse_params "${@}"

    LH_PARAMS_ASK_EXCLUDE='
      HOSTNAME
      PORT
    ' "${DOWNSTREAM[@]}"
  }

  main "${@}"
)

# .LH_SOURCE:lib/text.sh
# .LH_SOURCE:short/ssh-gen-vc.sh

# .LH_NOSOURCE

(return &>/dev/null) || {
  ssh_gen_github "${@}"
}
