#!/usr/bin/env bash

is_user_root() { [[ "$(id -u)" -eq 0 ]]; }
is_user_privileged() { is_user_root && [[ -n "${SUDO_USER}" ]]; }

privileged_user_home() { eval echo ~"${SUDO_USER}"; }

alias_home_in_path() {

  declare path="${1}" home="${2:-${HOME}}"
  declare home_rex; home_rex="$(escape_sed_expr "${home%/}")"

  # shellcheck disable=SC2001
  sed -e 's/^'"${home_rex}"'/~/' <<< "${path}"
}

is_port_valid() {
  grep -qx -- '[0-9]\+' <<< "${1}" \
  && [[ "${1}" -ge 0 ]] \
  && [[ "${1}" -le 65535 ]]
}

download_tool() {
  # USAGE:
  #   # Cache the download tool and use it
  #   declare -a DL_TOOL
  #   download_tool DL_TOOL
  #   "${DL_TOOL[@]}" https://google.com > google.txt
  #
  #   # Just use it to download
  #   download_tool https://google.com > google.txt

  declare _dt_the_url

  if [[ "${1}" == *'://'* ]]; then
    _dt_the_url="${1}"
    declare -a _dt_the_tool
  else
    # shellcheck disable=SC2178
    declare -n _dt_the_tool="${1}"
  fi

  { curl -V &>/dev/null && _dt_the_tool=(curl -fsSL --); } \
  || { wget -V &>/dev/null &&  _dt_the_tool=(wget -qO- --); } \
  || return

  if [[ -n "${_dt_the_url}" ]]; then
    (set -x; "${_dt_the_tool[@]}" "${_dt_the_url}")
  fi
}

# shellcheck disable=SC1090
detect_os_type() {
  # USAGE:
  #   detect_os_type || { ERR_BLOCK }
  # OUTPUT:
  #   OS_ID:VERSION_ID OS_ID_LIKE:VERSION_ID_LIKE
  # Where OS_ID_LIKE:VERSION_ID_LIKE is closest supported upstream
  # if OS_ID is not supported

  declare -a min_supported=(
    # Ordered by upstrem priority
    ubuntu:22.04
    debian:12
    centos:8
    rhel:8
    alpine:3.20
  )

  [[ -n "${1+x}" ]] && [[ -n "${2+x}" ]] && {
    # Check supported version, called in recursion

    declare id="${1}" vid="${2}"

    declare candidate; candidate="$(
      printf -- '%s\n' "${min_supported[@]}" | grep -x -m 1 -- "^${id}:.*"
    )"

    printf -- '%s\n' "${candidate}" "${id}:${vid}" \
    | sort -V | head -n 1 | grep -qFx "${candidate}"

    return $?
  }

  declare SELF; SELF="${FUNCNAME[0]}"
  declare OS_INFO; OS_INFO="$(cat /etc/os-release)" || {
    echo "(${SELF}) Can't detect OS TYPE" >&2
    return 1
  }

  declare id; id="$(. <(cat <<< "${OS_INFO}"); cat <<< "${ID,,}")"
  declare vid; vid="$(. <(cat <<< "${OS_INFO}"); cat <<< "${VERSION_ID}")"
  declare ID_VID="${id}:${vid}"

  if [[ " ${min_supported[*]}" == *" ${id}:"* ]]; then
    # Supported OS_ID

    "${SELF}" "${id}" "${vid}" && {
      echo "${ID_VID} ${ID_VID}"
      return 0
    }

    echo "(${SELF}) Unsupported ${id} version: '${vid}'" >&2
    return 1
  fi

  declare UPSTREAM_ID
  declare id_likes; id_likes="$(
    . <(cat <<< "${OS_INFO}")
    tr ' ' '\n' <<< "${ID_LIKE}" | grep '.\+'
  )" && UPSTREAM_ID="$(
    set -o pipefail

    printf -- '%s\n' "${min_supported[@]}" \
    | sed -e 's/^\([^:]\+\):.*/\1/' \
    | grep -Fxf <(printf -- '%s\n' "${id_likes}") \
    | head -n 1
  )" || {
    echo "(${SELF}) Unsupported OS: '${ID_VID}'" >&2
    return 1
  }

  declare UPSTREAM_VID
  if [[ 'centos' == "${UPSTREAM_ID}" ]]; then
    # Rely on same versioning as in upstream
    UPSTREAM_VID="${vid}"
  elif [[ 'ubuntu' == "${UPSTREAM_ID}" ]]; then
    # Attempt to convert code name to version
    declare -A map=(
      [jammy]=22.04
      [noble]=24.04
    )

    declare ubu_codename; ubu_codename="$(
      . <(cat <<< "${OS_INFO}")
      printf -- '%s\n' "${!map[@]}" | grep -Fx -m 1 -- "${UBUNTU_CODENAME}"
    )" && {
      UPSTREAM_VID="${map[${ubu_codename}]}"
    }
  fi

  "${SELF}" "${UPSTREAM_ID}" "${UPSTREAM_VID-0.0.0}" && {
    echo "${ID_VID} ${UPSTREAM_ID}:${UPSTREAM_VID}"
    return
  }

  echo "(${SELF}) Unsuported OS: ${ID_VID}" >&2
  return 1
}

# .LH_SOURCE:lib/basic.sh
