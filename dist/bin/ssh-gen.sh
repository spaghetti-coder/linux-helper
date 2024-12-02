#!/usr/bin/env bash
# .LH_SOURCED: {{ lib/text.sh }}
# shellcheck disable=SC2001
# shellcheck disable=SC2120
text_ltrim() { sed -e 's/^\s\+//' <<< "${1-$(cat)}"; }
text_rtrim() { sed -e 's/\s\+$//' <<< "${1-$(cat)}"; }
text_trim() { text_ltrim <<< "${1-$(cat)}" | text_rtrim; }
text_rmblank() { grep -v '^\s*$' <<< "${1-$(cat)}"; return 0; }
text_nice() { text_trim <<< "${1-$(cat)}" | text_rmblank | sed -e 's/^,//'; }
# .LH_SOURCED: {{/ lib/text.sh }}
# .LH_SOURCED: {{ lib/basic.sh }}
# https://stackoverflow.com/a/2705678
escape_sed_expr()  { sed -e 's/[]\/$*.^[]/\\&/g' <<< "${1-$(cat)}"; }
escape_sed_repl()  { sed -e 's/[\/&]/\\&/g' <<< "${1-$(cat)}"; }

escape_single_quotes()  { declare str="${1-$(cat)}"; cat <<< "${str//\'/\'\\\'\'}"; }
escape_double_quotes()  { declare str="${1-$(cat)}"; cat <<< "${str//\"/\"\\\"\"}"; }
# .LH_SOURCED: {{/ lib/basic.sh }}
# .LH_SOURCED: {{ base.ignore.sh }}
# USAGE:
#   declare -A LH_DEFAULTS=([PARAM_NAME]=VALUE)
#   lh_params_apply_defaults
# If LH_PARAMS[PARAM_NAME] is not set, it gets the value from LH_DEFAULTS
lh_params_apply_defaults() {
  [[ "$(declare -p LH_PARAMS 2>/dev/null)" == "declare -A"* ]] || declare -Ag LH_PARAMS
  [[ "$(declare -p LH_DEFAULTS 2>/dev/null)" == "declare -A"* ]] || declare -Ag LH_DEFAULTS

  declare p_name; for p_name in "${!LH_DEFAULTS[@]}"; do
    [[ -n "${LH_PARAMS[${p_name}]+x}" ]] || LH_PARAMS["${p_name}"]="${LH_DEFAULTS[${p_name}]}"
  done
}

lh_params_reset() {
  unset LH_PARAMS LH_PARAMS_NOVAL
  declare -Ag LH_PARAMS
  declare -ag LH_PARAMS_NOVAL
}

# USAGE:
#   lh_param_set PARAM_NAME VALUE
# Produces global LH_PARAMS[PARAM_NAME]=VALUE.
# When VALUE is not provided returns 1 and puts PARAM_NAME to LH_PARAMS_NOVAL global array
lh_param_set() {
  declare name="${1}"

  [[ -n "${2+x}" ]] || { lh_params_noval "${name}"; return 1; }

  [[ "$(declare -p LH_PARAMS 2>/dev/null)" == "declare -A"* ]] || declare -Ag LH_PARAMS
  LH_PARAMS["${name}"]="${2}"
}

lh_params_noval() {
  [[ "$(declare -p LH_PARAMS_NOVAL 2>/dev/null)" == "declare -a"* ]] || {
    unset LH_PARAMS_NOVAL
    declare -ag LH_PARAMS_NOVAL
  }

  [[ ${#} -gt 0 ]] && { LH_PARAMS_NOVAL+=("${@}"); return; }

  [[ ${#LH_PARAMS_NOVAL[@]} -gt 0 ]] || return 1
  printf -- '%s\n' "${LH_PARAMS_NOVAL[@]}"
}

# shellcheck disable=SC2120
lh_params_unsupported() {
  [[ "$(declare -p LH_PARAMS_UNSUPPORTED 2>/dev/null)" == "declare -a"* ]] || {
    unset LH_PARAMS_UNSUPPORTED
    declare -ag LH_PARAMS_UNSUPPORTED
  }

  [[ ${#} -gt 0 ]] && { LH_PARAMS_UNSUPPORTED+=("${@}"); return; }

  [[ ${#LH_PARAMS_UNSUPPORTED[@]} -gt 0 ]] || return 1
  printf -- '%s\n' "${LH_PARAMS_UNSUPPORTED[@]}"
}

lh_params_flush_invalid() {
  declare -i rc=1

  # shellcheck disable=SC2119
  declare unsup; unsup="$(lh_params_unsupported)" && {
    echo "Unsupported params:"
    printf -- '%s\n' "${unsup}" | sed -e 's/^/* /'
    rc=0
  }

  # shellcheck disable=SC2119
  declare noval; noval="$(lh_params_noval)" && {
    echo "Values required for:"
    printf -- '%s\n' "${noval}" | sed -e 's/^/* /'
    rc=0
  }

  return ${rc}
}
# .LH_SOURCED: {{/ base.ignore.sh }}

ssh_gen() (
  declare SELF="${FUNCNAME[0]}"

  # If not a file, default to ssh-gen.sh script name
  declare THE_SCRIPT=ssh-gen.sh
  grep -q -m 1 -- '.' "${0}" 2>/dev/null && THE_SCRIPT="$(basename -- "${0}")"

  # shellcheck disable=SC2034
  declare -A LH_DEFAULTS=(
    [PORT]="22"
    # [HOST]="${LH_PARAMS[HOSTNAME]}"
    # [COMMENT]="$(id -un)@$(hostname -f)"
    # [DIRNAME]="${LH_PARAMS[HOSTNAME]}"
    # [FILENAME]="${LH_PARAMS[USER]}"
    # [DEST_DIR]="${HOME}/.ssh/${LH_PARAMS[HOSTNAME]}"
  )

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

  print_help_usage() {
    echo "
      ${THE_SCRIPT} [--port PORT='22'] [--host HOST=HOSTNAME] \\
     ,  [--comment COMMENT=\"\$(id -un)@\$(hostname -f)\"] [--dirname DIRNAME=HOSTNAME] \\
     ,  [--filename FILENAME=USER] [--dest-dir DEST_DIR=\"\${HOME}/.ssh/\"HOSTNAME] \\
     ,  [--ask] [--] USER HOSTNAME
    "
  }

  print_help() {
    declare -r \
      USER=foo \
      HOSTNAME=10.0.0.69 \
      CUSTOM_DIR=_.serv.com \
      CUSTOM_FILE=bar

    text_nice "
      Generate private and public key pair and manage Include entry in ~/.ssh/config.
     ,
      USAGE:
      =====
      $(print_help_usage)
     ,
      PARAMS:
      ======
      USER      SSH user
      HOSTNAME  The actual SSH host. When values like '%h' (the target hostname)
     ,          used, must provide --host and most likely --dirname
      --        End of options
      --port    SSH port
      --host    SSH host match pattern
      --comment   Certificate comment
      --dirname   Destination directory name
      --filename  Destination file name
      --dest-dir  Custom destination directory. In case the option is provided
     ,            --dirname option is ignored and Include entry won't be created in
     ,            ~/.ssh/config file. The directory will be autocreated
      --ask       Provoke a prompt for all params
     ,
      DEMO:
      ====
      # Generate with all defaults to PK file ~/.ssh/serv.com/user
      ${THE_SCRIPT} user serv.com
     ,
      # Generate to ~/.ssh/${CUSTOM_DIR}/${CUSTOM_FILE} instead of ~/.ssh/${HOSTNAME}/${USER}
     ${THE_SCRIPT} --host 'serv.com *.serv.com' --dirname '${CUSTOM_DIR}' \\
     ,  --filename '${CUSTOM_FILE}' --comment Zoo -- ${USER} ${HOSTNAME}
     ,
      # Generate interactively to ~/my/certs/${USER} (will be prompted for params)
      ${THE_SCRIPT} --ask --dest-dir ~/my/certs/${USER}
    "
  }

  parse_params() {
    declare -a args

    lh_params_reset

    declare endopts=false
    declare param
    while [[ ${#} -gt 0 ]]; do
      ${endopts} && param='*' || param="${1}"

      case "${param}" in
        --            ) endopts=true ;;
        -\?|-h|--help ) print_help; exit ;;
        --usage       ) print_help_usage | text_nice; exit ;;
        --port        ) lh_param_set PORT "${@:2:1}"; shift ;;
        --host        ) lh_param_set HOST "${@:2:1}"; shift ;;
        --comment     ) lh_param_set COMMENT "${@:2:1}"; shift ;;
        --dirname     ) lh_param_set DIRNAME "${@:2:1}"; shift ;;
        --filename    ) lh_param_set FILENAME "${@:2:1}"; shift ;;
        --dest-dir    ) lh_param_set DEST_DIR "${@:2:1}"; shift ;;
        --ask         ) lh_param_set ASK true ;;
        -*            ) lh_params_unsupported "${1}" ;;
        *             ) args+=("${1}") ;;
      esac

      shift
    done

    [[ ${#args[@]} -gt 0 ]] && lh_param_set USER "${args[0]}"
    [[ ${#args[@]} -gt 1 ]] && lh_param_set HOSTNAME "${args[1]}"
    [[ ${#args[@]} -lt 3 ]] || lh_params_unsupported "${args[@]:2}"
  }

  trap_ask() {
    ! ${LH_PARAMS[ASK]-false} && return 0

    declare confirm

    while ! [[ "${confirm:-n}" == y ]]; do
      confirm=""

      read -erp "SSH user: " -i "${LH_PARAMS[USER]}" 'LH_PARAMS[USER]'
      read -erp "HostName (%h for the target hostname): " -i "${LH_PARAMS[HOSTNAME]}" 'LH_PARAMS[HOSTNAME]'
      read -erp "Host port: " -i "${LH_PARAMS[PORT]-22}" 'LH_PARAMS[PORT]'
      read -erp "Host: " -i "${LH_PARAMS[HOST]-${LH_PARAMS[HOSTNAME]}}" 'LH_PARAMS[HOST]'
      read -erp "Comment: " -i "${LH_PARAMS[COMMENT]-$(id -un)@$(hostname -f)}" 'LH_PARAMS[COMMENT]'
      read -erp "Directory name: " -i "${LH_PARAMS[DIRNAME]-${LH_PARAMS[HOSTNAME]}}" 'LH_PARAMS[DIRNAME]'
      read -erp "File name: " -i "${LH_PARAMS[FILENAME]-${LH_PARAMS[USER]}}" 'LH_PARAMS[FILENAME]'
      read -erp "Custom destination directory: " -i "${LH_PARAMS[DEST_DIR]}" 'LH_PARAMS[DEST_DIR]'

      echo '============================'

      while [[ ! " y n " == *" ${confirm} "* ]]; do
        read -rp "YES (y) for proceeding or NO (n) to repeat: " confirm
        [[ "${confirm,,}" =~ ^(y|yes)$ ]] && confirm=y
        [[ "${confirm,,}" =~ ^(n|no)$ ]] && confirm=n
      done
    done
  }

  check_required_params() {
    declare rc=0
    [[ -n "${LH_PARAMS[USER]}" ]]     || { rc=1; lh_params_noval USER; }
    [[ -n "${LH_PARAMS[HOSTNAME]}" ]] || { rc=1; lh_params_noval HOSTNAME; }
    return ${rc}
  }

  apply_defaults() {
    lh_params_apply_defaults

    LH_PARAMS[HOST]="${LH_PARAMS[HOST]-${LH_PARAMS[HOSTNAME]}}"
    LH_PARAMS[COMMENT]="${LH_PARAMS[COMMENT]-$(id -un)@$(hostname -f)}"
    LH_PARAMS[DIRNAME]="${LH_PARAMS[DIRNAME]-${LH_PARAMS[HOSTNAME]}}"
    LH_PARAMS[FILENAME]="${LH_PARAMS[FILENAME]-${LH_PARAMS[USER]}}"

    declare dest_dir_alias="${LH_PARAMS[DEST_DIR]}"
    if [[ -z "${LH_PARAMS[DEST_DIR]:+x}" ]]; then
      LH_PARAMS[DEST_DIR]="${HOME}/.ssh/${LH_PARAMS[DIRNAME]}"
      # shellcheck disable=SC2088
      dest_dir_alias="~/$(realpath -m --relative-to="${HOME}" -- "${LH_PARAMS[DEST_DIR]}")"
    else
      CUSTOM_DEST_DIR=true
    fi
    LH_PARAMS[DEST_DIR]="$(sed -e 's/\/*$//' <<< "${LH_PARAMS[DEST_DIR]}")"
    dest_dir_alias="$(sed -e 's/\/*$//' <<< "${dest_dir_alias}")"

    PK_PATH="${LH_PARAMS[DEST_DIR]}/${LH_PARAMS[FILENAME]}"
    PK_PATH_ALIAS="${dest_dir_alias}/${LH_PARAMS[FILENAME]}"

    PUB_PATH="${PK_PATH}.pub"
    PUB_PATH_ALIAS="${PK_PATH_ALIAS}.pub"

    PK_CONFFILE_PATH="${PK_PATH}.config"
    PK_CONFFILE_PATH_ALIAS="${PK_PATH_ALIAS}.config"
  }

  gen_key() {
    (set -x; mkdir -p "${LH_PARAMS[DEST_DIR]}") || return

    if ! cat -- "${PK_PATH}" &>/dev/null; then
      (set -x; ssh-keygen -q -N '' -b 4096 -t rsa -C "${LH_PARAMS[COMMENT]}" -f "${PK_PATH}") || return
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

    declare conf="
      # SSH host match pattern. Sample:
      #   myserv.com
      #   *.myserv.com myserv.com
      Host ${LH_PARAMS[HOST]}
        # The actual SSH host. Sample:
        #   10.0.0.69
        #   google.com
        #   %h # (referehce to matched Host)
        HostName ${LH_PARAMS[HOSTNAME]}
        Port ${LH_PARAMS[PORT]}
        User ${LH_PARAMS[USER]}
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
     ,  ssh-copy-id -i ${PUB_PATH_ALIAS} -p ${LH_PARAMS[PORT]} ${LH_PARAMS[USER]}@${LH_PARAMS[HOSTNAME]}
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
       ,  cp -r ${LH_PARAMS[DEST_DIR]} ${ssh_dir}
       ,  echo \"Include ${pk_conffile}\" > ~/.ssh/config
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
    # shellcheck disable=SC2015
    parse_params "${@}"
    trap_ask
    check_required_params

    lh_params_flush_invalid >&2 && {
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

# .LH_NOSOURCE

(return &>/dev/null) || {
  ssh_gen "${@}"
}
