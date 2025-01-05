#!/usr/bin/env bash

config_tmux_base() {
  { # Service vars
    declare SELF="${FUNCNAME[0]}"

    HOME_DIR="${HOME}"
    INSTALLED_FILES_UMASK=0077
    CONFD_ALIAS=""
  }

  _config_tmux_base_init
  _config_tmux_base_parse_params "${@}"
  _config_tmux_base_check_params

  lh_params invalids >&2 && {
    echo "FATAL (${SELF})" >&2
    return 1
  }

  CONFD_ALIAS="$(alias_home_in_path "$(lh_params get CONFD)")"
}

# shellcheck disable=SC2317
_config_tmux_base_init() {
  # Ensure clean environment
  lh_params reset

  if is_user_privileged; then
    HOME_DIR="$(privileged_user_home)"
    INSTALLED_FILES_UMASK=0022
  fi

  # shellcheck disable=SC2016
  lh_params defaults \
    CONFD='${HOME}/.tmux'

  lh_params_default_CONFD() { cat <<< "${HOME_DIR}/.tmux"; }
}

_config_tmux_base_parse_params() {
  declare -a args

  declare endopts=false
  declare param
  while [[ ${#} -gt 0 ]]; do
    ${endopts} && param='*' || param="${1}"

    case "${param}" in
      --            ) endopts=true ;;
      -\?|-h|--help ) print_help; exit ;;
      --usage       ) print_usage; exit ;;
      -*            ) lh_params unsupported "${1}" ;;
      *             ) args+=("${1}") ;;
    esac

    shift
  done

  [[ ${#args[@]} -gt 0 ]] && lh_params set CONFD "$(realpath -m -- "${args[0]}" 2>/dev/null)"
  [[ ${#args[@]} -lt 2 ]] || lh_params unsupported "${args[@]:1}"
}

_config_tmux_base_check_params() {
  lh_params is-blank CONFD && lh_params errbag "CONFD can't be blank"
}

config_tmux_create_confd_file() (
  declare dest="${1}"
  declare conf="${2}"
  declare confd; confd="$(lh_params get CONFD)"

  set -x
  umask -- "${INSTALLED_FILES_UMASK}"
  mkdir -p -- "${confd}" \
  && tee -- "${dest}" <<< "${conf}" >/dev/null
)

config_tmux_append_source_line() (
  declare source_line="${1}"
  declare -a tee_cmd_prefix=(tee -a --)
  declare -a tee_cmd=("${tee_cmd_prefix[@]}" "${HOME_DIR}/.tmux.conf")

  if is_user_privileged; then
    declare home; home="$(escape_single_quotes "${HOME_DIR}")"
    tee_cmd=(su -l "${SUDO_USER}" -c "umask 0077; ${tee_cmd_prefix[*]} '${home}/.tmux.conf'")
  fi

  grep -qFx -- "${source_line}" "${HOME_DIR}/.tmux.conf" 2>/dev/null \
  || printf -- '%s\n' "${source_line}" | (
    set -x; umask 0077; "${tee_cmd[@]}" >/dev/null
  )
)

# .LH_SOURCE:lib/lh-params.sh
# .LH_SOURCE:lib/system.sh
# .LH_SOURCE:lib/text.sh
