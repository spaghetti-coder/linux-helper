#!/usr/bin/env bash

HOME_DIR="${HOME}"
if [[ -n "${SUDO_USER:+x}" ]]; then
  HOME_DIR="$(eval echo ~"${SUDO_USER}")"
fi

echo ${SUDO_USER}
echo ${HOME_DIR}
exit

CONFD="${1:-${HOME_DIR}/.tmux}"
CONFD="$(realpath -m -- "${CONFD}")"

CONFD_ALIAS="${CONFD/${HOME_DIR}\//'~/'}"

