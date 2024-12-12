#!/usr/bin/env bash

is_user_root() { [[ "$(id -u)" -eq 0 ]]; }
is_user_privileged() { is_user_root && [[ -n "${SUDO_USER}" ]]; }

privileged_user_home() { eval echo ~"${SUDO_USER}"; }

alias_home_in_path() {
  declare path="${1}" home="${2:-${HOME}}"
  declare home_rex; home_rex="$(escape_sed_expr "${home%/}")"

  # shellcheck disable=SC2001
  sed -e 's/^'"${home_rex}"'/~/' <<< "${path}"
}

is_port_valid() {
  grep -qx -- '[0-9]\+' <<< "${1}" \
  && [[ "${1}" -ge 0 ]] \
  && [[ "${1}" -le 65535 ]]
}

# USAGE:
#   # Cache the download tool and use it
#   declare -a DL_TOOL
#   download_tool DL_TOOL
#   "${DL_TOOL[@]}" https://google.com > google.txt
#
#   # Just use it to download
#   download_tool https://google.com > google.txt
download_tool() {
  declare _dt_the_url

  if [[ "${1}" == *'://'* ]]; then
    _dt_the_url="${1}"
    declare -a _dt_the_tool
  else
    # shellcheck disable=SC2178
    declare -n _dt_the_tool="${1}"
  fi

  { curl -V &>/dev/null && _dt_the_tool=(curl -fsSL --); } \
  || { wget -V &>/dev/null &&  _dt_the_tool=(wget -qO- --); } \
  || return

  if [[ -n "${_dt_the_url}" ]]; then
    (set -x; "${_dt_the_tool[@]}" "${_dt_the_url}")
  fi
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
# .LH_SOURCED: {{/ lib/basic.sh }}
