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

# .LH_SOURCE:config/tmux/base.ignore.sh

SOURCE_LINE="source-file ${CONFD_ALIAS}/default.conf"

declare -a owner_tmux_prefix=(tee -a --)
declare -a owner_tmux_cmd=("${owner_tmux_prefix[@]}" "${HOME_DIR}/.tmux.conf")

if is_user_privileged; then
  owner_tmux_cmd=(su -l "${SUDO_USER}" -c "umask 0066; ${owner_tmux_prefix[*]} '${HOME_DIR}/.tmux.conf'")
fi

( set -x
  umask -- "${INSTALLED_FILES_UMASK}"
  mkdir -p -- "${CONFD}" \
  && tee -- "${CONFD}/default.conf" <<< "${CONFIG}" >/dev/null \
  && {
    grep -qFx -- "${SOURCE_LINE}" "${HOME_DIR}/.tmux.conf" 2>/dev/null \
    || printf -- '%s\n' "${SOURCE_LINE}" | { umask 0066; "${owner_tmux_cmd[@]}" >/dev/null; }
  }
)
