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
# .LH_SOURCE_NW:asset/conf/bash/bashrcd-init.ignore.sh
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
      grep -qFx -- "${INIT_PATH_ENTRY}" "${HOME}/.bashrc" 2>/dev/null && return
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

# .LH_SOURCE:lib/lh-params.sh
# .LH_SOURCE:lib/system.sh
# .LH_SOURCE:lib/text.sh

# .LH_NOSOURCE

(return &>/dev/null) || {
  bashrcd main "${@}"
}
