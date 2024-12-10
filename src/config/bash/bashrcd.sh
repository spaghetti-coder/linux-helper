#!/usr/bin/env bash

bashrcd() (
  { # Service vars
    declare -r SELF="${FUNCNAME[0]}"

    # If not a file, default to bashrcd.sh script name
    declare THE_SCRIPT=bashrcd.sh
    grep -q -m 1 -- '.' "${0}" 2>/dev/null && THE_SCRIPT="$(basename -- "${0}")"
  }

  declare INIT_PATH="${HOME}/.bashrc.d/000-bashcd-init"
  # shellcheck disable=SC2016
  declare INIT_PATH_ENTRY='. ~/.bashrc.d/000-bashcd-init'

  declare CONFIG; CONFIG="$(cat <<'.LH_HEREDOC'
# .LH_SOURCE_NW:asset/conf/bash/bashrcd-init.ignore.sh
.LH_HEREDOC
)"

  print_usage() { echo "
    ${THE_SCRIPT}
  "; }

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

  main() {
    parse_params "${@}"

    lh_params invalids >&2 && {
      echo "FATAL (${SELF})" >&2
      return 1
    }

    declare init_dir; init_dir="$(dirname -- "${INIT_PATH}")"
    ( set -x
      umask 0077
      mkdir -p -- "${init_dir}"
      tee -- "${INIT_PATH}" <<< "${CONFIG}" >/dev/null
    ) && (
      grep -qFx -- "${INIT_PATH_ENTRY}" "${HOME}/.bashrc" && return
      set -x
      tee -a -- "${HOME}/.bashrc" <<< "${INIT_PATH_ENTRY}" >/dev/null
    )
  }

  main "${@}"
)

# .LH_SOURCE:lib/lh-params.sh
# .LH_SOURCE:lib/text.sh

# .LH_NOSOURCE

(return &>/dev/null) || {
  bashrcd "${@}"
}
