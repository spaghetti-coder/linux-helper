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

# .LH_SOURCE:lib/basic.sh
# .LH_SOURCE:lib/lh-params.sh
# .LH_SOURCE:lib/system.sh
# .LH_SOURCE:lib/text.sh

# .LH_NOSOURCE

(return &>/dev/null) || {
  ssh_gen "${@}"
}
