#!/usr/bin/env bash
# shellcheck disable=SC2317

dydns() (
  # If not a file, default to dydns.sh script name
  local THE_SCRIPT=dydns.sh
  grep -q -m 1 -- '.' "${0}" 2>/dev/null && THE_SCRIPT="$(basename -- "${0}")"

  declare -a EXPORTS=(
    duckdns
    dynu
    now_dns
    ydns
  )

  duckdns() {
    if [[ -n "${1+x}" ]]; then
      provider_request "${1}" "${FUNCNAME[0]^^}" "secret-token" "site1,site2" '*/5 * * * *' "
        Get token from your main page: https://www.duckdns.org/
        No need to suffix domains with '.duckdns.org', only the subdomains
      "; return
    fi

    local -i rc=0
    local response; response="$(curl --max-time 60 -ksSL \
      "https://www.duckdns.org/update?&token=${TOKEN}&domains=${DOMAINS}&ip="
    )" || rc=1

    # DuckDNS 'KO' response doesn't come with error code
    [[ "${response}" == 'OK' ]] || rc=1

    [[ -z "${ONDONE}" ]] || {
      "${ONDONE}" "${rc}" "${response}" "${FUNCNAME[0]//_/-}" "${DOMAINS}"
    }

    printf -- '%s\n' "${response}"
    return "${rc}"
  }

  dynu() {
    if [[ -n "${1+x}" ]]; then
      provider_request "${1}" "${FUNCNAME[0]^^}" "my-user:secret-token" "site1.ooguy.com,site2.kozow.com" '*/5 * * * *' "
        Get username at 'Control Panel' > 'My Account':
          https://www.dynu.com/en-US/ControlPanel/MyAccount

        Use plain or MD5 / SHA256 hashed account password or gain (and alternatively
        hash with MD5 / SHA256) an IP Update Password at 'Control Panel'
        > 'My Account' > 'Username/Password':
          https://www.dynu.com/ControlPanel/ManageCredentials
      "; return
    fi

    local -i main_rc=0
    local -i rc

    local response
    local domain; while read -r domain; do
      rc=0

      response="$(curl --max-time 60 -ksSL -u "${TOKEN}" \
        "https://api.dynu.com/nic/update?hostname=${domain}"
      )" || { main_rc=1; rc=1; }

      # https://www.dynu.com/DynamicDNS/IP-Update-Protocol#responsecode
      grep '^\s*\(good\|nochg\)\(\s\+.*\)\?\s*$' <<< "${response}" || {
        main_rc=1; rc=1;
      }

      [[ -z "${ONDONE}" ]] || {
        "${ONDONE}" "${rc}" "${response}" "${FUNCNAME[0]//_/-}" "${domain}"
      }

      printf -- '%s\n' "${response}"
    done < <(tr ',' '\n' <<< "${DOMAINS}")

    return "${main_rc}"
  }

  now_dns() {
    if [[ -n "${1+x}" ]]; then
      provider_request "${1}" "${FUNCNAME[0]^^}" "foo@bar.baz:secret-token" "site1.mypi.co,site2.ddns.cam" '*/5 * * * *' "
        Use your rigistration email as the first part of the token.
        Use your password or token generated on account page for the second part
        of token: https://now-dns.com/account
        EMAIL:PASSWORD_OR_TOKEN
        No recommended schedule found.
      "; return
    fi

    local -i main_rc=0
    local -i rc

    local response
    local domain; while read -r domain; do
      rc=0

      response="$(curl --max-time 60 -ksSL -u "${TOKEN}" \
        "https://now-dns.com/update?hostname=${domain}"
      )" || { main_rc=1; rc=1; }

      # https://now-dns.com/clients
      grep '^\s*"\?\(good\|nochg\)"\?\(\s\+.*\)\?\s*$' <<< "${response}" || {
        main_rc=1; rc=1;
      }

      [[ -z "${ONDONE}" ]] || {
        "${ONDONE}" "${rc}" "${response}" "${FUNCNAME[0]//_/-}" "${domain}"
      }

      printf -- '%s\n' "${response}"
    done < <(tr ',' '\n' <<< "${DOMAINS}")

    return "${main_rc}"
  }

  ydns() {
    if [[ -n "${1+x}" ]]; then
      provider_request "${1}" "${FUNCNAME[0]^^}" "foobarbaz:secret-token" "site1.ydns.eu,site2.ydns.eu" '*/15 * * * *' "
        For first and second part of the token use Username and Secret from
        Preferences > API Credentials: https://ydns.io/user/api
        USERNAME:SECRET
      "; return
    fi

    local -i main_rc=0
    local -i rc

    local response
    local domain; while read -r domain; do
      rc=0

      response="$(curl --max-time 60 -ksSL --basic -u "${TOKEN}" \
        "https://ydns.io/api/v1/update/?host=${domain}"
      )" || { main_rc=1; rc=1; }

      # https://now-dns.com/clients
      grep '^\s*"\?\(good\|nochg\)"\?\(\s\+.*\)\?\s*$' <<< "${response}" || {
        main_rc=1; rc=1;
      }

      [[ -z "${ONDONE}" ]] || {
        "${ONDONE}" "${rc}" "${response}" "${FUNCNAME[0]//_/-}" "${domain}"
      }

      printf -- '%s\n' "${response}"
    done < <(tr ',' '\n' <<< "${DOMAINS}")

    return "${main_rc}"
  }

  print_help() {
    local provider=now-dns \
          domains=site1.mypi.co,site2.ddns.cam \
          email=foo@bar.baz \
          token=secret-token \
          schedule='*/5 * * * *'
    local var_prefix="${provider//-/_}"
    var_prefix="${var_prefix^^}"

    text_fmt "
      Update dynamic DNS. Supported providers:
      $(printf -- '* %s\n' "${EXPORTS[@]//_/-}")

      For help on a specific provider issue:
        ${THE_SCRIPT} PROVIDER --help

      Requirements:
      * bash
      * curl
      * crontab (only for configuring scheduled IP updates)

      USAGE:
      =====
      # Token and domains must be provided either via environment
      # variables or via options
      [export <PROVIDER_PREFIX>_TOKEN=...]
      [export <PROVIDER_PREFIX>_DOMAINS=...]
      [export <PROVIDER_PREFIX>_SCHEDULE=...]
      [export <PROVIDER_PREFIX>_ONDONE=...]
      ${THE_SCRIPT} PROVIDER [DOMAINS...] [--token TOKEN] \\
        [--ondone ONDONE_SCRIPT] [--schedule SCHEDULE [--dry]]

      DEMO:
      ====
      #
      # Provider:           now-dns (https://now-dns.com)
      # Domains:            ${domains//,/, }
      # Registration email: ${email}
      # Token:              ${token}
      #

      # Update domains manually
      ${THE_SCRIPT} ${provider} --token '${email}:${token}' \\
        '${domains}'

      # Same, but domains are in multiple positional params
      ${THE_SCRIPT} ${provider} --token '${email}:${token}' \\
        '${domains//,/\' \'}'

      # Same, but using env variables. Domains are only comma-separated
      export ${var_prefix}_TOKEN='${email}:${token}'
      export ${var_prefix}_DOMAINS='${domains}'
      ${THE_SCRIPT} ${provider}

      # Install '${provider}' provider to \${HOME}/.dydns/${provider} dorectory, schedule DyDNS
      # updates with ~/log.sh script run on each update. To access installed provider:
      #   \"\${HOME}/.dydns/${provider}/${provider}.sh\" \`# with --help flag to view help\`
      # Also the following crontab entry will be created:
      #   ${schedule} ... '${HOME}/.dydns/${provider}/${provider}.sh'
      # After installing all desired providers '${THE_SCRIPT}' script can be deleted.
      ${THE_SCRIPT} ${provider} --schedule '${schedule}' --ondone ~/log.sh \\
        --token '${email}:${token}' '${domains}'
      # Optionally create the log script
      printf -- '%s\n' '#!/usr/bin/env bash' '' \\
        '# RC - 0 for successful update or 1 for failure' \\
        '# MSG - response message from the provider' \\
        'echo \"RC=\${1}; MSG=\${2}; PROVIDER=\${3}; DOMAINS=\${4}\" >> ~/dydns.log' \\
        > ~/log.sh; chmod +x ~/log.sh

      # Same as previous, but without logger and cron configuration. They can be
      # configured later with the installed provider script (see its '--help').
      ${THE_SCRIPT} ${provider} --dry --schedule '${schedule}' \\
        --token '${email}:${token}' '${domains}'
    "
  }

  provider_request() {
    # RC:
    # * 0 - all is fine, request satisfied
    # * 1 - all is fine, not a request

    is_help "${1}" && { provider_help "${@:2}"; return; }

    # shellcheck disable=SC2016
    case "${1}" in
      --token ) printf -- '%s\n' "${TOKEN}"; return ;;
      --howto )
        text_fmt "
          # Move DyDNS provider suite to a different location #
          # ################################################# #

          # Ensure no crontab left behind
          ${THE_SCRIPT} unschedule
          # Move the suite to a new location
          mv ${SELF[home]} ~/my-dydns
          # Edit SELF paths in the 'conf' block
          vim ~/my-dydns/${THE_SCRIPT}
          # Bring the cron schedule back
          ~/my-dydns/${THE_SCRIPT} schedule

          # Configuration locations (at least by design) #
          # ############################################ #

          # Most of configuraitions:
          sed -e '1,/^}/!d' -e '/{\s*/,\$!d' -- '${SELF[file]}'
          # Hidden secret token:
          grep '^\s*[^#]\+' -- '${SELF[token_file]}'
          # Actual schedule:
          crontab -l 2>/dev/null | grep \"${SELF[cron_entry_rex]}\"
        "
        return
        ;;
      health )  provider_health; return ;;
      rmrf|rimraf )
        # Remove crontab entry
        "${FUNCNAME[0]}" unschedule \
        && ( # Remove self files
          set -x
          rm -f -- "${SELF[file]}" "${SELF[token_file]}" \
          && rmdir -p --ignore-fail-on-non-empty -- "${SELF[home]}"
        ); return
        ;;
      schedule )
        local entries; entries="$(crontab -l 2>/dev/null | grep -v "${SELF[cron_entry_rex]}")"
        (set -x; crontab - <<< "${entries}${entries:+$'\n'}${SELF[cron_entry]}")
        return
        ;;
      rm|uninstall )
        local confirm; while [[ "${confirm}" != 'y' ]]; do
          read -rp "Confirm uninstallation [y(es)/n(o)]: " confirm
          [[ "${confirm,,}" =~ ^(y|yes)$ ]] && confirm=y
          [[ "${confirm,,}" =~ ^(n|no)$ ]]  && return
        done

        "${FUNCNAME[0]}" rmrf; return
        ;;
      unschedule )
        # Remove crontab entry
        local entries; entries="$(crontab -l 2>/dev/null)" || return 0
        entries="$(grep -v "${SELF[cron_entry_rex]}" <<< "${entries}")"

        if grep -q '[^\s]' <<< "${entries}"; then
          (set -x; crontab - <<< "${entries}"); return
        fi

        (set -x; crontab -r); return 0
        ;;
    esac

    echo "Unsupported argument: '${1}'"
    return 1
  }

  provider_health() {
      local configured=true

      local token_text="TOKEN='***'   # Fine. Obfuscated. Issue \`${THE_SCRIPT} --token\` to reveal"
      if [[ -z "${TOKEN}" ]]; then
        configured=false
        token_text="TOKEN='' # Not available"
      fi

      local domains_text="DOMAINS='${DOMAINS}'  # Fine"
      if [[ -z "${DOMAINS}" ]]; then
        configured=false
        domains_text="DOMAINS='' # Not available"
      fi

      local schedule; schedule="$(
        crontab -l 2>/dev/null | grep "${SELF[cron_entry_rex]}" \
        | grep -o '.* sleep ' | sed -e 's/\s\+$//' -e 's/\s\+/ /' \
        | rev | cut -d' ' -f2- | rev
      )"
      local schedule_text="SCHEDULE='${schedule}'   # Fine"
      if [[ "${schedule}" != "${SCHEDULE}" ]]; then
        configured=false
        schedule_text="$(text_fmt "
          SCHEDULE='${SCHEDULE}'  # Desired
          SCHEDULE='${schedule}'  # Actual, fix by issuing \`${THE_SCRIPT} schedule\`
        ")"
      fi

      local ondone_text="ONDONE='${ONDONE}' # Fine"
      if [ -n "${ONDONE}" ] && ! command -v "${ONDONE}" &>/dev/null; then
        configured=false
        ondone_text="ONDONE='${ONDONE}' # Not available or not executable"
      fi

      local configuration_text="The script seems to be in action. Configuration:"
      if ! ${configured}; then
        configuration_text="The script is not configured correctly. Configuration:"
      fi

      text_fmt "
        # ${configuration_text}
        ${token_text}
        ${domains_text}
        ${schedule_text}
        ${ondone_text}
      "

      ${configured}
  }

  provider_help() {
    local var_prefix="${1}" \
          token="${2}" \
          domains="${3}" \
          schedule="${4}" \
          guide="${5}"
    # shellcheck disable=SC2088,SC2016
    local ondone='${HOME}/ondone.sh'

    [[ -n "${guide}" ]] && {
      text_fmt "${guide}" | sed 's/^/# /'
      echo
    }

    # If in dydns context
    [[ -n "${PROVIDER}" ]] && text_fmt "
        # Perform update with args
        ${THE_SCRIPT} ${PROVIDER} --token '${token}' '${domains}' \\
          --schedule '${schedule}' --ondone \"${ondone}\"
      " && echo && text_fmt "
        # Perform update with env variables
        # Required
        export ${var_prefix}_TOKEN='${token}'
        export ${var_prefix}_DOMAINS='${domains}'
        # Optional
        export ${var_prefix}_SCHEDULE='${schedule}'  # Provider recommended schedule
        export ${var_prefix}_ONDONE=\"${ondone}\"
        ${THE_SCRIPT} ${PROVIDER}
      "

    # If in provider stand-alone context
    # shellcheck disable=SC2016
    [[ -n "${PROVIDER}" ]] || {
      text_fmt "
        # Supported configurations
        # Required
        TOKEN='${token}'
        DOMAINS='${domains}'
        # Optional
        SCHEDULE='${schedule}'  # Provider recommended schedule
        ONDONE=\"${ondone}\"

        # Perform manual IP update
        ${THE_SCRIPT}

        # Available actions:
        ${THE_SCRIPT} --howto     # Print instructions on how to do something
        ${THE_SCRIPT} --token     # Reveal the secret token
        ${THE_SCRIPT} health      # Shallow configuration validation
        ${THE_SCRIPT} rimraf      # (or 'rmrf') 'uninstall' without confirmation prompt
        ${THE_SCRIPT} schedule    # Configure / reconfigure scheduled runs
        ${THE_SCRIPT} uninstall   # (or 'rm') Uninstall current script suit + schedule
        ${THE_SCRIPT} unschedule  # Remove schedule
      "
    }
  }

  install_provider() (
    local provider_file="${1}"
    local provider_dir; provider_dir="$(dirname -- "${provider_file}")"
    local token_file="${provider_dir}/${PROVIDER}.token.sh"

    (set -x; install -d -m 0700 -- "${provider_dir}") || return

    # Generate token file
    text_fmt "
      #!/usr/bin/env bash
      TOKEN='$(escape_single_quotes "${TOKEN}")'
    " | (
      set -x
      umask 0077 && tee -- "${token_file}" >/dev/null \
      && chmod 0600 -- "${token_file}"
    ) || return

    main() {
      local PROVIDER_FUNC
      init

      # Configuration
      local TOKEN DOMAINS SCHEDULE ONDONE
      declare -A SELF
      conf

      # Source token file
      # shellcheck disable=SC1090
      . "${SELF[token_file]}"

      # Normalize values
      # shellcheck disable=SC2001,SC2030
      DOMAINS="$(sed -e 's/\s*,\s*/,/g' <<< "${DOMAINS}" \
        | tr ',' '\n' | sort -n | uniq | tr '\n' ',' | sed -e 's/,$//')"
      # shellcheck disable=SC2001,SC2030
      SCHEDULE="$(sed -e 's/\s\+/ /g' <<< "${SCHEDULE}")"

      local PROVIDER=''
      # If not a file, default to ...
      local THE_SCRIPT="${PROVIDER_FUNC//_/-}.sh"
      grep -q -m 1 -- '.' "${0}" 2>/dev/null && THE_SCRIPT="$(basename -- "${0}")"

      SELF+=(
        [home]="$(dirname -- "${SELF[file]}")"
        # Sleep to avoid the crowd that copy-paste schedule from the official guide
        [cron_entry]="${SCHEDULE} sleep \$(( \$(shuf -i 0-40 -n 1) + 10 )); '${SELF[file]}'"
        [cron_entry_rex]=";\?\s\+'${SELF[file_rex]}'\s*$"
      )

      "${PROVIDER_FUNC}" "${@}"
    }

    # shellcheck disable=SC2016,SC2001
    printf -- '%s\n' \
      "#!/usr/bin/env bash" \
      "" \
      "$(text_fmt " `# Leave it on top`
        conf() {
          SELF=(
            # Paths configuration (reflect on script location in crontab)
            [file]='$(escape_single_quotes "${provider_file}")'
            [token_file]='$(escape_single_quotes "${token_file}")'
            [file_rex]='$(escape_single_quotes "${provider_file}" | escape_sed_expr)'
          )

          { # Provider configuration block
            DOMAINS='$(escape_single_quotes "${DOMAINS}")'
            # Desired schedule, can differ from the actual one in the crontab
            SCHEDULE='$(escape_single_quotes "${SCHEDULE}")'
            ONDONE='$(escape_single_quotes "${ONDONE}")'
            # TOKEN   # Resides in a separate file, \`cat -- \${SELF[token_file]}\`
          }
        }

        init() { PROVIDER_FUNC='${PROVIDER_FUNC}'; }
      ")" \
      "" \
      "$( declare -f \
        main \
        "${PROVIDER_FUNC}" \
        provider_help \
        provider_health \
        provider_request \
        is_help text_fmt
      )" \
      "" \
      '(return 2>/dev/null) || main "${@}"' \
    | (
      set -x
      tee -- "${provider_file}" >/dev/null \
      && chmod 0700 -- "${provider_file}"
    ) || return

    return
  )

  is_help() { [[ "${1}" =~ ^(-\?|-h|--help)$ ]]; }

  main() {
    is_help "${1}" && { print_help; return; }
    local PROVIDER="${1}"; shift

    printf -- '%s\n' "${EXPORTS[@]//_/-}" | grep -qFx -- "${PROVIDER}" || {
      echo "Unsupported provider: '${PROVIDER}'" >&2
      return 1
    }

    declare -a ERRBAG
    local PROVIDER_FUNC="${PROVIDER//-/_}"

    # Parse args
    local TOKEN SCHEDULE ONDONE DOMAINS
    local dry=false
    while [[ $# -gt 0 ]]; do
      # Trap provider help
      is_help "${1}" && { "${PROVIDER_FUNC}" --help; return; }

      case "${1}" in
        --token     ) TOKEN="${2}"; shift ;;
        --schedule  ) SCHEDULE="${2}"; shift ;;
        --ondone    ) ONDONE="${2}"; shift ;;
        --dry       ) dry=true ;;
        -*          ) ERRBAG+=("Unsupported option: '${1}'") ;;
        *           ) DOMAINS+="${DOMAINS:+,}${1}" ;;
      esac

      shift
    done

    local TOKEN_ENVVARNAME="${PROVIDER_FUNC^^}_TOKEN" \
          DOMAINS_ENVVARNAME="${PROVIDER_FUNC^^}_DOMAINS" \
          SCHEDULE_ENVVARNAME="${PROVIDER_FUNC^^}_SCHEDULE" \
          ONDONE_ENVVARNAME="${PROVIDER_FUNC^^}_ONDONE"

    TOKEN="${TOKEN-${!TOKEN_ENVVARNAME}}"
    DOMAINS="${DOMAINS-${!DOMAINS_ENVVARNAME}}"
    SCHEDULE="${SCHEDULE-${!SCHEDULE_ENVVARNAME}}"
    ONDONE="${ONDONE-${!ONDONE_ENVVARNAME}}"

    # Validate required env variables
    [[ -n "${TOKEN}" ]] || ERRBAG+=("${TOKEN_ENVVARNAME} env variable or --token option value required")
    [[ -n "${DOMAINS}" ]] || ERRBAG+=("${DOMAINS_ENVVARNAME} env variable or DOMAINS argument value required")
    [[ -z "${SCHEDULE}" ]] && ${dry} && ERRBAG+=("${SCHEDULE_ENVVARNAME} env variable or --schedule option required for --dry option")

    [[ ${#ERRBAG[@]} -lt 1 ]] || {
      printf -- '%s\n' "${ERRBAG[@]}" >&2
      return 1
    }

    # Schedule setup
    [[ -n "${SCHEDULE}" ]] && {
      local dest="${HOME}/.dydns/${PROVIDER}/${PROVIDER}.sh"
      install_provider "${dest}" && {
        ${dry} || "${dest}" schedule
      }; return
    }

    "${PROVIDER_FUNC}"
  }

  main "${@}"
)

# .LH_SOURCE:lib/basic.sh
# .LH_SOURCE:lib/text.sh

(return 2>/dev/null) || dydns "${@}"
