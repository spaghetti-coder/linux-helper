#!/usr/bin/env bash

# shellcheck disable=SC2317
lxc_do() (
  # lxc_do CT_ID COMMAND [ARG...]

  declare SELF="${FUNCNAME[0]}"

  declare CONFFILE_SNAPSHOT_REX='^\s*\[.\+\]\s*'

  conffile_head() {
    # conffile_head || { ERR_BLOCK }

    ( set -o pipefail
      grep -m1 -B 9999 -- "${CONFFILE_SNAPSHOT_REX}" "${CT_CONFFILE}" 2>/dev/null \
      | head -n -1
    ) || cat -- "${CT_CONFFILE}" 2>/dev/null || {
      lh_params errbag "Can't read conffile '${CT_CONFFILE}'"
      return 1
    }
  }

  conffile_tail() {
    # conffile_tail || { ERR_BLOCK }

    ( set -o pipefail
      grep -m1 -A 9999 -- "${CONFFILE_SNAPSHOT_REX}" "${CT_CONFFILE}" \
      | head -n -1
    )

    [[ ${?} -lt 2 ]] || {
      lh_params errbag "Can't read conffile '${CT_CONFFILE}'"
      return 1
    }
  }

  ensure_confline() {
    # ensure_confline CONFLINE... || { ERR_BLOCK }

    declare head; head="$(conffile_head)" || return
    declare tail; tail="$(conffile_tail)" || return
    [[ -n "${tail}" ]] && tail=$'\n\n'"${tail}"

    declare rex changed=false
    declare line; for line in "${@}"; do
      line="$(sed -e 's/^\s*//' -e 's/\s*$//' <<< "${line}")"
      rex="$(_confline_to_match_rex "${line}")"

      (set -x; grep -qx -- "${rex}" <<< "${head}") || {
        [[ ${?} -lt 2 ]] || return
        head+="${head+$'\n'}${line}"
        changed=true
      }
    done

    ! ${changed} && return

    printf -- '%s%s\n' "${head}" "${tail}" | (
      set -x; tee -- "${CT_CONFFILE}" >/dev/null
    )
  }

  ensure_no_confline() {
    # ensure_confline CONFLINE... || { ERR_BLOCK }

    declare head; head="$(conffile_head)" || return
    declare tail; tail="$(conffile_tail)" || return
    [[ -n "${tail}" ]] && tail=$'\n\n'"${tail}"

    declare rex_file
    declare line; for line in "${@}"; do
      rex_file+="${rex_file:+$'\n'}$(_confline_to_match_rex "${line}")"
    done

    [[ -z "${rex_file}" ]] && return

    head="$(grep -vxf <(cat <<< "${rex_file}") <<< "${head}")"

    printf -- '%s%s\n' "${head}" "${tail}" | (
      set -x; tee -- "${CT_CONFFILE}" >/dev/null
    )
  }

  ensure_dev() {
    # ensure_dev DEV_LINE... || { ERR_BLOCK }
    # ensure_dev '/dev/dri/renderD128,gid=104'

    declare rc=0

    declare head; head="$(conffile_head)" || return

    declare -a allowed_nums
    declare tmp; tmp="$(_allowed_device_nums dev)" \
    && mapfile -t allowed_nums <<< "${tmp}"

    declare -a add_devs
    declare dev rex dev_num ctr=0
    declare line; for line in "${@}"; do
      line="$(sed -e 's/^\s*//' -e 's/\s*$//' <<< "${line}")"
      dev="$(cut -d, -f1 <<< "${line},")"

      rex='\s*dev[0-9]\+[:=]\s*'"$(escape_sed_expr "${dev}")"'\(,.*\)\?\s*'
      (grep -qxe "${rex}" <<< "${head}") && continue

      dev_num="${allowed_nums[${ctr}]}"
      [[ -n "${dev_num}" ]] || {
        rc=$?
        lh_params errbag "No slot for dev '${line}'"
        continue
      }

      add_devs+=("dev${dev_num}: ${line}")
      (( ctr++ ))
    done

    ensure_confline "${add_devs[@]}" || rc=$?
    return "${rc}"
  }

  ensure_nodev() {
    # ensure_nodev DEV_PATH... || { ERR_BLOCK }
    # ensure_nodev '/dev/dri/renderD128'

    declare rex_file
    declare dev; for dev in "${@}"; do
      rex_file+="${rex_file:+$'\n'}"'\s*dev[0-9]\+:\s*'"$(escape_sed_expr "${dev}")"'\(,.\+\)\?\s*'
    done

    [[ -z "${rex_file}" ]] && return

    declare head; head="$(conffile_head)" || return
    declare -a nodevs
    mapfile -t nodevs <<< "$(grep -xf <(cat <<< "${rex_file}") <<< "${head}")"

    ensure_no_confline "${nodevs[@]}"
  }

  ensure_mount() {
    # ensure_mount MP_LINE... || { ERR_BLOCK }
    # ensure_mount '/host/dir,mp=/ct/mountpoint,mountoptions=noatime,replicate=0,backup=0'

    declare -i rc=0

    declare head; head="$(conffile_head)" || return

    declare -a allowed_nums
    declare tmp; tmp="$(_allowed_device_nums dev)" \
    && mapfile -t allowed_nums <<< "${tmp}"

    declare -a add_mps
    declare volume mp mp_rex=',mp=[^,]\+'
    declare rex1 rex2 mp_num ctr=0
    declare line; for line in "${@}"; do
      line="$(sed -e 's/^\s*//' -e 's/\s*$//' <<< "${line}")"
      volume="$(cut -d, -f1 <<< "${line},")"
      mp="$(
        set -o pipefail
        grep -o -- "${mp_rex}" <<< "${line}"
      )" || {
        rc=$?
        lh_params errbag "No mount point 'mp=' detected in '${line}'"
        continue
      }

      rex1='^\s*mp[0-9]\+[:=]\s*'"$(escape_sed_expr "${volume}"),"
      rex2="$(escape_sed_expr "${mp}")"
      (grep -e "${rex1}" <<< "${head}" | grep -qe "${rex2}") && continue

      mp_num="${allowed_nums[${ctr}]}"
      [[ -n "${mp_num}" ]] || {
        rc=$?
        lh_params errbag "No slot for mp '${line}'"
        continue
      }

      add_mps+=("mp${mp_num}: ${line}")
      (( ctr++ ))
    done

    ensure_confline "${add_mps[@]}" || rc=$?
    return "${rc}"
  }

  ensure_umount() {
    # ensure_mount CT_MP... || { ERR_BLOCK }
    # ensure_mount /ct/mountpoint

    declare rex_file
    declare mp; for mp in "${@}"; do
      rex_file+="${rex_file:+$'\n'}"'\s*mp[0-9]\+:.*,mp='"$(escape_sed_expr "${mp}")"'\(,.\+\)\?\s*'
    done

    [[ -z "${rex_file}" ]] && return

    declare head; head="$(conffile_head)" || return
    declare -a umounts
    mapfile -t umounts <<< "$(grep -xf <(cat <<< "${rex_file}") <<< "${head}")"

    ensure_no_confline "${umounts[@]}"
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

    declare cbk="${1}"; shift
    declare -a args

    declare arg; for arg in "${@}"; do
      args+=("'$(escape_single_quotes "${arg}")'")
    done

    declare cmd
    cmd="$(declare -f "${cbk}")" || return
    cmd+="${cmd:+$'\n'}${cbk}"
    [[ ${#args[@]} -lt 1 ]] || cmd+=' '
    cmd+="${args[*]}"

    # Attempt to install bash if not installed
    lxc-attach -n "${CT_ID}" -- bash -c true 2>/dev/null
    [[ $? == 127 ]] && (
      set -x
      lxc-attach -n "${CT_ID}" -- /bin/sh -c \
        'apk add --update --no-cache bash 2>/dev/null'
    )
    [[ $? == 127 ]] && (
      set -x
      lxc-attach -n "${CT_ID}" -- /bin/sh -c \
        'dnf install -y bash 2>/dev/null'
    )
    [[ $? == 127 ]] && (
      set -x
      lxc-attach -n "${CT_ID}" -- /bin/sh -c \
        '(apt-get --version && apt-get update && apt-get install -y bash) >/dev/null'
    )

    ("${prefix[@]}"; lxc-attach -n "${CT_ID}" -- bash -c -- "${cmd}")
  }

  get_uptime() (
    # get_uptime

    lxc-attach -n "${CT_ID}" -- /bin/sh -c '
      grep -o '^[0-9]\+' /proc/uptime 2>/dev/null
    ' || echo 0
  )

  hookscript() {
    # ensure_hook [FUNC...] || { ERR_BLOCK }
    # test() { declare CT_ID="${1}" PHASE="${2}"; echo "${CT_ID} ${PHASE}" >&2; }
    # ensure_hook test
    #
    # Hookscript info:
    #   https://codingpackets.com/blog/proxmox-hook-script-port-mirror/#hook-scripts

    declare -a stack
    declare -A map
    declare f; for f in "${@}"; do
      map["${f}"]="$(declare -f -- "${f}")" || return
      stack+=("${f}")
    done

    [[ ${#stack[@]} -lt 1 ]] && return

    declare inc_file; inc_file="$(
      # shellcheck disable=SC2016
      text_nice '
        # $1 contains CT_ID
        # $2 contains the container execution phase, one of:
        #   * pre-start
        #   * post-start
        #   * pre-stop
        #   * post-stop
        # More on the subject:
        #   https://codingpackets.com/blog/proxmox-hook-script-port-mirror/#hook-scripts
       ,
        _lh_hookstack() {
          '"$(printf -- '%s "${@}"\n' "${stack[@]}" | sed 's/^/,  /')"'
        }
       ,
        '"$(printf -- '%s\n' "${map[@]}" | sed 's/^/,/')"'
       ,
        _lh_hookstack "${@}"
      '
    )"

    declare storage_path; storage_path="$(_storage_path)/hookscript"

    declare INC_PATH="${storage_path}/${CT_ID}.lh-inc.sh"
    declare HOOK_PATH="/var/lib/vz/snippets/${CT_ID}.hook.sh"

    # Create inc file
    ( cat <<< "${inc_file}" | {
      set -x

      mkdir -p "${storage_path}" \
      && tee -- "${INC_PATH}" >/dev/null
    }) || return

    # Ensure shebanged hook file
    declare hook_shebang='#!/usr/bin/env bash'
    head -n 1 -- "${HOOK_PATH}" 2>/dev/null | grep -qFx -- "${hook_shebang}" || (
      declare tail; tail="$(tail -n +2 "${HOOK_PATH}" 2>/dev/null)"
      set -x
      tee -- "${HOOK_PATH}" <<< "${hook_shebang}${tail:+$'\n'}${tail}" >/dev/null
    ) || return

    # Ensure hook file is executable
    (set -x; chmod +x -- "${HOOK_PATH}") || return

    # Ensure inc file sourced
    declare inc_rex; inc_rex='\s*\.\s\+'"$(escape_sed_expr "'${INC_PATH}'")"'\s*'
    grep -qx -- "${inc_rex}"'\s*' "${HOOK_PATH}" || (
      declare hook_fname; hook_fname="$(basename -- "${HOOK_PATH}")"
      set -x
      tee -a -- "${HOOK_PATH}" <<< ". '${INC_PATH}'" >/dev/null \
      && pct set "${CT_ID}" --hookscript "local:snippets/${hook_fname}"
    ) || return
  }

  is_down() {
    # is_down && { IS_DOWN_BLOCK } || { IS_UP_BLOCK }

    pct status "${CT_ID}" | grep -q ' stopped$'
  }

  is_up() {
    # is_up && { IS_UP_BLOCK } || { IS_DOWN_BLOCK }

    pct status "${CT_ID}" | grep -q ' running$'
  }

  _allowed_device_nums() {
    declare device_name="${1}"
    declare head; head="$(conffile_head)" || return

    declare busy_nums; busy_nums="$(
      grep -o "^${device_name}[0-9]\+:" <<< "${head}" \
      | sed -e "s/^${device_name}//" -e 's/:$//' | sort -n
    )"
    grep -vFxf <(echo "${busy_nums}") <<< "$(seq 0 255)"
  }

  _confline_to_match_rex() {
    declare line="${1}" opt val
    line="$(sed -e 's/^\s*//' -e 's/\s*$//' <<< "${line}")"
    opt="$(cut -d: -f1 <<< "${line}:")"
    val="$(cut -d: -f2- <<< "${line}:" | sed -e 's/^\s*//' -e 's/:$//')"
    echo '\s*'"$(escape_sed_expr "${opt}")"'\s*[:=]\s*'"$(escape_sed_expr "${val}")"'\s*'
  }

  _storage_path() {
    echo /root/linux-helper/lxc
  }

  # ^^^^^^^^^ #
  # FUNCTIONS #
  #############

  declare -ar EXPORTS=(
    conffile_head
    conffile_tail
    ensure_confline
    ensure_no_confline
    ensure_dev
    ensure_nodev
    ensure_mount
    ensure_umount
    ensure_down
    ensure_up
    exec_cbk
    get_uptime
    hookscript
    is_down
    is_up
  )

  declare -r CT_ID="${1}"; shift
  declare -r CT_CONFFILE="/etc/pve/lxc/${CT_ID}.conf"

  if [[ -z "${CT_ID:+x}" ]]; then
    lh_params errbag "CT_ID is required, and can't be empty"; lh_params invalids >&2 && {
      echo "FATAL (${SELF})" >&2
      return 1
    }
  fi

  # shellcheck disable=SC2015
  if ! printf -- '%s\n' "${EXPORTS[@]}" | grep -qFx -- "${1//-/_}"; then
    lh_params unsupported "${1}"
  else
    "${1//-/_}" "${@:2}"
  fi
  declare -i RC=$?

  ! lh_params invalids >&2 || {
    RC=$?
    echo "FATAL (${SELF})" >&2
  }

  return ${RC}
)

# .LH_SOURCE:lib/basic.sh
# .LH_SOURCE:lib/lh-params.sh
