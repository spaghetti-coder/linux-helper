#!/usr/bin/env bash

# shellcheck disable=SC2317
docker_template() (
  declare -a TPL_IDS
  declare -a TPL_ARGS
  declare COMPOSE_FILE
  declare TPL_VARS TPL_LISTS TPL_OBJS
  declare -a RM_VARS
  declare -A KV_VARS KV_LISTS KV_OBJS

  parse_args() {
    declare tpl_end=false
    declare p; for p in "${@}"; do
      [[ "${p:0:1}" == '@' ]] && ! ${tpl_end} && {
        TPL_IDS+=("${p:1}"); continue
      }

      tpl_end=true
      TPL_ARGS+=("${p}"); continue
    done
  }

  dl_templates() {
    declare -a dl_tool; download_tool dl_tool

    declare base_url="${DOCKER_TAMPLATE_BASE_URL-https://github.com/spaghetti-coder/linux-helper/raw/master/src/asset/docker}"
    declare tpl_url ctr=0
    declare tpl; for tpl in "${TPL_IDS[@]}"; do
      tpl_url="${base_url}/docker-compose.${tpl}.tpl.yaml"
      tpl="$(set -x; "${dl_tool[@]}" "${tpl_url}")" || {
        echo "(${FUNCNAME[0]}) Can't download ${tpl_url}" >&2
        return 1
      }

      (( ctr++ ))

      if [[ ${ctr} -gt 1 ]]; then
        # https://superuser.com/a/1092811
        tpl="$(sed -e '0,/^---\s*$/{//d}' -e '0,/^services:\s*$/{//d}' <<< "${tpl}")"
      fi

      COMPOSE_FILE+="${COMPOSE_FILE:+$'\n\n'}${tpl}"
    done
  }

  detect_tpl_vars_types() {
    declare all; all="$(
      grep -o -e '{{\s*.\+\s*}}' <<< "${COMPOSE_FILE}" \
      | sed -e 's/^{{\s*//' -e 's/\s*}}$//'
    )"

    TPL_LISTS="$( set -o pipefail
      declare rex='\[\s*\(.\+\)\s*\]'
      grep -x "${rex}" <<< "${all}" \
      | sed -e 's/^'"${rex}"'$/\1/'
    )" && mapfile -t TPL_LISTS <<< "${TPL_LISTS}" || TPL_LISTS=()

    TPL_OBJS="$( set -o pipefail
      declare rex='{\s*\(.\+\)\s*}'
      grep -x "${rex}" <<< "${all}" \
      | sed -e 's/^'"${rex}"'$/\1/'
    )" && mapfile -t TPL_OBJS <<< "${TPL_OBJS}" || TPL_OBJS=()

    TPL_VARS="$( set -o pipefail
      declare rex='\([^{\[].*[^{\[]\?\)'
      grep -x "${rex}" <<< "${all}" \
      | sed -e 's/^'"${rex}"'$/\1/'
    )" && mapfile -t TPL_VARS <<< "${TPL_VARS}" || TPL_VARS=()
  }

  collect_defaults() {
    declare rex_file; rex_file="$(
      printf -- '#\\s*%s=.*\n' "${TPL_VARS[@]}"
    )"
    declare defaults; defaults="$( set -o pipefail
      grep -xf <(echo "${rex_file}") <<< "${COMPOSE_FILE}" \
      | sed -e 's/^#\s*//' -e 's/^\s*$//'
    )" && mapfile -t defaults <<< "${defaults}" || defaults=()

    declare d; for d in "${defaults[@]}"; do
      KV_VARS["${d%%=*}"]="${d#*=}"
    done

    # Clean comment-defaults
    COMPOSE_FILE="$(
      grep -vxf <(echo "${rex_file}") <<< "${COMPOSE_FILE}" \
      | grep -vx '#\s*'
    )"
  }

  merge_args() {
    TPL_ARGS=()

    declare key val obj_val
    while [[ $# -gt 0 ]]; do
      key="${1}"; shift

      if [[ "${key:0:1}" == '-' ]]; then
        RM_VARS+=("${key:1}")
        continue
      fi

      if [[ "${key}" == *'='* ]]; then
        val="${key#*=}"; key="${key%%=*}"
      else
        val="${1}"; shift
      fi

      if [[ " ${TPL_VARS[*]} " == *" ${key} "* ]]; then
        KV_VARS["${key}"]="${val}"
      elif [[ " ${TPL_LISTS[*]} " == *" ${key} "* ]]; then
        KV_LISTS["${key}"]+="${KV_LISTS[${key}]+$'\n'}- $(
          # shellcheck disable=SC2001
          sed -e '2,$s/^/  /' <<< "${val}"
        )"
      elif [[ " ${TPL_OBJS[*]} " == *" ${key} "* ]]; then
        if [[ "${val}" == *'='* ]]; then
          obj_val="${val#*=}"; val="${val%%=*}"
        else
          obj_val="${1}"; shift
        fi

        KV_OBJS["${key}"]+="${KV_OBJS[${key}]+$'\n'}${val}: $(
          # shellcheck disable=SC2001
          sed -e '2,$s/^/  /' <<< "${obj_val}"
        )"
      fi
    done
  }

  process_vars() {
    declare -a rm_filter=(cat) rm_filter_args
    declare rm_var; for rm_var in "${RM_VARS[@]}"; do
      rm_filter=(sed)
      rm_filter_args+=(-e '/{{\s*'"$(escape_sed_expr "${rm_var}")"'\s*}}/d')
    done

    declare -a compile_args
    declare key; for key in "${!KV_VARS[@]}"; do
      compile_args+=("${key}" "${KV_VARS[${key}]}")
    done

    "${rm_filter[@]}" "${rm_filter_args[@]}" \
    | template_compile "${compile_args[@]}"
  }

  process_lists() {
    declare file; file="$(cat)"

    declare list_line
    declare line_no offset replacement
    declare name; for name in "${TPL_LISTS[@]}"; do
      replacement=''
      [[ -n "${KV_LISTS[${name}]}" ]] && replacement="${KV_LISTS[${name}]}"

      while list_line="$(
        grep -n '^\s*#\s*{{\s*\[\s*'"$(escape_sed_expr "${name}")"'\s*\]\s*}}' <<< "${file}"
      )"; do
        line_no="${list_line%%:*}"
        list_line="${list_line#*:}"
        offset="$(grep -o '^\s*' <<< "${list_line}")"

        file="$(
          head -n "$(( line_no - 1 ))" <<< "${file}"
          # shellcheck disable=SC2001
          [[ -n "${replacement}" ]] && sed -e 's/^/'"${offset}"'/' <<< "${replacement}"
          tail -n +"$(( line_no + 1 ))" <<< "${file}"
        )"
      done
    done

    cat <<< "${file}"
  }

  process_objs() {
    declare file; file="$(cat)"

    declare obj_line
    declare line_no offset replacement
    declare name; for name in "${TPL_OBJS[@]}"; do
      replacement=''
      [[ -n "${KV_OBJS[${name}]}" ]] && replacement="${KV_OBJS[${name}]}"

      while obj_line="$(
        grep -n '^\s*#\s*{{\s*{\s*'"$(escape_sed_expr "${name}")"'\s*}\s*}}' <<< "${file}"
      )"; do
        line_no="${obj_line%%:*}"
        obj_line="${obj_line#*:}"
        offset="$(grep -o '^\s*' <<< "${obj_line}")"

        file="$(
          head -n "$(( line_no - 1 ))" <<< "${file}"
          # shellcheck disable=SC2001
          [[ -n "${replacement}" ]] && sed -e 's/^/'"${offset}"'/' <<< "${replacement}"
          tail -n +"$(( line_no + 1 ))" <<< "${file}"
        )"
      done
    done

    cat <<< "${file}"
  }

  main() {
    parse_args "${@}"
    [[ "${#TPL_IDS[@]}" -lt 1 ]] && return
    dl_templates || return
    detect_tpl_vars_types
    collect_defaults
    merge_args "${TPL_ARGS[@]}"

    process_vars <<< "${COMPOSE_FILE}" \
    | process_lists | process_objs
  }

  declare -ar EXPORTS=(
    main
  )

  # shellcheck disable=SC2015
  if printf -- '%s\n' "${EXPORTS[@]}" | grep -qFx -- "${1//-/_}"; then
    "${1//-/_}" "${@:2}"
  fi
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
# .LH_SOURCED: {{ lib/system.sh }}
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
# .LH_SOURCED: {{/ lib/system.sh }}

# .LH_NOSOURCE

(return &>/dev/null) || {
  docker_template main "${@}"
}
