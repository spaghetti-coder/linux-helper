#!/usr/bin/env bash

_BASHRCD_FILES="$(
  the_dir="$(dirname -- "${BASH_SOURCE[0]}")"
  find -- "${the_dir}" -maxdepth 1 -name '*.sh' -not -path "${BASH_SOURCE[0]}" -type f \
  | sort -n | grep '.'
)" && {
  mapfile -t _BASHRCD_FILES <<< "${_BASHRCD_FILES}"

  for _BASHRCD_FILE in "${_BASHRCD_FILES[@]}"; do
    # shellcheck disable=SC1090
    . "${_BASHRCD_FILE}"
  done
} || return 0
