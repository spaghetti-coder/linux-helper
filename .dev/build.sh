#!/usr/bin/env bash

SELF="$(basename -- "${0}")"

SELF_DIR="$(realpath -m --relative-to "$(pwd)" -- "$(dirname -- "${0}")")"
PROJ_DIR="$(realpath -m --relative-to "$(pwd)" -- "${SELF_DIR}/..")"

SRC_DIR="${PROJ_DIR}/src"
DEST_DIR="${PROJ_DIR}/dist"

get_bash_compiler() {
  declare compiler

  if compiler="$(set -x; cat -- "${DEST_DIR}/short/compile-bash-project.sh")"; then
    (set -x; tee -- "${SELF_DIR}/cache/compile-bash-project.sh" <<< "${compiler}" >/dev/null) || return $?
  fi

  (set -x; cat -- "${SELF_DIR}/cache/compile-bash-project.sh")
}

RC=0

compiler="$(get_bash_compiler)" || exit $?
(set -x; rm -rf -- "${DEST_DIR}")
( set -o pipefail
  bash <(cat <<< "${compiler}") --no-ext '.ignore.sh' -- "${SRC_DIR}" "${DEST_DIR}"
) || RC=1

"${SELF_DIR}/bin/compile-md.sh" || RC=1

if [[ ${RC} -lt 1 ]]; then
  echo "# ===== ${SELF} OK"
else
  echo "# ===== ${SELF} KO: something went wrong"
fi

exit "${RC}"
