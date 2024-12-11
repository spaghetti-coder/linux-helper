#!/usr/bin/env bash

# Attempt to fix __git_ps1 not found in RHEL-like, Debian-like, Alpine
# shellcheck disable=SC1091
declare -F __git_ps1 &>/dev/null \
|| . /usr/share/git-core/contrib/completion/git-prompt.sh 2>/dev/null \
|| . /usr/lib/git-core/git-sh-prompt 2>/dev/null \
|| . /usr/share/git-core/git-prompt.sh 2>/dev/null

# shellcheck disable=SC2016
PS1="$(
  printf -- '%s%s%s\n' \
    '\[\033[01;31m\]\u@\h\[\033[00m\] \[\033[01;32m\]\w\[\033[00m\]' \
    '$(GIT_PS1_SHOWDIRTYSTATE=1 __git_ps1 '\'' (\[\033[01;33m\]%s\[\033[00m\])'\'' 2>/dev/null)' \
    ' \[\033[01;33m\]\$\[\033[00m\] '
)"
