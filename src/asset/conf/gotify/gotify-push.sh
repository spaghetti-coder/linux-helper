#!/usr/bin/env bash

gotify_push() {
  # gotify_push TITLE BODY [PRIORITY]

  if [[ "${1}" =~ ^(-\?|-h|--help)$ ]]; then
    local script; script="$(basename -- "${0}")"

    text_fmt "
      Demo:
      ====
      # Reauired
      export GOTIFY_ADDRESS=https://gotify.server.com
      export GOTIFY_TOKEN='...'
      # Optional
      export GOTIFY_MARKDOWN=true # defaults to false

      # ${script} MSG_TITLE MSG_BODY [PRIORITY]
      ${script} 'Message title' 'Message body' 7
    "

    return
  fi

  local endpoint="${GOTIFY_ADDRESS}/message?token=${GOTIFY_TOKEN}"

  local title="${1:-DUMMY TITLE}" \
        body="${2:-DUMMY MESSAGE}" \
        priority="${3:-5}"

  local content_type=text/plain
  if [[ " true yes y 1 " == *" ${GOTIFY_MARKDOWN,,:-false} "* ]]; then
    content_type=text/markdown
  fi

  local payload; payload="$(text_fmt '
    {
      "title": "'"$(escape_double_quotes "${title}")"'",
      "message": "'"$(escape_double_quotes "${body}")"'",
      "priority": '"$(escape_double_quotes "${priority}")"',
      "extras": {
        "client::display": { "contentType": "'"${content_type}"'" }
      }
    }
  ')"

  curl -sSL -X POST -H 'Content-Type: application/json' \
    --data "${payload}" -- "${endpoint}"
}

# .LH_SOURCE:lib/basic.sh
# .LH_SOURCE:lib/text.sh

(return 2>/dev/null) || gotify_push "${@}"
