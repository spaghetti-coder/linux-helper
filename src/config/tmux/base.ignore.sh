#!/usr/bin/env bash

HOME_DIR="${HOME}"
IS_PRIVILEGED=false
if [[ -n "${SUDO_USER:+x}" ]] && [[ "$(id -u)" -eq 0 ]]; then
  HOME_DIR="$(eval echo ~"${SUDO_USER}")"
  IS_PRIVILEGED=true
fi

CONFD="${1:-${HOME_DIR}/.tmux}"
CONFD="$(realpath -m -- "${CONFD}")"

CONFD_ALIAS="${CONFD/${HOME_DIR}\//'~/'}"
