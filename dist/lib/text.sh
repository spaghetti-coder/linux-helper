#!/usr/bin/env bash

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
  local offset; offset="$(grep '[^ ]' <<< "${content}" | grep -o '^\s*' | sort | head -n 1)"
  sed -e 's/^\s\{0,'${#offset}'\}//' -e 's/\s\+$//' <<< "${content}"
}
