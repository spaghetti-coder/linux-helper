#!/usr/bin/env bash

SELF="$(basename -- "${0}")"

PROJ_DIR="$(realpath -m --relative-to "$(pwd)" -- "$(dirname -- "${0}")/../..")"

SRC_DIR="${PROJ_DIR}/src"
DIST_DIR="${PROJ_DIR}/dist"

SRC_MD="${SRC_DIR}/README.md"
DEST_MD="${PROJ_DIR}/README.md"

BASE_URL=https://raw.githubusercontent.com/spaghetti-coder/linux-helper
BASE_VERSION=master

{
  declare deps
  declare cache_file="${PROJ_DIR}/.dev/cache/compile-md-cache.sh"

  if : \
    && deps="$(set -x; cat -- "${DIST_DIR}/partial/replace-marker.sh" 2>/dev/null)" \
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
  declare params

  params="$(
    (set -x; "${DIST_DIR}/${1}" --help usage) \
    | cut -d ' ' -f2- | text_ltrim | sed 's/^/,  /' | text_ltrim
  )"
  if [[ -n "${params}" ]]; then
    params=" \\"$'\n'"${params}"
  fi

  REPLACEMENT=$'\n'"$(text_nice '
    **AD HOC:**
    ~~~sh
    # Review and change input params
    bash <(
   ,  # Can be changed to tag or commit ID
   ,  VERSION="'"${BASE_VERSION}"'"
   ,  curl -V &>/dev/null && tool=(curl -sL) || tool=(wget -qO-)
   ,  set -x; "${tool[@]}" "'"${BASE_URL}/\${VERSION}/dist/${file}"'"
    )'"${params}"'
    ~~~
  ')"$'\n'
}

RC=0

(
  set -o pipefail
  cat -- "${SRC_MD}" \
  | replace_marker '.LH_HELP:' replace_help_cbk '<!--' '-->' \
  | replace_marker '.LH_ADHOC:' replace_adhoc_cbk '<!--' '-->' \
  | (set -x; tee -- "${DEST_MD}" >/dev/null)
) || RC=1

if [[ ${RC} -lt 1 ]]; then
  echo "# ===== ${SELF} OK" >&2
else
  echo "# ===== ${SELF} KO: something went wrong" >&2
fi

exit "${RC}"
