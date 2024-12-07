#!/usr/bin/env bash

lh_params_reset() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { "${FUNCNAME[1]}" "${@}"; return $?; }
  declare vname vtype
  for vname in "${!_lh_params_map[@]}"; do
    unset "${vname}"
    declare -"${vtype}"g "${vname}"
  done
}

lh_params_set() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { "${FUNCNAME[1]}" "${@}"; return $?; }
  [[ -n "${2+x}" ]] || { lh_params_noval "${1}"; return 1; }
  # shellcheck disable=SC2034
  LH_PARAMS["${1}"]="${2}"
}

lh_params_noval() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { "${FUNCNAME[1]}" "${@}"; return $?; }
  LH_PARAMS_NOVAL+=("${@}")
}

lh_params_unsupported() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  LH_PARAMS_UNSUPPORTED+=("${@}")
}

_lh_params_init() {
  [[ "${FUNCNAME[1]}" != lh_params_* ]] && return

  declare -A _lh_params_map=(
    [LH_PARAMS]=A
    [LH_PARAMS_DEFAULTS]=A
    [LH_PARAMS_NOVAL]=a
    [LH_PARAMS_UNSUPPORTED]=a
  )

  # Ensure global variables
  declare vname vtype
  for vname in "${!_lh_params_map[@]}"; do
    [[ "$(declare -p "${vname}" 2>/dev/null)" == "declare -${vtype}"* ]] && continue

    unset "${vname}"
    declare -"${vtype}"g "${vname}"
  done

  unset vname vtype

  "${FUNCNAME[1]}" "${@}"
}
