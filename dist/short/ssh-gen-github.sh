#!/usr/bin/env bash

ssh_gen_github() (
  { # Service vars
    # declare -r SELF="${FUNCNAME[0]}"

    # If not a file, default to ssh-gen-github script name
    declare THE_SCRIPT="ssh-gen-github.sh"
    grep -q -m 1 -- '.' "${0}" 2>/dev/null && THE_SCRIPT="$(basename -- "${0}")"
  }

  # shellcheck disable=SC2016
  declare -A DEFAULTS=(
    [account]=git
    [host]=github.com
    [comment]='$(id -un)@$(hostname -f)'
  )

  declare -a DOWNSTREAM=(ssh_gen_vc "${DEFAULTS[host]}")

  print_usage() { text_nice "
    ${THE_SCRIPT} [--ask] [--host HOST='${DEFAULTS[host]}'] \\
    ,  [--comment COMMENT=\"${DEFAULTS[comment]}\"] [--] [ACCOUNT='${DEFAULTS[account]}']
  "; }

  print_help() {
    declare -r ACCOUNT=foo

    text_nice "
      github.com centric shortcut of ssh-gen.sh tool. Generate private and public key
      pair and configure ~/.ssh/config file to use them.

      USAGE:
      =====
      $(print_usage | sed 's/^/,/')

      PARAMS:
      ======
      ACCOUNT   Github account name, only used to make cert filename, for SSH
     ,          connection 'git' user will be used.
      --        End of options
      --ask     Provoke a prompt for all params
      --host    SSH host match pattern
      --comment Certificate comment

      DEMO:
      ====
      # Generate with all defaults to PK file ~/.ssh/${DEFAULTS[host]}/${DEFAULTS[account]}
      ${THE_SCRIPT}

      # Generate to ~/.ssh/${DEFAULTS[host]}/${ACCOUNT}
      ${THE_SCRIPT} ${ACCOUNT} --host github.com-${ACCOUNT} --comment Zoo
    "
  }

  parse_params() {
    declare -a invals

    declare endopts=false
    declare param
    while [[ ${#} -gt 0 ]]; do
      ${endopts} && param='*' || param="${1}"

      case "${param}" in
        --            ) endopts=true ;;
        -\?|-h|--help ) print_help; exit ;;
        --usage       ) print_usage; exit ;;
        --ask         ) DOWNSTREAM+=(--ask) ;;
        --host        ) DOWNSTREAM+=(--host "${@:2:1}"); shift ;;
        --comment     ) DOWNSTREAM+=(--comment "${@:2:1}"); shift ;;
        -*            ) invals+=("${1}") ;;
        *             ) DOWNSTREAM+=("${1}") ;;
      esac

      shift
    done

    DOWNSTREAM+=(-- "${invals[@]}")
  }

  main() {
    parse_params "${@}"

    LH_PARAMS_ASK_EXCLUDE='
      HOSTNAME
      PORT
    ' "${DOWNSTREAM[@]}"
  }

  main "${@}"
)
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
  local offset; offset="$(grep '[^ ]' <<< "${content}" | grep -o '^\s*' | sort | head -n 1)"
  sed -e 's/^\s\{0,'${#offset}'\}//' -e 's/\s\+$//' <<< "${content}"
}
# .LH_SOURCED: {{/ lib/text.sh }}
# .LH_SOURCED: {{ short/ssh-gen-vc.sh }}
ssh_gen_vc() (
  { # Service vars
    declare -r SELF="${FUNCNAME[0]}"

    # If not a file, default to ssh-gen-vc.sh script name
    declare THE_SCRIPT="ssh-gen-vc.sh"
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
      ACCOUNT=git \
      PORT=22 \
      HOST=HOSTNAME \
      COMMENT='$(id -un)@$(hostname -f)'

    # Configure custom defaults
    lh_params_default_HOST() { lh_params get HOSTNAME; }
    lh_params_default_COMMENT() { printf -- '%s\n' "$(id -un)@$(hostname -f)"; }
  }

  print_usage() { text_nice "
    ${THE_SCRIPT} [--ask] [--host HOST=$(lh_params default-string HOST)] [--port PORT='$(lh_params default-string PORT)'] \\
   ,  [--comment COMMENT=\"$(lh_params default-string COMMENT)\"] [--] HOSTNAME [ACCOUNT=$(lh_params default-string ACCOUNT)]
  "; }

  print_help() {
    declare -r  hostname=github.com \
                account=bar

    text_nice "
      Generic version control system centric shortcut of ssh-gen.sh tool. Generate
      private and public key pair and configure ~/.ssh/config file to use them.

      USAGE:
      =====
      $(print_usage | sed 's/^/,/')

      PARAMS:
      ======
      HOSTNAME  VC system hostname
      ACCOUNT   VC system account name, only used to make cert filename, for SSH
     ,          connection 'git' user will be used.
      --        End of options
      --ask     Provoke a prompt for all params
      --host    SSH host match pattern
      --port    SSH port
      --comment Certificate comment

      DEMO:
      ====
      # Generate with all defaults to PK file ~/.ssh/${hostname}/$(lh_params default-string ACCOUNT)
      ${THE_SCRIPT} ${hostname}

      # Generate to ~/.ssh/${hostname}/${account} with custom hostname and comment
      ${THE_SCRIPT} ${hostname} ${account} --host ${hostname}-${account} --comment Zoo
    "
  }

  parse_params() {
    declare -a args

    declare endopts=false
    declare param
    while [[ ${#} -gt 0 ]]; do
      ${endopts} && param='*' || param="${1}"

      case "${param}" in
        -\?|-h|--help ) print_help; exit ;;
        --usage       ) print_usage; exit ;;
        --            ) endopts=true ;;
        --ask         ) lh_params set ASK true ;;
        --host        ) lh_params set HOST "${@:2:1}"; shift ;;
        --port        ) lh_params set PORT "${@:2:1}"; shift ;;
        --comment     ) lh_params set COMMENT "${@:2:1}"; shift ;;
        -*            ) lh_params unsupported "${1}" ;;
        *             ) args+=("${1}") ;;
      esac

      shift
    done

    [[ ${#args[@]} -gt 0 ]] && lh_params set HOSTNAME "${args[0]}"
    [[ ${#args[@]} -gt 1 ]] && lh_params set ACCOUNT "${args[1]}"
    [[ ${#args[@]} -lt 3 ]] || lh_params unsupported "${args[@]:2}"
  }

  trap_ask() {
    "$(lh_params get ASK)" || return 0

    lh_params ask-config \
      , HOSTNAME "VC HostName (%h for the target hostname): " \
      , ACCOUNT "VC user account name: " \
      , HOST "SSH Host: " \
      , PORT "SSH Host port: " \
      , COMMENT "Comment: "

    lh_params ask
  }

  check_params() {
    lh_params get HOSTNAME >/dev/null || lh_params_noval HOSTNAME

    lh_params is-blank HOSTNAME && lh_params errbag "HOSTNAME can't be blank"
    lh_params is-blank ACCOUNT  && lh_params errbag "ACCOUNT can't be blank"
    lh_params is-blank HOST     && lh_params errbag "HOST can't be blank"
    lh_params is-blank PORT     && lh_params errbag "PORT can't be blank"

    declare port; port="$(lh_params get PORT)" \
      && ! lh_params is-blank PORT \
      && ! is_port_valid "${port}" \
      && lh_params errbag "PORT='$(escape_single_quotes "${port}")' is invalid"
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

    declare -a downstream=(ssh_gen)
    declare filename host port comment hostname

    filename="$(lh_params get ACCOUNT)" && downstream+=(--filename "${filename}")
    host="$(lh_params get HOST)" && downstream+=(--host "${host}")
    port="$(lh_params get PORT)" && downstream+=(--port "${port}")
    comment="$(lh_params get COMMENT)" && downstream+=(--comment "${comment}")

    downstream+=( -- "$(lh_params get HOSTNAME)" git)

    "${downstream[@]}"
  }

  main "${@}"
)
# .LH_SOURCED: {{ bin/ssh-gen.sh }}
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

  print_usage() { text_nice "
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

      USAGE:
      =====
      $(print_usage | sed 's/^/,/')

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

      DEMO:
      ====
      # Generate with all defaults to PK file ~/.ssh/${HOSTNAME}/user
      ${THE_SCRIPT} ${HOSTNAME} user

      # Generate to ~/.ssh/${CUSTOM_DIR}/${CUSTOM_FILE} instead of ~/.ssh/%h/${USER}
     ${THE_SCRIPT} --host 'serv.com *.serv.com' --comment Zoo --dirname '${CUSTOM_DIR}' \\
     ,  --filename '${CUSTOM_FILE}' -- '%h' ${USER}

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
        --usage       ) print_usage; exit ;;
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

    (set -x; umask 0077; mkdir -p -- "${dest_dir}") || return

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
    identity_file="$(sed -e 's/^'"$(escape_sed_expr "${HOME}")"'/~/' <<< "${identity_file}")"

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
  declare -f "lh_params_set_${1}" &>/dev/null && { "lh_params_set_${1}" "${2}"; return $?; }
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
  declare -F "lh_params_get_${1}" &>/dev/null && { "lh_params_get_${1}"; return; }
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

    # Exclude ':*' adaptor suffix from pname
    LH_PARAMS_ASK["${pname%:*}"]+="${LH_PARAMS_ASK["${pname%:*}"]+$'\n'}${ptext}"
  done
}

lh_params_ask() {
  [[ -n "${LH_PARAMS_ASK_EXCLUDE+x}" ]] && {
    LH_PARAMS_ASK_EXCLUDE="$(
      # shellcheck disable=SC2001
      sed -e 's/^\s*//' -e 's/\s*$//' <<< "${LH_PARAMS_ASK_EXCLUDE}" \
      | grep -v '^$'
    )"
  }

  declare confirm pname question handler_id
  while ! ${confirm-false}; do
    for pname in "${LH_PARAMS_ASK_PARAMS[@]}"; do
      handler_id="$(
        set -o pipefail
        grep -o ':[^:]\+$' <<< "${pname}" | sed -e 's/^://'
      )" || handler_id=default
      pname="${pname%:*}"

      # Don't prompt for params in LH_PARAMS_ASK_EXCLUDE (text) list
      grep -qFx -- "${pname}" <<< "${LH_PARAMS_ASK_EXCLUDE}" && continue

      question="${LH_PARAMS_ASK[${pname}]}"
      "lh_params_ask_${handler_id}_handler" "${pname}" "${question}"
    done

    echo '============================' >&2

    confirm=nobool
    while ! to_bool "${confirm}" >/dev/null; do
      read -rp "YES (y) for proceeding or NO (n) to repeat: " confirm
      confirm="$(to_bool "${confirm}")"
    done
  done
}

lh_params_ask_default_handler() {
  declare pname="${1}"
  declare question="${2}"
  declare answer

  read -erp "${question}" -i "$(lh_params_get "${pname}")" answer
  lh_params_set "${pname}" "${answer}"
}

lh_params_ask_pass_handler() {
  declare pname="${1}"
  declare question="${2}"
  declare answer answer_repeat
  while :; do
    read -srp "${question}" answer
    echo >&2
    read -srp "Confirm ${question}" answer_repeat
    echo >&2

    [[ "${answer}" == "${answer_repeat}" ]] || {
      echo "Confirm value doesn't match! Try again" >&2
      continue
    }

    [[ -n "${answer}" ]] && lh_params_set "${pname}" "${answer}"
    break
  done
}

lh_params_ask_bool_handler() {
  declare pname="${1}"
  declare question="${2}"
  declare answer
  while :; do
    read -erp "${question}" -i "$(lh_params_get "${pname}")" answer

    answer="$(to_bool "${answer}")" || {
      echo "'${answer}' is not a valid boolean value! Try again" >&2
      continue
    }

    lh_params_set "${pname}" "${answer}"
    break
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
# .LH_SOURCED: {{/ lib/system.sh }}

# .LH_SOURCED: {{/ bin/ssh-gen.sh }}

# .LH_SOURCED: {{/ short/ssh-gen-vc.sh }}

# .LH_NOSOURCE

(return &>/dev/null) || {
  ssh_gen_github "${@}"
}
