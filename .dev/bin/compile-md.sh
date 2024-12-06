#!/usr/bin/env bash

SELF="$(basename -- "${0}")"

PROJ_DIR="$(realpath -m --relative-to "$(pwd)" -- "$(dirname -- "${0}")/../..")"

SRC_DIR="${PROJ_DIR}/src"
DIST_DIR="${PROJ_DIR}/dist"

SRC_MD="${SRC_DIR}/README.md"
DEST_MD="${PROJ_DIR}/README.md"

BASE_RAW_URL=https://raw.githubusercontent.com/spaghetti-coder/linux-helper
BASE_RAW_URL_ALT=https://bitbucket.org/kvedenskii/linux-scripts/raw
BASE_VERSION=master

{
  declare deps
  declare cache_file="${PROJ_DIR}/.dev/cache/compile-md.deps.sh"

  if : \
    && deps="$(set -x; cat -- "${DIST_DIR}/partial/replace-marker.sh" 2>/dev/null)" \
    && deps+=$'\n'"$(set -x; cat -- "${DIST_DIR}/lib/basic.sh" 2>/dev/null)" \
    && deps+=$'\n'"$(set -x; cat -- "${DIST_DIR}/lib/text.sh" 2>/dev/null)" \
  ; then
    (set -x; tee -- "${cache_file}" <<< "${deps}" >/dev/null) || exit ${?}
  fi

  deps="$(set -x; cat -- "${cache_file}")" || exit ${?}

  # shellcheck disable=SC1090
  . <(cat <<< "${deps}")
}

echo "# ===== ${SELF}: compiling ${SRC_MD} => ${DEST_MD}" >&2

# shellcheck disable=SC2317
replace_help_cbk() {
  declare help; help="$(set -x; "${DIST_DIR}/${1}" --help)" || return $?

  REPLACEMENT=$'\n''**MAN:**'$'\n''~~~'$'\n'
  REPLACEMENT+="${help}"
  REPLACEMENT+=$'\n''~~~'$'\n'
}

# shellcheck disable=SC2317
# shellcheck disable=SC2016
replace_adhoc_cbk() {
  declare file; file="$(cut -d' ' -f1 <<< "${1} ")"
  declare params; params="$(cut -d' ' -f2- <<< "${1} " | text_trim)"

  if ${RAPLACE_ADHOC_USAGE:-false}; then
    params="$(set -o pipefail
      (set -x; "${DIST_DIR}/${1}" --usage) \
      | cut -d ' ' -f2- | text_ltrim | sed 's/^/,  /' | text_ltrim
    )" || return $?

    if [[ -n "${params}" ]]; then
      params=" \\"$'\n'"${params}"
    fi
  elif [[ -n "${params}" ]]; then
    params=" ${params}"
  fi

  REPLACEMENT=$'\n'"$(text_nice '
    **AD HOC:**
    ~~~sh
    # Review and change input params (after "bash -s --")
    # VERSION can be changed to any treeish
    (
   ,  VERSION='"'${BASE_VERSION}'"'
   ,  curl -V &>/dev/null && dl_tool=(curl -sL) || dl_tool=(wget -qO-)
   ,  set -x; "${dl_tool[@]}" "'"${BASE_RAW_URL}/\${VERSION:-master}/dist/${file}"'" \
   ,  || "${dl_tool[@]}" "'"${BASE_RAW_URL_ALT}/\${VERSION:-master}/dist/${file}"'"
    ) | bash -s --'"${params}"'
    ~~~
  ')"$'\n'
}

# shellcheck disable=SC2120
replace_base_raw_url() {
  declare url_repl; url_repl="$(escape_sed_repl "${BASE_RAW_URL}")"
  declare url_alt_repl; url_alt_repl="$(escape_sed_repl "${BASE_RAW_URL_ALT}")"

  # shellcheck disable=SC2001
  (set -x
    # First substitute less general placeholder
    sed -e 's/@@BASE_RAW_URL_ALT/'"${url_alt_repl}"'/g' \
        -e 's/@@BASE_RAW_URL/'"${url_repl}"'/g'
  )
}

RC=0

(
  set -o pipefail
  cat -- "${SRC_MD}" \
  | replace_marker '.LH_HELP:' replace_help_cbk '<!--' '-->' \
  | RAPLACE_ADHOC_USAGE=true replace_marker '.LH_ADHOC_USAGE:' replace_adhoc_cbk '<!--' '-->' \
  | RAPLACE_ADHOC_USAGE=false replace_marker '.LH_ADHOC:' replace_adhoc_cbk '<!--' '-->' \
  | replace_base_raw_url \
  | (set -x; tee -- "${DEST_MD}" >/dev/null)
) || RC=1

if [[ ${RC} -lt 1 ]]; then
  echo "# ===== ${SELF} OK" >&2
else
  echo "# ===== ${SELF} KO: something went wrong" >&2
fi

exit "${RC}"
