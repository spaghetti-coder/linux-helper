#!/usr/bin/env bash

# shellcheck disable=SC2317
git_ps1() (
  { # Service vars
    declare -r SELF="${FUNCNAME[0]}"

    # If not a file, default to git-ps1.sh script name
    declare THE_SCRIPT=git-ps1.sh
    grep -q -m 1 -- '.' "${0}" 2>/dev/null && THE_SCRIPT="$(basename -- "${0}")"
  }

  declare CONF_PATH; CONF_PATH="$(bashrcd home)/500-git-ps1.sh"

  declare CONFIG; CONFIG="$(cat <<'.LH_HEREDOC'
# .LH_SOURCE_NW:asset/conf/git/ps1.ignore.sh
.LH_HEREDOC
)"

  print_usage() { text_nice "${THE_SCRIPT}"; }

  print_help() { text_nice "
    Cusomize bash PS1 prompt for git

    USAGE:
    =====
    $(print_usage | sed 's/^/,/')

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
        --usage       ) print_usage; exit ;;
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

    bashrcd main && (set -x; tee -- "${CONF_PATH}" <<< "${CONFIG}" >/dev/null)
  }

  declare -a EXPORTS=(
    main
  )

  if printf -- '%s\n' "${EXPORTS[@]}" | grep -qFx -- "${1//-/_}"; then
    "${1//-/_}" "${@:2}"
  else
    lh_params unsupported "${1}"; lh_params invalids >&2 && {
      echo "FATAL (${SELF})" >&2
      return 1
    }
  fi
)

# .LH_SOURCE:config/bash/bashrcd.sh
# .LH_SOURCE:lib/lh-params.sh
# .LH_SOURCE:lib/text.sh

# .LH_NOSOURCE

(return &>/dev/null) || {
  git_ps1 main "${@}"
}
