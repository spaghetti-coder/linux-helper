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

        _lh_hookstack() {
          '"$(printf -- '%s "${@}"\n' "${stack[@]}" | sed 's/^/,  /')"'
        }

        '"$(printf -- '%s\n' "${map[@]}" | sed 's/^/,/')"'

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
# .LH_SOURCED: {{ lib/basic.sh }}
# https://stackoverflow.com/a/2705678
escape_sed_expr()  { sed -e 's/[]\/$*.^[]/\\&/g' <<< "${1-$(cat)}"; }
escape_sed_repl()  { sed -e 's/[\/&]/\\&/g' <<< "${1-$(cat)}"; }

escape_single_quotes()  { declare str="${1-$(cat)}"; cat <<< "${str//\'/\'\\\'\'}"; }
escape_double_quotes()  { declare str="${1-$(cat)}"; cat <<< "${str//\"/\"\\\"\"}"; }

to_bool() {
  [[ "${1,,}" =~ ^(1|y|yes|true)$ ]] && { echo true; return; }
  [[ "${1,,}" =~ ^(0|n|no|false)$ ]] && { echo false; return; }
  return 1
}

# https://unix.stackexchange.com/a/194790
uniq_ordered() {
  cat -n <<< "${1-$(cat)}" | sort -k2 -k1n  | uniq -f1 | sort -nk1,1 | cut -f2-
}

template_compile() {
  # echo 'text {{ KEY1 }} more {{ KEY2 }} text' \
  # | template_compile [KEY1 VAL1]...

  declare -a expr filter=(cat)
  declare key val
  while [[ ${#} -gt 0 ]]; do
    [[ "${1}" == *'='* ]] && {
      key="${1%%=*}" val="${1#*=}"
      shift
    } || {
      key="${1}" val="${2}"
      shift 2
    }
    expr+=(-e 's/{{\s*'"$(escape_sed_expr "${key}")"'\s*}}/'"$(escape_sed_repl "${val}")"'/g')
  done

  [[ ${#expr[@]} -lt 1 ]] || filter=(sed "${expr[@]}")

  "${filter[@]}"
}
# .LH_SOURCED: {{/ lib/basic.sh }}
# .LH_SOURCED: {{ lib/lh-params.sh }}
lh_params() { lh_params_"${1//-/_}" "${@:2}"; }

lh_params_reset() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  declare vname vtype
  for vname in "${!_lh_params_map[@]}"; do
    unset "${vname}"
    declare -"${vtype}"g "${vname}"
  done
}

lh_params_set() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  [[ -n "${2+x}" ]] || { lh_params_noval "${1}"; return 1; }
  declare -f "lh_params_set_${1}" &>/dev/null && { "lh_params_set_${1}" "${2}"; return $?; }
  LH_PARAMS["${1}"]="${2}"
}

# lh_params_get NAME [DEFAULT]
#
# # Try to get $LH_PARAMS[NAME], fall back to invokation of lh_params_default_NAME,
# # then fallback to $LH_PARAMS_DEFAULTS[NAME] and if doesn't exist RC 1
# lh_params_get NAME
#
# # Try to get $LH_PARAMS[NAME], fall back to DEFAULT_VAL
# lh_params_get NAME DEFAULT_VAL
lh_params_get() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  [[ -n "${LH_PARAMS[${1}]+x}" ]] && { cat <<< "${LH_PARAMS[${1}]}"; return; }
  declare -F "lh_params_get_${1}" &>/dev/null && { "lh_params_get_${1}"; return; }
  [[ -n "${2+x}" ]] && { cat <<< "${2}"; return; }
  declare -F "lh_params_default_${1}" &>/dev/null && { "lh_params_default_${1}"; return; }
  [[ -n "${LH_PARAMS_DEFAULTS[${1}]+x}" ]] && { cat <<< "${LH_PARAMS_DEFAULTS[${1}]}"; return; }
  return 1
}

lh_params_is_blank() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  [[ -n "${LH_PARAMS[${1}]+x}" ]] && [[ -z "${LH_PARAMS[${1}]:+x}" ]]
}

lh_params_noval() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  # https://stackoverflow.com/a/13216833
  declare -a issues=("${@/%/ requires a value}")
  lh_params_errbag "${issues[@]}"
}

lh_params_unsupported() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  # https://stackoverflow.com/a/13216833
  declare -a issues=("${@/%/\' param is unsupported}")
  lh_params_errbag "${issues[@]/#/\'}"
}

lh_params_errbag() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  LH_PARAMS_ERRBAG+=("${@}")
}

# lh_params_defaults PARAM_NAME1='DEFAULT_VAL'...
lh_params_defaults() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  declare kv pname pval
  for kv in "${@}"; do
    kv="${kv}="
    pname="${kv%%=*}"
    pval="${kv#*=}"; pval="${pval::-1}"
    LH_PARAMS_DEFAULTS["${pname}"]="${pval}"
  done
}

lh_params_default_string() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  cat <<< "${LH_PARAMS_DEFAULTS[${1}]}"
}

lh_params_ask_config() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }

  declare pname ptext prev_comma=false
  for ptext in "${@}"; do
    [[ "${ptext}" == ',' ]] && { prev_comma=true; continue; }

    ${prev_comma} || [[ -z "${pname}" ]] && {
      pname="${ptext}"
      LH_PARAMS_ASK_PARAMS+=("${pname}")
      prev_comma=false
      continue
    }

    # Exclude ':*' adaptor suffix from pname
    LH_PARAMS_ASK["${pname%:*}"]+="${LH_PARAMS_ASK["${pname%:*}"]+$'\n'}${ptext}"
  done
}

lh_params_ask() {
  [[ -n "${LH_PARAMS_ASK_EXCLUDE+x}" ]] && {
    LH_PARAMS_ASK_EXCLUDE="$(
      # shellcheck disable=SC2001
      sed -e 's/^\s*//' -e 's/\s*$//' <<< "${LH_PARAMS_ASK_EXCLUDE}" \
      | grep -v '^$'
    )"
  }

  declare confirm pname question handler_id
  while ! ${confirm-false}; do
    for pname in "${LH_PARAMS_ASK_PARAMS[@]}"; do
      handler_id="$(
        set -o pipefail
        grep -o ':[^:]\+$' <<< "${pname}" | sed -e 's/^://'
      )" || handler_id=default
      pname="${pname%:*}"

      # Don't prompt for params in LH_PARAMS_ASK_EXCLUDE (text) list
      grep -qFx -- "${pname}" <<< "${LH_PARAMS_ASK_EXCLUDE}" && continue

      question="${LH_PARAMS_ASK[${pname}]}"
      "lh_params_ask_${handler_id}_handler" "${pname}" "${question}"
    done

    echo '============================' >&2

    confirm=nobool
    while ! to_bool "${confirm}" >/dev/null; do
      read -rp "YES (y) for proceeding or NO (n) to repeat: " confirm
      confirm="$(to_bool "${confirm}")"
    done
  done
}

lh_params_ask_default_handler() {
  declare pname="${1}"
  declare question="${2}"
  declare answer

  read -erp "${question}" -i "$(lh_params_get "${pname}")" answer
  lh_params_set "${pname}" "${answer}"
}

lh_params_ask_pass_handler() {
  declare pname="${1}"
  declare question="${2}"
  declare answer answer_repeat
  while :; do
    read -srp "${question}" answer
    echo >&2
    read -srp "Confirm ${question}" answer_repeat
    echo >&2

    [[ "${answer}" == "${answer_repeat}" ]] || {
      echo "Confirm value doesn't match! Try again" >&2
      continue
    }

    [[ -n "${answer}" ]] && lh_params_set "${pname}" "${answer}"
    break
  done
}

lh_params_ask_bool_handler() {
  declare pname="${1}"
  declare question="${2}"
  declare answer
  while :; do
    read -erp "${question}" -i "$(lh_params_get "${pname}")" answer

    answer="$(to_bool "${answer}")" || {
      echo "'${answer}' is not a valid boolean value! Try again" >&2
      continue
    }

    lh_params_set "${pname}" "${answer}"
    break
  done
}

lh_params_invalids() {
  declare -i rc=1

  [[ ${#LH_PARAMS_ERRBAG[@]} -lt 1 ]] || {
    echo "Issues:"
    printf -- '* %s\n' "${LH_PARAMS_ERRBAG[@]}"
    rc=0
  }

  return ${rc}
}

_lh_params_init() {
  declare -A _lh_params_map=(
    [LH_PARAMS]=A
    [LH_PARAMS_DEFAULTS]=A
    [LH_PARAMS_ASK]=A
    [LH_PARAMS_ASK_PARAMS]=a
    [LH_PARAMS_ERRBAG]=a
  )

  # Ensure global variables
  declare vname vtype
  for vname in "${!_lh_params_map[@]}"; do
    vtype="${_lh_params_map[${vname}]}"
    [[ "$(declare -p "${vname}" 2>/dev/null)" == "declare -${vtype}"* ]] && continue

    unset "${vname}"
    declare -"${vtype}"g "${vname}"
  done

  [[ "${FUNCNAME[1]}" != lh_params_* ]] || {
    unset vname vtype
    "${FUNCNAME[1]}" "${@}"
  }
}
# .LH_SOURCED: {{/ lib/lh-params.sh }}
