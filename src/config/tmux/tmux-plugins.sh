#!/usr/bin/env bash

# .LH_SOURCE:lib/basic.sh
# .LH_SOURCE:config/tmux/tmux-base.ignore.sh

# If not a file, default to ssh-gen.sh script name
declare THE_SCRIPT=tmux-plugins.sh
grep -q -m 1 -- '.' "${0}" 2>/dev/null && THE_SCRIPT="$(basename -- "${0}")"

CONFIG="$(cat <<'HEREDOC_END'
# .LH_SOURCE_NW:asset/conf/tmux/plugins.conf
HEREDOC_END
)"

CONFIG_APPENDIX="$(cat <<'HEREDOC_END'
# .LH_SOURCE_NW:asset/conf/tmux/appendix.conf
HEREDOC_END
)"

print_help_usage() { echo "
  ${THE_SCRIPT} [--] [CONFD=\"\${HOME}/.tmux\"]
"; }

print_help() { text_nice "
  Generate plugins tmux configuration preset and source it to ~/.tmux.conf file.
  tmux and git are required to be installed for this script. The configs are with
  the following content:
 ,
  \`\`\`
  ${CONFIG}
  \`\`\`
 ,
  \`\`\`
  ${CONFIG_APPENDIX}
  \`\`\`
 ,
  USAGE:
  =====
  $(print_help_usage)
 ,
  PARAMS:
  ======
  CONFD   Confd directory to store tmux custom configurations
 ,
  DEMO:
  ====
  # Generate with all defaults to ~/.tmux/{appendix,plugins}.conf
  ${THE_SCRIPT}
 ,
  # Generate to /etc/tmux/{appendix,plugins}.conf. Requires sudo for non-root user
  sudo ${THE_SCRIPT} /etc/tmux
"; }

config_tmux_base "${@}" || exit

SOURCE_LINE="source-file ${CONFD_ALIAS}/plugins.conf"

config_tmux_create_confd_file "${LH_PARAMS[CONFD]}/plugins.conf" "${CONFIG}" \
&& config_tmux_append_source_line "${SOURCE_LINE}"

(
  declare -a mdkir_cmd_prefix=(mkdir -p --)
  declare -a mkdir_cmd=("${mdkir_cmd_prefix[@]}" ~/.tmux/plugins)
  is_user_privileged && {
    mkdir_cmd=(su -l "${SUDO_USER}" -c "umask 0077; ${mdkir_cmd_prefix[*]} ~/.tmux/plugins")
  }

  set -x
  rm -rf -- "${HOME_DIR}/.tmux/plugins/tpm"
  umask 0077
  "${mkdir_cmd[@]}"
)

SOURCE_LINE="source-file ${CONFD_ALIAS}/appendix.conf"
SOURCE_LINE_REX="$(escape_sed_expr "${SOURCE_LINE}")"

(
  declare -a clone_cmd_prefix=(git clone https://github.com/tmux-plugins/tpm --)
  declare -a clone_cmd=("${clone_cmd_prefix[@]}" ~/.tmux/plugins/tpm)
  is_user_privileged && {
    clone_cmd=(su -l "${SUDO_USER}" -c "umask 0077; ${clone_cmd_prefix[*]} ~/.tmux/plugins/tpm")
  }

  set -x
  umask 0077
  "${clone_cmd[@]}"
) && (
  set -x
  umask -- "${INSTALLED_FILES_UMASK}"
  tee -- "${LH_PARAMS[CONFD]}/appendix.conf" <<< "${CONFIG_APPENDIX}" >/dev/null \
  && sed -i -e '/^'"${SOURCE_LINE_REX}"'$/d' -- "${HOME_DIR}/.tmux.conf"
) && (
  declare -a reload_src_cmd=(true)
  [[ -n "${TMUX_PANE}" ]] && reload_src_cmd=(tmux source ~/.tmux.conf)
  declare -a install_cmd=(~/.tmux/plugins/tpm/scripts/install_plugins.sh)
  is_user_privileged && {
    install_cmd=(su -l "${SUDO_USER}" -c "umask 0077; ~/.tmux/plugins/tpm/scripts/install_plugins.sh")
  }

  set -x
  umask 0077
  tee -a "${HOME_DIR}/.tmux.conf" <<< "${SOURCE_LINE}" >/dev/null \
  && "${reload_src_cmd[@]}" \
  && "${install_cmd[@]}"
)
