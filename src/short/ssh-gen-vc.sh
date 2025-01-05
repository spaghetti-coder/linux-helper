#!/usr/bin/env bash

ssh_gen_vc() (
  { # Service vars
    declare -r SELF="${FUNCNAME[0]}"

    # If not a file, default to ssh-gen-vc.sh script name
    declare THE_SCRIPT="ssh-gen-vc.sh"
    grep -q -m 1 -- '.' "${0}" 2>/dev/null && THE_SCRIPT="$(basename -- "${0}")"
  }

  # shellcheck disable=SC2317
  # shellcheck disable=SC2016
  init() {
    # Ensure clean environment
    lh_params reset

    # Configure defaults
    lh_params defaults \
      ASK=false \
      ACCOUNT=git \
      PORT=22 \
      HOST=HOSTNAME \
      COMMENT='$(id -un)@$(hostname -f)'

    # Configure custom defaults
    lh_params_default_HOST() { lh_params get HOSTNAME; }
    lh_params_default_COMMENT() { printf -- '%s\n' "$(id -un)@$(hostname -f)"; }
  }

  print_usage() { text_nice "
    ${THE_SCRIPT} [--ask] [--host HOST=$(lh_params default-string HOST)] [--port PORT='$(lh_params default-string PORT)'] \\
   ,  [--comment COMMENT=\"$(lh_params default-string COMMENT)\"] [--] HOSTNAME [ACCOUNT=$(lh_params default-string ACCOUNT)]
  "; }

  print_help() {
    declare -r  hostname=github.com \
                account=bar

    text_nice "
      Generic version control system centric shortcut of ssh-gen.sh tool. Generate
      private and public key pair and configure ~/.ssh/config file to use them.

      USAGE:
      =====
      $(print_usage | sed 's/^/,/')

      PARAMS:
      ======
      HOSTNAME  VC system hostname
      ACCOUNT   VC system account name, only used to make cert filename, for SSH
     ,          connection 'git' user will be used.
      --        End of options
      --ask     Provoke a prompt for all params
      --host    SSH host match pattern
      --port    SSH port
      --comment Certificate comment

      DEMO:
      ====
      # Generate with all defaults to PK file ~/.ssh/${hostname}/$(lh_params default-string ACCOUNT)
      ${THE_SCRIPT} ${hostname}

      # Generate to ~/.ssh/${hostname}/${account} with custom hostname and comment
      ${THE_SCRIPT} ${hostname} ${account} --host ${hostname}-${account} --comment Zoo
    "
  }

  parse_params() {
    declare -a args

    declare endopts=false
    declare param
    while [[ ${#} -gt 0 ]]; do
      ${endopts} && param='*' || param="${1}"

      case "${param}" in
        -\?|-h|--help ) print_help; exit ;;
        --usage       ) print_usage; exit ;;
        --            ) endopts=true ;;
        --ask         ) lh_params set ASK true ;;
        --host        ) lh_params set HOST "${@:2:1}"; shift ;;
        --port        ) lh_params set PORT "${@:2:1}"; shift ;;
        --comment     ) lh_params set COMMENT "${@:2:1}"; shift ;;
        -*            ) lh_params unsupported "${1}" ;;
        *             ) args+=("${1}") ;;
      esac

      shift
    done

    [[ ${#args[@]} -gt 0 ]] && lh_params set HOSTNAME "${args[0]}"
    [[ ${#args[@]} -gt 1 ]] && lh_params set ACCOUNT "${args[1]}"
    [[ ${#args[@]} -lt 3 ]] || lh_params unsupported "${args[@]:2}"
  }

  trap_ask() {
    "$(lh_params get ASK)" || return 0

    lh_params ask-config \
      , HOSTNAME "VC HostName (%h for the target hostname): " \
      , ACCOUNT "VC user account name: " \
      , HOST "SSH Host: " \
      , PORT "SSH Host port: " \
      , COMMENT "Comment: "

    lh_params ask
  }

  check_params() {
    lh_params get HOSTNAME >/dev/null || lh_params_noval HOSTNAME

    lh_params is-blank HOSTNAME && lh_params errbag "HOSTNAME can't be blank"
    lh_params is-blank ACCOUNT  && lh_params errbag "ACCOUNT can't be blank"
    lh_params is-blank HOST     && lh_params errbag "HOST can't be blank"
    lh_params is-blank PORT     && lh_params errbag "PORT can't be blank"

    declare port; port="$(lh_params get PORT)" \
      && ! lh_params is-blank PORT \
      && ! is_port_valid "${port}" \
      && lh_params errbag "PORT='$(escape_single_quotes "${port}")' is invalid"
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

    declare -a downstream=(ssh_gen)
    declare filename host port comment hostname

    filename="$(lh_params get ACCOUNT)" && downstream+=(--filename "${filename}")
    host="$(lh_params get HOST)" && downstream+=(--host "${host}")
    port="$(lh_params get PORT)" && downstream+=(--port "${port}")
    comment="$(lh_params get COMMENT)" && downstream+=(--comment "${comment}")

    downstream+=( -- "$(lh_params get HOSTNAME)" git)

    "${downstream[@]}"
  }

  main "${@}"
)

# .LH_SOURCE:bin/ssh-gen.sh
# .LH_SOURCE:lib/lh-params.sh
# .LH_SOURCE:lib/text.sh

# .LH_NOSOURCE

(return &>/dev/null) || {
  ssh_gen_vc "${@}"
}
