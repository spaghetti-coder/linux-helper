#!/usr/bin/env bash

CONFIG="$(cat <<'HEREDOC_END'
# default.conf

set-option -g prefix C-Space
set-option -g allow-rename off
set -g history-limit 100000
set -g renumber-windows on
set -g base-index 1
set -g display-panes-time 3000
setw -g pane-base-index 1
setw -g aggressive-resize on
HEREDOC_END
)"

[[ "${1}" == --info ]] && {
  echo "${CONFIG}"
  exit
}
# .LH_SOURCED: {{ config/tmux/base.ignore.sh }}
HOME_DIR="${HOME}"
if [[ -n "${SUDO_USER:+x}" ]]; then
  HOME_DIR="$(eval echo ~"${SUDO_USER}")"
fi

CONFD="${1:-${HOME_DIR}/.tmux}"
CONFD="$(realpath -m -- "${CONFD}")"

CONFD_ALIAS="${CONFD/${HOME_DIR}\//'~/'}"

# .LH_SOURCED: {{/ config/tmux/base.ignore.sh }}

SOURCE_LINE="source-file ${CONFD_ALIAS}/default.conf"

(
  set -x
  mkdir -p -- "${CONFD}" \
  && tee -- "${CONFD}/default.conf" <<< "${CONFIG}" >/dev/null \
  && {
    grep -qFx -- "${SOURCE_LINE}" ~/.tmux.conf 2>/dev/null \
    || printf -- '%s\n' "${SOURCE_LINE}" | tee -a ~/.tmux.conf >/dev/null
  }
)
