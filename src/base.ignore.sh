#!/usr/bin/env bash

# USAGE:
#   declare -A LH_DEFAULTS=([PARAM_NAME]=VALUE)
#   lh_params_apply_defaults
# If LH_PARAMS[PARAM_NAME] is not set, it gets the value from LH_DEFAULTS
lh_params_apply_defaults() {
  [[ "$(declare -p LH_PARAMS 2>/dev/null)" == "declare -A"* ]] || declare -Ag LH_PARAMS
  [[ "$(declare -p LH_DEFAULTS 2>/dev/null)" == "declare -A"* ]] || declare -Ag LH_DEFAULTS

  declare p_name; for p_name in "${!LH_DEFAULTS[@]}"; do
    [[ -n "${LH_PARAMS[${p_name}]+x}" ]] || LH_PARAMS["${p_name}"]="${LH_DEFAULTS[${p_name}]}"
  done
}

lh_params_reset() {
  unset LH_PARAMS LH_PARAMS_NOVAL
  declare -Ag LH_PARAMS
  declare -ag LH_PARAMS_NOVAL
}

# USAGE:
#   lh_param_set PARAM_NAME VALUE
# Produces global LH_PARAMS[PARAM_NAME]=VALUE.
# When VALUE is not provided returns 1 and puts PARAM_NAME to LH_PARAMS_NOVAL global array
lh_param_set() {
  declare name="${1}"

  [[ -n "${2+x}" ]] || { lh_params_noval "${name}"; return 1; }

  [[ "$(declare -p LH_PARAMS 2>/dev/null)" == "declare -A"* ]] || declare -Ag LH_PARAMS
  LH_PARAMS["${name}"]="${2}"
}

lh_params_noval() {
  [[ "$(declare -p LH_PARAMS_NOVAL 2>/dev/null)" == "declare -a"* ]] || {
    unset LH_PARAMS_NOVAL
    declare -ag LH_PARAMS_NOVAL
  }

  [[ ${#} -gt 0 ]] && { LH_PARAMS_NOVAL+=("${@}"); return; }

  [[ ${#LH_PARAMS_NOVAL[@]} -gt 0 ]] || return 1
  printf -- '%s\n' "${LH_PARAMS_NOVAL[@]}"
}

# shellcheck disable=SC2120
lh_params_unsupported() {
  [[ "$(declare -p LH_PARAMS_UNSUPPORTED 2>/dev/null)" == "declare -a"* ]] || {
    unset LH_PARAMS_UNSUPPORTED
    declare -ag LH_PARAMS_UNSUPPORTED
  }

  [[ ${#} -gt 0 ]] && { LH_PARAMS_UNSUPPORTED+=("${@}"); return; }

  [[ ${#LH_PARAMS_UNSUPPORTED[@]} -gt 0 ]] || return 1
  printf -- '%s\n' "${LH_PARAMS_UNSUPPORTED[@]}"
}

lh_params_flush_invalid() {
  declare -i rc=1

  # shellcheck disable=SC2119
  declare unsup; unsup="$(lh_params_unsupported)" && {
    echo "Unsupported params:"
    printf -- '%s\n' "${unsup}" | sed -e 's/^/* /'
    rc=0
  }

  # shellcheck disable=SC2119
  declare noval; noval="$(lh_params_noval)" && {
    echo "Values required for:"
    printf -- '%s\n' "${noval}" | sed -e 's/^/* /'
    rc=0
  }

  return ${rc}
}
