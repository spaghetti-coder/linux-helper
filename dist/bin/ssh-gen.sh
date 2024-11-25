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

ssh_gen() (
  declare SELF="${FUNCNAME[0]}"

  declare SG_USER
  declare SG_HOSTNAME

  # SG_PORT
  # SG_HOST
  # SG_COMMENT
  # SG_DIRNAME
  # SG_FILENAME
  # SG_DEST_DIR

  declare ASK=false

  declare -a ERRBAG

  declare SG_DEST_DIR_ALIAS

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

  print_help() {
    declare -r \
      USER=foo \
      HOSTNAME=10.0.0.69 \
      CUSTOM_DIR=_.serv.com \
      CUSTOM_FILE=bar

    # If not a file, default to ssh-gen.sh script name
    declare THE_SCRIPT=ssh-gen.sh
    grep -q -m 1 -- '.' "${0}" 2>/dev/null && THE_SCRIPT="$(basename -- "${0}")"

    text_nice "
      Generate private and public key pair and manage Include entry in ~/.ssh/config
      file. For option replacements environment variables can be used, by prefixing
      env var with 'SG_', turning opt name to uppercase and replacing '-' with '_'
      (--dest-dir ~/serv.com/ => SG_DEST_DIR=\"\${HOME}/serv.com/\")
     ,
      USAGE:
      =====
      ${THE_SCRIPT} USER HOSTNAME [OPTIONS]
     ,
      PARAMS (=DEFAULT_VALUE):
      ======
      USER      SSH user
      HOSTNAME  The actual SSH host. When values like '%h' (the target hostname)
     ,          used, must provide --host and most likely --dirname
      --        End of options
      --port    (='22') SSH port
      --host    (=HOSTNAME) SSH host match pattern
      --comment   (=\$(id -un)@\$(hostname -f)) Certificate comment
      --dirname   (=HOSTNAME) Destination directory name
      --filename  (=USER) Destination file name
      --dest-dir  (=~/.ssh/HOSTNAME) Custom destination directory. In case the option
     ,            is provided --dirname option is ignored and Include entry won't be
     ,            created in ~/.ssh/config file. The directory will be autocreated
      --ask       Flag that will provoke a prompt all params
     ,
      DEMO:
      ====
      # Generate with all defaults to PK file ~/.ssh/serv.com/user
      ${THE_SCRIPT} user serv.com
     ,
      # Generate to ~/.ssh/${CUSTOM_DIR}/${CUSTOM_FILE} instead of ~/.ssh/${HOSTNAME}/${USER}
      SG_DIRNAME='${CUSTOM_DIR}' SG_HOST='serv.com *.serv.com' \\
     ,  ${THE_SCRIPT} --filename='${CUSTOM_FILE}' --comment Zoo -- ${USER} ${HOSTNAME}
     ,
      # Generate interactively to ~/my/certs/${USER} (will be prompted for params)
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
        --port        ) SG_PORT="${2}"; shift ;;
        --port=*      ) SG_PORT="${1#*=}" ;;
        --host        ) SG_HOST="${2}"; shift ;;
        --host=*      ) SG_HOST="${1#*=}" ;;
        --comment     ) SG_COMMENT="${2}"; shift ;;
        --comment=*   ) SG_COMMENT="${1#*=}" ;;
        --dirname     ) SG_DIRNAME="${2}"; shift ;;
        --dirname=*   ) SG_DIRNAME="${1#*=}" ;;
        --filename    ) SG_FILENAME="${2}"; shift ;;
        --filename=*  ) SG_FILENAME="${1#*=}" ;;
        --dest-dir    ) SG_DEST_DIR="${2}"; shift ;;
        --dest-dir=*  ) SG_DEST_DIR="${1#*=}" ;;
        --ask         ) ASK=true ;;
        *             ) args+=("${1}") ;;
      esac

      shift
    done

    [[ ${#args[@]} -gt 0 ]] && SG_USER="${args[0]}"
    [[ ${#args[@]} -gt 1 ]] && SG_HOSTNAME="${args[1]}"
    [[ ${#args[@]} -lt 3 ]] || {
      ERRBAG+=(
        "Unsupported params:"
        "$(printf -- '* %s\n' "${args[@]:2}")"
      )

      return 1
    }
  }

  trap_ask() {
    ! ${ASK} && return 0

    declare confirm

    while ! [[ "${confirm:-n}" == y ]]; do
      confirm=""

      read -erp "SSH user: " -i "${SG_USER}" SG_USER
      read -erp "HostName (%h for the target hostname): " -i "${SG_HOSTNAME}" SG_HOSTNAME
      read -erp "Host port: " -i "${SG_PORT:-22}" SG_PORT
      read -erp "Host: " -i "${SG_HOST:-${SG_HOSTNAME}}" SG_HOST
      read -erp "Comment: " -i "${SG_COMMENT:-$(id -un)@$(hostname -f)}" SG_COMMENT
      read -erp "Directory name: " -i "${SG_DIRNAME:-${SG_HOSTNAME}}" SG_DIRNAME
      read -erp "File name: " -i "${SG_FILENAME:-${SG_USER}}" SG_FILENAME
      read -erp "Custom destination directory: " -i "${SG_DEST_DIR}" SG_DEST_DIR

      echo '============================'

      while [[ ! " y n " == *" ${confirm} "* ]]; do
        read -rp "YES (y) for proceeding or NO (n) to repeat: " confirm
        [[ "${confirm,,}" == yes ]] && confirm=y
        [[ "${confirm,,}" == no ]] && confirm=n
        confirm="${confirm,,}"
      done
    done
  }

  validate_required_args() {
    declare rc=0
    [[ -n "${SG_USER}" ]]     || { rc=1; ERRBAG+=("USER is required"); }
    [[ -n "${SG_HOSTNAME}" ]] || { rc=1; ERRBAG+=("HOSTNAME is required"); }
    return ${rc}
  }

  flush_errbag() {
    echo "FATAL (${SELF})"
    printf -- '%s\n' "${ERRBAG[@]}"
  }

  apply_defaults() {
    SG_PORT="${SG_PORT:-22}"
    SG_HOST="${SG_HOST:-${SG_HOSTNAME}}"
    SG_COMMENT="${SG_COMMENT:-$(id -un)@$(hostname -f)}"
    SG_DIRNAME="${SG_DIRNAME:-${SG_HOSTNAME}}"
    SG_FILENAME="${SG_FILENAME:-${SG_USER}}"

    SG_DEST_DIR_ALIAS="${SG_DEST_DIR}"
    if [[ -z "${SG_DEST_DIR:+x}" ]]; then
      SG_DEST_DIR="${HOME}/.ssh/${SG_DIRNAME}"
      # shellcheck disable=SC2088
      SG_DEST_DIR_ALIAS="~/$(realpath -m --relative-to="${HOME}" "${HOME}/.ssh/${SG_DIRNAME}")"
    else
      CUSTOM_DEST_DIR=true
    fi

    PK_PATH="${SG_DEST_DIR}/${SG_FILENAME}"
    PK_PATH_ALIAS="${SG_DEST_DIR_ALIAS}/${SG_FILENAME}"

    PUB_PATH="${PK_PATH}.pub"
    PUB_PATH_ALIAS="${PK_PATH_ALIAS}.pub"

    PK_CONFFILE_PATH="${PK_PATH}.config"
    PK_CONFFILE_PATH_ALIAS="${PK_PATH_ALIAS}.config"
  }

  gen_key() {
    declare dest_dir; dest_dir="$(dirname -- "${PK_PATH}")"

    (set -x; mkdir -p "${dest_dir}") || return

    if ! cat -- "${PK_PATH}" &>/dev/null; then
      (set -x; ssh-keygen -q -N '' -b 4096 -t rsa -C "${SG_COMMENT}" -f "${PK_PATH}") || return
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

    declare conf="
      # SSH host match pattern. Sample:
      #   myserv.com
      #   *.myserv.com myserv.com
      Host ${SG_HOST}
        # The actual SSH host. Sample:
        #   10.0.0.69
        #   google.com
        #   %h # (referehce to matched Host)
        HostName ${SG_HOSTNAME}
        Port ${SG_PORT}
        User ${SG_USER}
        IdentityFile ${identity_file}
        IdentitiesOnly yes
    "

    printf -- '%s\n' "${conf}" \
      | grep -v '^\s*$' | sed -e 's/^\s\+//' -e '5,$s/^/  /' \
      | (set -x; tee -- "${PK_CONFFILE_PATH}" >/dev/null) \
    && {
      # Include in ~/.ssh/config
      grep -qFx -- "${confline}" "${ssh_conffile}" 2>/dev/null && return

      ${CUSTOM_DEST_DIR} && return

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
     ,  ssh-copy-id -i ${PUB_PATH_ALIAS} -p ${SG_PORT} ${SG_USER}@${SG_HOSTNAME}
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
       ,  cp -r ${SG_DEST_DIR} ${ssh_dir}
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
    parse_params "${@}" \
    && trap_ask \
    && validate_required_args \
    || { flush_errbag; return 1; }

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
