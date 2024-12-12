#!/usr/bin/env bash

ssh_gen() (
  { # Service vars
    declare -r SELF="${FUNCNAME[0]}"

    # If not a file, default to demo.sh script name
    declare THE_SCRIPT=demo.sh
    grep -q -m 1 -- '.' "${0}" 2>/dev/null && THE_SCRIPT="$(basename -- "${0}")"
  }

  # shellcheck disable=SC2317
  # shellcheck disable=SC2016
  init() {
    # Ensure clean environment
    lh_params reset

    # Configure defaults
    lh_params defaults \
      ASK=false \
      HOST=HOSTNAME \
      PORT=22 \
      COMMENT='$(id -un)@$(hostname -f)' \
      DIRNAME=HOSTNAME \
      FILENAME=USER \
      DEST_DIR=

    # Configure custom defaults
    lh_params_default_HOST() { lh_params get HOSTNAME; }
    lh_params_default_COMMENT() { printf -- '%s\n' "$(id -un)@$(hostname -f)"; }
    lh_params_default_DIRNAME() { lh_params get HOSTNAME; }
    lh_params_default_FILENAME() { lh_params get USER; }
  }

  declare CUSTOM_DEST_DIR=false

  declare PK_PATH
  declare PK_PATH_ALIAS
  declare PUB_PATH
  declare PUB_PATH_ALIAS
  declare PK_CONFFILE_PATH
  declare PK_CONFFILE_PATH_ALIAS

  declare -A GEN_RESULT=(
    [pk_created]=false
    [pub_created]=false
    [conffile_entry]=false
  )

  print_usage() { echo "
    ${THE_SCRIPT} [--ask] [--host HOST=$(lh_params default-string HOST)] [--port PORT='$(lh_params default-string PORT)'] \\
   ,  [--comment COMMENT=\"$(lh_params default-string COMMENT)\"] [--dirname DIRNAME=$(lh_params default-string DIRNAME)] \\
   ,  [--filename FILENAME=$(lh_params default-string FILENAME)] [--dest-dir DEST_DIR] [--] HOSTNAME USER
  "; }

  print_help() {
    declare -r \
      HOSTNAME=10.0.0.69 \
      USER=foo \
      CUSTOM_DIR=_.serv.com \
      CUSTOM_FILE=bar

    text_nice "
      Generate private and public key pair and manage Include entry in ~/.ssh/config.
     ,
      USAGE:
      =====
      $(print_usage)
     ,
      PARAMS:
      ======
      HOSTNAME  The actual SSH host. With values like '%h' (the target hostname)
     ,          must provide --host and most likely --dirname
      USER      SSH user
      --        End of options
      --ask     Provoke a prompt for all params
      --host    SSH host match pattern
      --port    SSH port
      --comment   Certificate comment
      --dirname   Destination directory name
      --filename  SSH identity key file name
      --dest-dir  Custom destination directory. In case the option is provided
     ,            --dirname option is ignored and Include entry won't be created in
     ,            ~/.ssh/config file. The directory will be autocreated
     ,
      DEMO:
      ====
      # Generate with all defaults to PK file ~/.ssh/${HOSTNAME}/user
      ${THE_SCRIPT} ${HOSTNAME} user
     ,
      # Generate to ~/.ssh/${CUSTOM_DIR}/${CUSTOM_FILE} instead of ~/.ssh/%h/${USER}
     ${THE_SCRIPT} --host 'serv.com *.serv.com' --comment Zoo --dirname '${CUSTOM_DIR}' \\
     ,  --filename '${CUSTOM_FILE}' -- '%h' ${USER}
     ,
      # Generate interactively to ~/my/certs/${USER} (will be prompted for params).
      ${THE_SCRIPT} --ask --dest-dir ~/my/certs/${USER}
    "
  }

  parse_params() {
    declare -a args

    declare endopts=false
    declare param
    while [[ ${#} -gt 0 ]]; do
      ${endopts} && param='*' || param="${1}"

      case "${param}" in
        --            ) endopts=true ;;
        -\?|-h|--help ) print_help; exit ;;
        --usage       ) print_usage | text_nice; exit ;;
        --ask         ) lh_params set ASK true ;;
        --host        ) lh_params set HOST "${@:2:1}"; shift ;;
        --port        ) lh_params set PORT "${@:2:1}"; shift ;;
        --comment     ) lh_params set COMMENT "${@:2:1}"; shift ;;
        --dirname     ) lh_params set DIRNAME "${@:2:1}"; shift ;;
        --filename    ) lh_params set FILENAME "${@:2:1}"; shift ;;
        --dest-dir    ) lh_params set DEST_DIR "${@:2:1}"; shift ;;
        -*            ) lh_params unsupported "${1}" ;;
        *             ) args+=("${1}") ;;
      esac

      shift
    done

    [[ ${#args[@]} -gt 0 ]] && lh_params set HOSTNAME "${args[0]}"
    [[ ${#args[@]} -gt 1 ]] && lh_params set USER "${args[1]}"
    [[ ${#args[@]} -lt 3 ]] || lh_params unsupported "${args[@]:2}"
  }

  trap_ask() {
    "$(lh_params get ASK)" || return 0

    lh_params ask-config \
      , HOSTNAME "HostName (%h for the target hostname): " \
      , USER "SSH user: " \
      , HOST "Host: " \
      , PORT "Host port: " \
      , COMMENT "Comment: " \
      , DIRNAME "Directory name: " \
      , FILENAME "File name: " \
      , DEST_DIR "Custom destination directory: "

    lh_params ask
  }

  check_params() {
    lh_params get HOSTNAME >/dev/null || lh_params_noval HOSTNAME
    lh_params get USER >/dev/null     || lh_params_noval USER

    lh_params is-blank HOSTNAME && lh_params errbag "HOSTNAME can't be blank"
    lh_params is-blank USER     && lh_params errbag "USER can't be blank"
    lh_params is-blank HOST     && lh_params errbag "HOST can't be blank"
    lh_params is-blank PORT     && lh_params errbag "PORT can't be blank"
    lh_params is-blank DIRNAME  && lh_params errbag "DIRNAME can't be blank"
    lh_params is-blank FILENAME && lh_params errbag "FILENAME can't be blank"

    declare port; port="$(lh_params get PORT)" \
      && ! lh_params is-blank PORT \
      && ! is_port_valid "${port}" \
      && lh_params errbag "PORT='$(escape_single_quotes "${port}")' is invalid"
  }

  apply_defaults() {
    declare dest_dir_alias; dest_dir_alias="$(lh_params get DEST_DIR)"
    if lh_params get DEST_DIR | grep -q '.'; then
      CUSTOM_DEST_DIR=true
    else
      # Set dest dir to default value
      lh_params set DEST_DIR "${HOME}/.ssh/$(lh_params get DIRNAME)"

      # shellcheck disable=SC2088
      dest_dir_alias="~/$(realpath -m --relative-to="${HOME}" -- "$(lh_params get DEST_DIR)")"
    fi

    # rtrim '/' for DEST_DIR and DEST_DIR alias
    lh_params set DEST_DIR "$(lh_params get DEST_DIR | sed -e 's/\/*$//')"
    dest_dir_alias="$(sed -e 's/\/*$//' <<< "${dest_dir_alias}")"

    PK_PATH="$(lh_params get DEST_DIR)/$(lh_params get FILENAME)"
    PK_PATH_ALIAS="${dest_dir_alias}/$(lh_params get FILENAME)"

    PUB_PATH="${PK_PATH}.pub"
    PUB_PATH_ALIAS="${PK_PATH_ALIAS}.pub"

    PK_CONFFILE_PATH="${PK_PATH}.config"
    PK_CONFFILE_PATH_ALIAS="${PK_PATH_ALIAS}.config"
  }

  gen_key() {
    declare dest_dir comment
    dest_dir="$(lh_params get DEST_DIR)"
    comment="$(lh_params get COMMENT)"

    (set -x; mkdir -p "${dest_dir}") || return

    if ! cat -- "${PK_PATH}" &>/dev/null; then
      (set -x; ssh-keygen -q -N '' -b 4096 -t rsa -C "${comment}" -f "${PK_PATH}") || return
      GEN_RESULT[pk_created]=true
      GEN_RESULT[pub_created]=true
    fi

    if : \
      && ! ${GEN_RESULT[pk_created]} \
      && ! cat -- "${PUB_PATH}" &>/dev/null \
    ; then
      (set -x; ssh-keygen -y -f "${PK_PATH}" | tee -- "${PUB_PATH}") || return
      GEN_RESULT[pub_created]=true
    fi
  }

  manage_conffile() {
    declare ssh_conffile="${HOME}/.ssh/config"
    declare confline="Include ${PK_CONFFILE_PATH_ALIAS}"

    declare identity_file="${PK_PATH_ALIAS}"
    ${CUSTOM_DEST_DIR} && identity_file="$(realpath -m -- "${PK_PATH_ALIAS}")"
    # shellcheck disable=SC2001
    identity_file="$(sed -e 's/'"$(escape_sed_expr "${HOME}")"'/~/' <<< "${identity_file}")"

    declare conf; conf="
      # SSH host match pattern. Sample:
      #   myserv.com
      #   *.myserv.com myserv.com
      Host $(lh_params get HOST)
        # The actual SSH host. Sample:
        #   10.0.0.69
        #   google.com
        #   %h # (referehce to matched Host)
        HostName $(lh_params get HOSTNAME)
        Port $(lh_params get PORT)
        User $(lh_params get USER)
        IdentityFile ${identity_file}
        IdentitiesOnly yes
    "

    echo "${conf}" \
      | grep -v '^\s*$' | sed -e 's/^\s\+//' -e '5,$s/^/  /' \
      | (set -x; tee -- "${PK_CONFFILE_PATH}" >/dev/null) \
    && {
      # Include in ~/.ssh/config

      ${CUSTOM_DEST_DIR} && return
      grep -qFx -- "${confline}" "${ssh_conffile}" 2>/dev/null && return

      printf -- '%s\n' "${confline}" | (set -x; tee -a -- "${ssh_conffile}" >/dev/null) || return
      GEN_RESULT[conffile_entry]=true
    }
  }

  post_msg() {
    echo >&2

    echo 'RESULT:' >&2

    if ${GEN_RESULT[pk_created]}; then
      echo "  * ${PK_PATH_ALIAS} created." >&2
    else
      echo "  * ${PK_PATH_ALIAS} existed." >&2
    fi

    if ${GEN_RESULT[pub_created]}; then
      echo "  * ${PUB_PATH_ALIAS} created." >&2
    else
      echo "  * ${PUB_PATH_ALIAS} existed." >&2
    fi

    if ${GEN_RESULT[conffile_entry]}; then
      echo "  * ~/.ssh/config entry added." >&2
    elif ! ${CUSTOM_DEST_DIR}; then
      echo "  * ~/.ssh/config entry existed." >&2
    fi

    text_nice "
      Add public key to your server:
     ,  ssh-copy-id -i ${PUB_PATH_ALIAS} -p '$(lh_params get PORT)' '$(lh_params get USER)'@'$(lh_params get HOSTNAME)'
      Add public key to your git host account:
     ,  * https://github.com/settings/keys
     ,  * https://bitbucket.org/account/settings/ssh-keys/
    " >&2

    if ${CUSTOM_DEST_DIR}; then
      # shellcheck disable=SC2088
      declare ssh_dir='~/.ssh/some-dir'
      declare pk_conffile; pk_conffile="${ssh_dir}/$(basename -- "${PK_CONFFILE_PATH}")"

      text_nice "
        Add to your SSH configuration:
       ,  cp -r '$(lh_params get DEST_DIR)' ${ssh_dir}
       ,  echo 'Include ${pk_conffile}' > ~/.ssh/config
       ,  # Ensure correct path to PK file under IdentityFile
       ,  vim ${pk_conffile}
      " >&2
    fi

    text_nice "
      THE RESULTING PUBLIC KEY:
      ========================
    " >&2
    cat -- "${PUB_PATH}"
  }

  main() {
    init
    parse_params "${@}"
    trap_ask
    check_params

    lh_params invalids >&2 && {
      echo "FATAL (${SELF})" >&2
      return 1
    }

    apply_defaults
    gen_key || return $?
    manage_conffile || return $?
    post_msg || return $?
  }

  main "${@}"
)
# .LH_SOURCED: {{ lib/basic.sh }}
# https://stackoverflow.com/a/2705678
escape_sed_expr()  { sed -e 's/[]\/$*.^[]/\\&/g' <<< "${1-$(cat)}"; }
escape_sed_repl()  { sed -e 's/[\/&]/\\&/g' <<< "${1-$(cat)}"; }

escape_single_quotes()  { declare str="${1-$(cat)}"; cat <<< "${str//\'/\'\\\'\'}"; }
escape_double_quotes()  { declare str="${1-$(cat)}"; cat <<< "${str//\"/\"\\\"\"}"; }
# .LH_SOURCED: {{/ lib/basic.sh }}
# .LH_SOURCED: {{ lib/lh-params.sh }}
lh_params() { lh_params_"${1//-/_}" "${@:2}"; }

lh_params_reset() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  declare vname vtype
  for vname in "${!_lh_params_map[@]}"; do
    unset "${vname}"
    declare -"${vtype}"g "${vname}"
  done
}

lh_params_set() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  [[ -n "${2+x}" ]] || { lh_params_noval "${1}"; return 1; }
  # shellcheck disable=SC2034
  LH_PARAMS["${1}"]="${2}"
}

# lh_params_get NAME [DEFAULT]
#
# # Try to get $LH_PARAMS[NAME], fall back to invokation of lh_params_default_NAME,
# # then fallback to $LH_PARAMS_DEFAULTS[NAME] and if doesn't exist RC 1
# lh_params_get NAME
#
# # Try to get $LH_PARAMS[NAME], fall back to DEFAULT_VAL
# lh_params_get NAME DEFAULT_VAL
lh_params_get() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  [[ -n "${LH_PARAMS[${1}]+x}" ]] && { cat <<< "${LH_PARAMS[${1}]}"; return; }
  [[ -n "${2+x}" ]] && { cat <<< "${2}"; return; }
  declare -F "lh_params_default_${1}" &>/dev/null && { "lh_params_default_${1}"; return; }
  [[ -n "${LH_PARAMS_DEFAULTS[${1}]+x}" ]] && { cat <<< "${LH_PARAMS_DEFAULTS[${1}]}"; return; }
  return 1
}

lh_params_is_blank() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  [[ -n "${LH_PARAMS[${1}]+x}" ]] && [[ -z "${LH_PARAMS[${1}]:+x}" ]]
}

lh_params_noval() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  # https://stackoverflow.com/a/13216833
  declare -a issues=("${@/%/ requires a value}")
  lh_params_errbag "${issues[@]}"
}

lh_params_unsupported() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  # https://stackoverflow.com/a/13216833
  declare -a issues=("${@/%/\' param is unsupported}")
  lh_params_errbag "${issues[@]/#/\'}"
}

lh_params_errbag() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  LH_PARAMS_ERRBAG+=("${@}")
}

# lh_params_defaults PARAM_NAME1='DEFAULT_VAL'...
lh_params_defaults() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  declare kv pname pval
  for kv in "${@}"; do
    kv="${kv}="
    pname="${kv%%=*}"
    pval="${kv#*=}"; pval="${pval::-1}"
    LH_PARAMS_DEFAULTS["${pname}"]="${pval}"
  done
}

lh_params_default_string() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  cat <<< "${LH_PARAMS_DEFAULTS[${1}]}"
}

lh_params_ask_config() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }

  declare pname ptext prev_comma=false
  for ptext in "${@}"; do
    [[ "${ptext}" == ',' ]] && { prev_comma=true; continue; }

    ${prev_comma} || [[ -z "${pname}" ]] && {
      pname="${ptext}"
      LH_PARAMS_ASK_PARAMS+=("${pname}")
      prev_comma=false
      continue
    }

    LH_PARAMS_ASK["${pname}"]+="${LH_PARAMS_ASK["${pname}"]+$'\n'}${ptext}"
  done
}

lh_params_ask() {
  declare confirm pname ptext

  [[ -n "${LH_PARAMS_ASK_EXCLUDE+x}" ]] && {
    LH_PARAMS_ASK_EXCLUDE="$(
      # shellcheck disable=SC2001
      sed -e 's/^\s*//' -e 's/\s*$//' <<< "${LH_PARAMS_ASK_EXCLUDE}" \
      | grep -v '^$'
    )"
  }

  while ! [[ "${confirm:-n}" == y ]]; do
    confirm=""

    for pname in "${LH_PARAMS_ASK_PARAMS[@]}"; do
      # Don't prompt for params in LH_PARAMS_ASK_EXCLUDE (text) list
      grep -qFx -- "${pname}" <<< "${LH_PARAMS_ASK_EXCLUDE}" && continue

      read  -erp "${LH_PARAMS_ASK[${pname}]}" \
            -i "$(lh_params_get "${pname}")" "LH_PARAMS[${pname}]"
    done

    echo '============================' >&2

    while [[ ! " y n " == *" ${confirm} "* ]]; do
      read -rp "YES (y) for proceeding or NO (n) to repeat: " confirm
      [[ "${confirm,,}" =~ ^(y|yes)$ ]] && confirm=y
      [[ "${confirm,,}" =~ ^(n|no)$ ]] && confirm=n
    done
  done
}

lh_params_invalids() {
  declare -i rc=1

  [[ ${#LH_PARAMS_ERRBAG[@]} -lt 1 ]] || {
    echo "Issues:"
    printf -- '* %s\n' "${LH_PARAMS_ERRBAG[@]}"
    rc=0
  }

  return ${rc}
}

_lh_params_init() {
  declare -A _lh_params_map=(
    [LH_PARAMS]=A
    [LH_PARAMS_DEFAULTS]=A
    [LH_PARAMS_ASK]=A
    [LH_PARAMS_ASK_PARAMS]=a
    [LH_PARAMS_ERRBAG]=a
  )

  # Ensure global variables
  declare vname vtype
  for vname in "${!_lh_params_map[@]}"; do
    vtype="${_lh_params_map[${vname}]}"
    [[ "$(declare -p "${vname}" 2>/dev/null)" == "declare -${vtype}"* ]] && continue

    unset "${vname}"
    declare -"${vtype}"g "${vname}"
  done

  [[ "${FUNCNAME[1]}" != lh_params_* ]] || {
    unset vname vtype
    "${FUNCNAME[1]}" "${@}"
  }
}
# .LH_SOURCED: {{/ lib/lh-params.sh }}
# .LH_SOURCED: {{ lib/system.sh }}
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

  if grep -qF -- '://' <<< "${1}"; then
    _dt_the_url="${1}"
    declare -a _dt_the_tool
  else
    # shellcheck disable=SC2178
    declare -n _dt_the_tool="${1}"
  fi

  curl -V &>/dev/null && _dt_the_tool=(curl -sfL --) || _dt_the_tool=(wget -qO- --)
  "${_dt_the_tool[@]}" -V &>/dev/null || return

  if [[ -n "${_dt_the_url}" ]]; then
    (set -x; "${_dt_the_tool[@]}" "${_dt_the_url}")
  fi
}
# .LH_SOURCED: {{/ lib/system.sh }}
# .LH_SOURCED: {{ lib/text.sh }}
# shellcheck disable=SC2001
# shellcheck disable=SC2120
text_ltrim() { sed -e 's/^\s\+//' <<< "${1-$(cat)}"; }
text_rtrim() { sed -e 's/\s\+$//' <<< "${1-$(cat)}"; }
text_trim() { text_ltrim <<< "${1-$(cat)}" | text_rtrim; }
text_rmblank() { grep -v '^\s*$' <<< "${1-$(cat)}"; return 0; }
text_nice() { text_trim <<< "${1-$(cat)}" | text_rmblank | sed -e 's/^,//'; }
# .LH_SOURCED: {{/ lib/text.sh }}

# .LH_NOSOURCE

(return &>/dev/null) || {
  ssh_gen "${@}"
}
