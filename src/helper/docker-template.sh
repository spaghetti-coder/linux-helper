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

# .LH_SOURCE:lib/basic.sh
# .LH_SOURCE:lib/system.sh

# .LH_NOSOURCE

(return &>/dev/null) || {
  docker_template main "${@}"
}
