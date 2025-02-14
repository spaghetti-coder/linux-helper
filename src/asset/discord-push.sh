#!/usr/bin/env bash

# https://wchesley.dev/posts/discord_curl_notifications/
# https://birdie0.github.io/discord-webhooks-guide/
discord_push() {
  # gotify_push TITLE BODY [DECIMAL_COLOR]

  local title="${1:-DUMMY TITLE}" \
        body="${2:-DUMMY MESSAGE}" \
        color="${3}" `# <- Optional`

  if [[ "${1}" =~ ^(-\?|-h|--help)$ ]]; then
    local script; script="$(basename -- "${0}")"

    text_fmt "
      Demo:
      ====
      # Required
      export DISCORD_PUSH_TOKEN='<WEBHOOK_ID>/<WEBHOOK_TOKEN>'

      # ${script} MSG_TITLE MSG_BODY [DECIMAL_COLOR]
      ${script} 'Message title' 'Message body' 16711680 # <- Red color
    "

    return
  fi

  local payload='{"embeds": [{'
    payload+='"title": "'"$(escape_double_quotes "${title}")"'"'
    payload+=', "description": "'"$(escape_double_quotes "${body}")"'"'
    [ -n "${color}" ] && payload+=', "color": "'"$(escape_double_quotes "${color}")"'"'
  payload+='}]}'

  curl -X POST -H "Content-Type: application/json" -d "${payload}" \
    "https://discord.com/api/webhooks/${DISCORD_PUSH_TOKEN}"
}

# .LH_SOURCE:lib/basic.sh
# .LH_SOURCE:lib/text.sh

(return 2>/dev/null) || discord_push "${@}"
