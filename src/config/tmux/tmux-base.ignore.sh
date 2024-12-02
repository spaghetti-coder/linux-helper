#!/usr/bin/env bash

# .LH_SOURCE:lib/system.sh
# .LH_SOURCE:lib/text.sh
# .LH_SOURCE:base.ignore.sh

config_tmux_base() {
  declare SELF="${FUNCNAME[0]}"

  HOME_DIR="${HOME}"
  INSTALLED_FILES_UMASK=0077
  CONFD_ALIAS=""

  if is_user_privileged; then
    HOME_DIR="$(privileged_user_home)"
    INSTALLED_FILES_UMASK=0022
  fi

  # shellcheck disable=SC2034
  declare -A LH_DEFAULTS=(
    [CONFD]="${HOME_DIR}/.tmux"
  )

  declare -a args
  declare endopts=false
  declare param
  while [[ ${#} -gt 0 ]]; do
    ${endopts} && param='*' || param="${1}"

    case "${param}" in
      --            ) endopts=true ;;
      -\?|-h|--help ) print_help; exit ;;
      --usage       ) print_help_usage | text_nice; exit ;;
      -*            ) lh_params_unsupported "${1}" ;;
      *             ) args+=("${1}") ;;
    esac

    shift
  done

  [[ ${#args[@]} -gt 0 ]] && lh_param_set CONFD "${args[0]}"
  [[ ${#args[@]} -lt 2 ]] || lh_params_unsupported "${args[@]:1}"

  lh_params_apply_defaults

  lh_params_flush_invalid >&2 && {
    echo "FATAL (${SELF})" >&2
    return 1
  }

  LH_PARAMS[CONFD]="$(realpath -m -- "${LH_PARAMS[CONFD]}")"
  CONFD_ALIAS="$(alias_home_in_path "${LH_PARAMS[CONFD]}")"
}

config_tmux_create_confd_file() (
  declare dest="${1}"
  declare conf="${2}"

  set -x
  umask -- "${INSTALLED_FILES_UMASK}"
  mkdir -p -- "${LH_PARAMS[CONFD]}" \
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
