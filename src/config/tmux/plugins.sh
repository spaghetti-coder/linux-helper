#!/usr/bin/env bash

CONFIG="$(cat <<'HEREDOC_END'
# plugins.conf

set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-sidebar'

# set-environment -g TMUX_PLUGIN_MANAGER_PATH '~/.tmux/plugins'
# run -b '~/.tmux/plugins/tpm/tpm'
HEREDOC_END
)"

CONFIG_APPENDIX="$(cat <<'HEREDOC_END'
# appendix.conf
set-environment -g TMUX_PLUGIN_MANAGER_PATH '~/.tmux/plugins'
run -b '~/.tmux/plugins/tpm/tpm'
HEREDOC_END
)"

[[ "${1}" == --info ]] && {
  echo "${CONFIG}"$'\n'"${CONFIG_APPENDIX}"
  exit
}

# .LH_SOURCE:config/tmux/base.ignore.sh
# .LH_SOURCE:lib/basic.sh

SOURCE_LINE="source-file ${CONFD_ALIAS}/plugins.conf"

(
  set -x
  mkdir -p -- "${CONFD}" \
  && tee -- "${CONFD}/plugins.conf" <<< "${CONFIG}" >/dev/null \
  && {
    grep -qFx -- "${SOURCE_LINE}" ~/.tmux.conf 2>/dev/null \
    || printf -- '%s\n' "${SOURCE_LINE}" | tee -a ~/.tmux.conf >/dev/null
  }
)

(
  set -x
  rm -rf ~/.tmux/plugins/tpm
  mkdir -p ~/.tmux/plugins
)

SOURCE_LINE="source-file ${CONFD_ALIAS}/appendix.conf"
SOURCE_LINE_REX="$(escape_sed_expr "${SOURCE_LINE}")"

reload_src_cmd=(true)
[[ -n "${TMUX_PANE}" ]] && reload_src_cmd=(tmux source ~/.tmux.conf)

(
  set -o pipefail; set -x
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm \
  && tee -- "${CONFD}/appendix.conf" <<< "${CONFIG_APPENDIX}" >/dev/null \
  && sed -i -e '/^'"${SOURCE_LINE_REX}"'$/d' ~/.tmux.conf \
  && tee -a ~/.tmux.conf <<< "${SOURCE_LINE}" >/dev/null \
  && "${reload_src_cmd[@]}" \
  && ~/.tmux/plugins/tpm/scripts/install_plugins.sh
)
