#!/usr/bin/env bash

# .LH_SOURCE:lib/system.sh

HOME_DIR="${HOME}"
INSTALLED_FILES_UMASK=0066
if is_user_privileged; then
  HOME_DIR="$(privileged_user_home)"
  INSTALLED_FILES_UMASK=0022
fi

CONFD="${1:-${HOME_DIR}/.tmux}"
CONFD="$(realpath -m -- "${CONFD}")"

CONFD_ALIAS="${CONFD/${HOME_DIR}\//'~/'}"
