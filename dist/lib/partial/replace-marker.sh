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
# .LH_SOURCED: {{ lib/text.sh }}
# shellcheck disable=SC2001
# shellcheck disable=SC2120
text_ltrim() { sed -e 's/^\s\+//' <<< "${1-$(cat)}"; }
text_rtrim() { sed -e 's/\s\+$//' <<< "${1-$(cat)}"; }
text_trim() { text_ltrim <<< "${1-$(cat)}" | text_rtrim; }
text_rmblank() { grep -v '^\s*$' <<< "${1-$(cat)}"; return 0; }
text_nice() { text_trim <<< "${1-$(cat)}" | text_rmblank | sed -e 's/^,//'; }
# .LH_SOURCED: {{/ lib/text.sh }}

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
