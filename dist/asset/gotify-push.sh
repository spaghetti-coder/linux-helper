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
# .LH_SOURCED: {{ lib/basic.sh }}
# https://stackoverflow.com/a/2705678
escape_sed_expr()  { sed -e 's/[]\/$*.^[]/\\&/g' <<< "${1-$(cat)}"; }
escape_sed_repl()  { sed -e 's/[\/&]/\\&/g' <<< "${1-$(cat)}"; }

escape_single_quotes()  { declare str="${1-$(cat)}"; cat <<< "${str//\'/\'\\\'\'}"; }
escape_double_quotes()  { declare str="${1-$(cat)}"; cat <<< "${str//\"/\"\\\"\"}"; }

to_bool() {
  [[ "${1,,}" =~ ^(1|y|yes|true)$ ]] && { echo true; return; }
  [[ "${1,,}" =~ ^(0|n|no|false)$ ]] && { echo false; return; }
  return 1
}

# https://unix.stackexchange.com/a/194790
uniq_ordered() {
  cat -n <<< "${1-$(cat)}" | sort -k2 -k1n  | uniq -f1 | sort -nk1,1 | cut -f2-
}

template_compile() {
  # echo 'text {{ KEY1 }} more {{ KEY2 }} text' \
  # | template_compile [KEY1 VAL1]...

  declare -a expr filter=(cat)
  declare key val
  while [[ ${#} -gt 0 ]]; do
    [[ "${1}" == *'='* ]] && {
      key="${1%%=*}" val="${1#*=}"
      shift
    } || {
      key="${1}" val="${2}"
      shift 2
    }
    expr+=(-e 's/{{\s*'"$(escape_sed_expr "${key}")"'\s*}}/'"$(escape_sed_repl "${val}")"'/g')
  done

  [[ ${#expr[@]} -lt 1 ]] || filter=(sed "${expr[@]}")

  "${filter[@]}"
}
# .LH_SOURCED: {{/ lib/basic.sh }}
# .LH_SOURCED: {{ lib/text.sh }}
# shellcheck disable=SC2001,SC2120

text_ltrim() { sed -e 's/^\s\+//' <<< "${1-$(cat)}"; }
text_rtrim() { sed -e 's/\s\+$//' <<< "${1-$(cat)}"; }
text_trim() { text_ltrim <<< "${1-$(cat)}" | text_rtrim; }
text_rmblank() { grep -v '^\s*$' <<< "${1-$(cat)}"; return 0; }
text_nice() {
  text_trim <<< "${1-$(cat)}" \
  | sed -e '/^.\+$/,$!d' | tac \
  | sed -e '/^.\+$/,$!d' -e 's/^,//' | tac
}
text_fmt() {
  local content; content="$(
    sed '/[^ ]/,$!d' <<< "${1-"$(cat)"}" | tac | sed '/[^ ]/,$!d' | tac
  )"
  local offset; offset="$(grep -o -m1 '^\s*' <<< "${content}")"
  sed -e 's/^\s\{0,'${#offset}'\}//' -e 's/\s\+$//' <<< "${content}"
}
# .LH_SOURCED: {{/ lib/text.sh }}

(return 2>/dev/null) || gotify_push "${@}"
