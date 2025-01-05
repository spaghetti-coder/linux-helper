#!/usr/bin/env bash

config_tmux_default() (
  { # Service vars

    # If not a file, default to ssh-gen.sh script name
    declare THE_SCRIPT=tmux-default.sh
    grep -q -m 1 -- '.' "${0}" 2>/dev/null && THE_SCRIPT="$(basename -- "${0}")"
  }

  declare CONFIG; CONFIG="$(text_nice "
    # .LH_SOURCE_NW:asset/conf/tmux/default.conf
  ")"

  # shellcheck disable=SC2317
  print_usage() { text_nice "
    ${THE_SCRIPT} [--] [CONFD=\"$(lh_params default-string CONFD)\"]
  "; }

  # shellcheck disable=SC2317
  print_help() { text_nice "
    Generate basic tmux configuration preset and source it to ~/.tmux.conf file. The
    config is with the following content:

    \`\`\`
    ${CONFIG}
    \`\`\`

    USAGE:
    =====
    $(print_usage | sed 's/^/,/')

    PARAMS:
    ======
    CONFD   Confd directory to store tmux custom configurations
    --      End of options

    DEMO:
    ====
    # Generate with all defaults to \"$(lh_params default-string CONFD)/default.conf\"
    ${THE_SCRIPT}

    # Generate to /etc/tmux/default.conf. Requires sudo for non-root user
    sudo ${THE_SCRIPT} /etc/tmux
  "; }

  main() {
    config_tmux_base "${@}" || return

    declare source_line="source-file ${CONFD_ALIAS}/default.conf"

    config_tmux_create_confd_file "$(lh_params get CONFD)/default.conf" "${CONFIG}" \
    && config_tmux_append_source_line "${source_line}"
  }

  main "${@}"
)

# .LH_SOURCE:config/tmux/tmux-base.ignore.sh
# .LH_SOURCE:lib/basic.sh
# .LH_SOURCE:lib/text.sh

# .LH_NOSOURCE

(return &>/dev/null) || {
  config_tmux_default "${@}"
}
