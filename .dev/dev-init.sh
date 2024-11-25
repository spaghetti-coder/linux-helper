#!/usr/bin/env bash


hooks_install() {
  declare CUSTOM_HOOK_VERSION=2.9
  declare CUSTOM_HOOK_VERSION_REX='2\.9'

  declare SCRIPT_DIR; SCRIPT_DIR="$(dirname -- "$(realpath --relative-to="$(pwd)" -- "${0}")")"
  declare PROJ_DIR; PROJ_DIR="$(dirname -- "${SCRIPT_DIR}")"

  declare CUSTOM_HOOKS_PATH='.dev/git-hooks'

  if git --version | grep -o '\([0-9]\+\.\)\+[0-9]\+' | {
      printf -- '%s\n' "${CUSTOM_HOOK_VERSION}"
      cat
    } | sort -V | tail -n 1 \
    | grep -q '^'"${CUSTOM_HOOK_VERSION_REX}"'$' \
  ; then
    # Legacy hook installation

    (
      set -x
      cd "${PROJ_DIR}/.git/hooks" || exit
      ln -fs "./../../${CUSTOM_HOOKS_PATH}"/* ./ || exit
    )

    return $?
  fi

  (
    set -x
    cd "${PROJ_DIR}" || exit
    git config --local core.hooksPath "${CUSTOM_HOOKS_PATH}" || exit
  )
}

hooks_install
