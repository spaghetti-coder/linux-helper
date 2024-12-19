#!/usr/bin/env bash

# shellcheck disable=SC2317
lxc_do() (
  # lxc_do CT_ID COMMAND [ARG...]

  declare SELF="${FUNCNAME[0]}"

  ensure_confline() {
    # ensure_confline CONFLINE... || { ERR_BLOCK }

    declare conffile="/etc/pve/lxc/${CT_ID}.conf"

    declare opt val rex add_lines
    declare line; for line in "${@}"; do
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

  ensure_down() {
    # ensure_down || { ERR_BLOCK }

    if ! is_down; then
      (set -x; pct shutdown "${CT_ID}")
    fi
  }

  ensure_up() {
    # ensure_up [WARMUP_SEC=5] || { ERR_BLOCK }

    declare warm="${1-5}"

    if ! is_up; then
      (set -x; pct start "${CT_ID}") || return
      (set -x; lxc-wait "${CT_ID}" --state="RUNNING" -t 10)
    fi

    # Give it time to warm up the services
    warm="$(( warm - "$(get_uptime)" ))"
    if [[ "${warm}" -gt 0 ]]; then (set -x; sleep "${warm}" ); fi
  }

  exec_cbk() {
    # exec_cbk [-v|--verbose] FUNCNAME [ARG...] || { ERR_BLOCK }

    declare -a prefix=(true)

    [[ "${1}" =~ ^(-v|--verbose)$ ]] && { prefix=(set -x); shift; }

    declare cbk="${1}"
    declare -a args

    declare arg; for arg in "${@:2}"; do
      args+=("'$(escape_single_quotes "${arg}")'")
    done

    declare cmd
    cmd="$(declare -f "${cbk}")" || return
    cmd+="${cmd:+$'\n'}${cbk}"
    [[ ${#args[@]} -lt 1 ]] || cmd+=' '
    cmd+="${args[*]}"

    # Attempt to install bash if not installed
    lxc-attach -n "${CT_ID}" -- bash -c true
    [[ $? == 127 ]] && (
      set -x
      lxc-attach -n "${CT_ID}" -- /bin/sh -c \
        'apk add --update --no-cache bash' 2>/dev/null
    )
    [[ $? == 127 ]] && (
      set -x
      lxc-attach -n "${CT_ID}" -- /bin/sh -c \
        'dnf install -y bash' 2>/dev/null
    )
    [[ $? == 127 ]] && (
      set -x
      lxc-attach -n "${CT_ID}" -- /bin/sh -c \
        'apt-get --version && apt-get update && apt-get install -y bash' 2>/dev/null
    )

    ("${prefix[@]}"; lxc-attach -n "${CT_ID}" -- bash -c -- "${cmd}")
  }

  get_uptime() (
    # get_uptime

    _get_uptime() { grep -o "^[0-9]\\+" /proc/uptime 2>/dev/null || echo 0; }
    exec_cbk _get_uptime
  )

  is_down() {
    # is_down && { IS_DOWN_BLOCK } || { IS_UP_BLOCK }

    pct status "${CT_ID}" | grep -q ' stopped$'
  }

  is_up() {
    # is_up && { IS_UP_BLOCK } || { IS_DOWN_BLOCK }

    pct status "${CT_ID}" | grep -q ' running$'
  }

  # ^^^^^^^^^ #
  # FUNCTIONS #
  #############

  declare -ar EXPORTS=(
    ensure_confline
    ensure_down
    ensure_up
    exec_cbk
    get_uptime
    is_down
    is_up
  )

  declare -r CT_ID="${1}"; shift
  if [[ -z "${CT_ID:+x}" ]]; then
    lh_params errbag "CT_ID is required, and can't be empty"; lh_params invalids >&2 && {
      echo "FATAL (${SELF})" >&2
      return 1
    }
  fi

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
# .LH_SOURCE:lib/lh-params.sh
