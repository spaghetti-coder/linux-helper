#!/usr/bin/env bash

# shellcheck disable=SC2317
lxc_do() (
  declare SELF="${FUNCNAME[0]}"

  # add_confline CT_ID CONFLINE... || { ERR_BLOCK }
  ensure_confline() {
    declare -r ct_id="${1}"
    declare -a conflines=("${@:2}")
    declare conffile="/etc/pve/lxc/${ct_id}.conf"

    declare opt val rex add_lines
    declare line; for line in "${conflines[@]}"; do
      line="$(sed -e 's/^\s*//' -e 's/\s*$//' <<< "${line}")"
      opt="$(cut -d: -f1 <<< "${line}:")"
      val="$(cut -d: -f2- <<< "${line}:" | sed -e 's/^\s*//' -e 's/:$//')"
      rex="\s*$(escape_sed_expr "${opt}")\s*[:=]\s*$(escape_sed_expr "${val}")\s*"

      (set -x; grep -qx -- "${rex}" "${conffile}") || {
        [[ ${?} -lt 2 ]] || return
        add_lines+="${add_lines+$'\n'}${line}"
      }
    done

    printf -- '%s\n' "${add_lines}" | (set -x; tee -a -- "${conffile}" >/dev/null)
  }

  declare EXPORTS=(
    ensure_confline
  )

  # shellcheck disable=SC2015
  if printf -- '%s\n' "${EXPORTS[@]}" | grep -qFx -- "${1//-/_}"; then
    "${1//-/_}" "${@:2}"
  else
    lh_params unsupported "${1}"; lh_params invalids >&2 && {
      echo "FATAL (${SELF})" >&2
      return 1
    }
  fi
)

# .LH_SOURCE:lib/basic.sh
