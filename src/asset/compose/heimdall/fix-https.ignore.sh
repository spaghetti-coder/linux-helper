#!/usr/bin/env bash

# https://github.com/linuxserver/Heimdall/issues/423#issuecomment-995246073

fix_https() {
  local env_file=/config/www/.env
  local app_url

  if [[ -n "${1+x}" ]]; then
    app_url="${1}"
  elif [[ -n "${VIRTUAL_HOST+x}" ]]; then
    # Proxied by nginx-proxy container
    app_url="${VIRTUAL_PROTO-http}://${VIRTUAL_HOST}"
  else
    # Fall back to FQDN and HTTPS
    app_url=https://"$(hostname -f)"
  fi

  # Give it up to 30 secs to expand the filesystem
  local timeout=30 ctr=0
  while ! cat -- "${env_file}" &>/dev/null; do
    (( ctr++ ))
    [ "${ctr}" -gt "${timeout}" ] && return
    sleep 1
  done

  fix_app_url "${env_file}" "${app_url}"

  # No need fot the last part if not https
  ! [[ "${app_url}" == 'https://'* ]] && return

  force_hhttps "${env_file}"
}

fix_app_url() {
  local env_file="${1}" \
        app_url="${2}"

  # Ensure correct APP_URL
  sed -i -e 's#^\(\s*APP_URL=\).*#\1'"${app_url}"'#' -- "${env_file}"
}

force_hhttps() {
  local env_file="${1}"

  # Does not seem to help, but see no harm either
  if grep -q '^\s*FORCE_HTTPS=' -- "${env_file}"; then
    sed -i -e 's#^\(\s*FORCE_HTTPS=\).*#\1true#' -- "${env_file}"
  else
    echo 'FORCE_HTTPS=true' | tee -a -- "${env_file}"
  fi
}

(return &>/dev/null) || fix_https "${@}"
