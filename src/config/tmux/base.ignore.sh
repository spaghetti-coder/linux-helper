#!/usr/bin/env bash

# .LH_SOURCE:lib/system.sh

HOME_DIR="${HOME}"
if is_user_privileged; then
  HOME_DIR="$(eval echo ~"${SUDO_USER}")"
fi

CONFD="${1:-${HOME_DIR}/.tmux}"
CONFD="$(realpath -m -- "${CONFD}")"

CONFD_ALIAS="${CONFD/${HOME_DIR}\//'~/'}"
