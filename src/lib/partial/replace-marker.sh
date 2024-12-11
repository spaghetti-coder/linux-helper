#!/usr/bin/env bash

# cat FILE | get_marker_lines MARKER REPLACE_CBK [COMMENT_PREFIX] [COMMENT_SUFFIX]
replace_marker() {
  declare marker="${1}" \
          replace_cbk="${2}" \
          prefix \
          suffix
  declare content; content="$(cat)"

  [[ ${#} -gt 2 ]] && prefix="${3}"
  [[ ${#} -gt 3 ]] && suffix="${4}"

  declare marker_rex; marker_rex="$(escape_sed_expr "${marker}")"
  declare prefix_rex; prefix_rex="$(escape_sed_expr "${prefix}")"
  declare suffix_rex; suffix_rex="$(escape_sed_expr "${suffix}")"

  declare rex; rex="$(
    printf -- '\(\s*\)%s\s*%s\(.*\)%s\s*' \
      "${prefix_rex}" "${marker_rex}" "${suffix_rex}"
  )"

  declare -i RC=0

  declare line \
          number \
          offset \
          REPLACEMENT \
          arg
  while line="$(
    set -o pipefail
    grep -n -m 1 -- "^${rex}\$" <<< "${content}" \
    | sed -e 's/^\([0-9]\+:\)'"${rex}"'$/\1\2\3/' | text_rtrim
  )"; do
    # Explicitely remove REPLACEMENT VALUE
    REPLACEMENT=''

    number="${line%%:*}"
    line="${line#*:}"
    offset="$(grep -o '^\s*' <<< "${line}")"
    arg="$(text_ltrim "${line}")"

    "${replace_cbk}" "${arg}" || { RC=1; continue; }
    if [[ -n "${REPLACEMENT}" ]]; then
      # shellcheck disable=SC2001
      REPLACEMENT="$(sed -e 's/^/'"${offset}"'/' <<< "${REPLACEMENT}")"$'\n'
    fi

    content="$(
      printf -- '%s\n%s%s\n' \
        "$(head -n $((number - 1)) <<< "${content}")" \
        "${REPLACEMENT}" \
        "$(tail -n +$((number + 1)) <<< "${content}")"
    )"
  done

  printf -- '%s\n' "${content}"
  return ${RC}
}

# .LH_SOURCE:lib/basic.sh
# .LH_SOURCE:lib/text.sh

# .LH_NOSOURCE

if ! (return &>/dev/null); then
  # DEMO SECTION
  #
  # For another demo see src/bin/compile-bash-file.sh

  replace_callback() {
    # shellcheck disable=SC2034
    REPLACEMENT="$(tr ' ' '\n' <<< "${1}")"
  }

  echo '
    123
    <!-- .LH_SOURCE:1 2 3 -->
    ----
    <!-- .LH_SOURCE: -->
    ----
    <!-- .LH_SOURCE:45 -->
    ----
    <!-- .LH_SOURCE:67 8 -->
    9
  ' | replace_marker '.LH_SOURCE:' replace_callback '<!--' '-->'
fi
