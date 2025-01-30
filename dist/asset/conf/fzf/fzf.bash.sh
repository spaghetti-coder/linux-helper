#!/usr/bin/env bash

__iife_fzf() {
  unset __iife_fzf

  ! fzf --version &>/dev/null && return

  local -a opts=(
    --height "'100%'"
    --border
    --history-size 999999
    # https://github.com/junegunn/fzf/issues/577#issuecomment-225953097
    --preview "'echo {}'" --bind ctrl-p:toggle-preview
    --preview-window down:50%:wrap
  )

  FZF_DEFAULT_OPTS+="${FZF_DEFAULT_OPTS:+ }${opts[*]}"
}; __iife_fzf
