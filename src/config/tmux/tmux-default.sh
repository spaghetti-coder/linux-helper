#!/usr/bin/env bash

# .LH_SOURCE:lib/basic.sh
# .LH_SOURCE:config/tmux/tmux-base.ignore.sh

# If not a file, default to ssh-gen.sh script name
declare THE_SCRIPT=tmux-default.sh
grep -q -m 1 -- '.' "${0}" 2>/dev/null && THE_SCRIPT="$(basename -- "${0}")"

CONFIG="$(cat <<'HEREDOC_END'
# .LH_SOURCE_NW:asset/conf/tmux/default.conf
HEREDOC_END
)"

print_help_usage() { echo "
  ${THE_SCRIPT} [--] [CONFD=\"\${HOME}/.tmux\"]
"; }

print_help() { text_nice "
  Generate basic tmux configuration preset and source it to ~/.tmux.conf file. The
  config is with the following content:
 ,
  \`\`\`
  ${CONFIG}
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
  # Generate with all defaults to ~/.tmux/default.conf
  ${THE_SCRIPT}
 ,
  # Generate to /etc/tmux/default.conf. Requires sudo for non-root user
  sudo ${THE_SCRIPT} /etc/tmux
"; }

config_tmux_base "${@}" || exit

SOURCE_LINE="source-file ${CONFD_ALIAS}/default.conf"

config_tmux_create_confd_file "${LH_PARAMS[CONFD]}/default.conf" "${CONFIG}" \
&& config_tmux_append_source_line "${SOURCE_LINE}"
