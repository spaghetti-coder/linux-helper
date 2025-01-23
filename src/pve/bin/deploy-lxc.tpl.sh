#!/usr/bin/env bash

# Allows config callbacks nesting.
# Config function can be renamed.
DEPLOY_LXC_CONFIGS+=(lxc_config)

lxc_config() {
  # `get_next_id` generates next available CT_ID. With this each run of the
  # script will trigger creating of a new container. Consider using a
  # hardcoded numeric value instead for stable deployments
  CT_ID="$(get_next_id)"

  # Best guess hint from: http://download.proxmox.com/images/system
  TEMPLATE=ubuntu-24.04

  # Params to `pct create` command
  CREATE_PARAMS=(
    # --net0='name=eth0,bridge=vmbr0,ip=10.0.0.69/8,gw=10.0.0.1'
    --net0='name=eth0,bridge=vmbr0,ip=dhcp'
    # `pick_rootdir` to automanage STORAGE_ID
    --storage="$(pick_rootdir)" # local-lvm
    --rootfs=5  # In GB, optional
    --unprivileged=1
    # Don't git-commit plain password, at least hashed with:
    #   # https://bamtech.medium.com/how-to-create-a-hashed-password-1b85a4ebe54
    #   openssl passwd -6 -stdin <<< PASSWORD
    --password='changeme'
  )

  # Params to `pct set` command
  SET_PARAMS=(
    --timezone=host
    --onboot=0
    --memory=512 # In MB, optional
    --cores=1 # Optional, defaulta to all from PVE host
    --hostname=lh-lxc # Optional
    --tags='lh-lxc;changeme' # Optional, semicolon separated
    # --features='nesting=1,keyctl=1' # Automanaged according to PRIVILEGED
    # --swap=512 # In MB, optional
    # --mp0=local-lvm:2 # Allocate new volume, STORAGE_ID:SIZE_IN_GiB
  )

  # Postdeploy stage available variables:
  # * CT_ID       Actual container id
  # * PRIVILEGED  Actual privileged state with value of true / false
  # * ONBOOT      Actual onboot with value of true / false
  # * OS_TYPE     Actual Guest OS type
  # * HOST_NAME   Actual hostname

  # Better prefix hooks with 'lxc_' to avoid overriding
  # of deploy_lxc internal functions
  PREDEPLOY=(lxc_predeploy_dummy)
  POSTDEPLOY=(lxc_postdeploy_dummy)
}

lxc_distant_deploy() {
  # Just edit the function and place its name in the very beginning
  # of DEPLOY_LXC_CONFIGS list for remote deployment

  local REMOTE_8EVhoN6FkB3l3ylD=my-pve-server.home

  # If current FQDN is one of supported masters (one by line)
  hostname -f | grep -qFxf <(text_nice "
    deployment-master-server.home
  ") && [[ -n "${REMOTE_8EVhoN6FkB3l3ylD}" ]] || return 0

  log_info "Distant deployment (${REMOTE_8EVhoN6FkB3l3ylD})"

  # Promote self functions to remote PVE removing remote
  # deployment marker and execute deploy_lxc entrypoint

  # shellcheck disable=SC2029
  {
    declare -p DEPLOY_LXC_CONFIGS 2>/dev/null
    declare -f | sed -e '/REMOTE_8EVhoN6FkB3l3ylD[=]/d'
  } | ssh "${REMOTE_8EVhoN6FkB3l3ylD}" "
    pveversion >/dev/null || exit
    /bin/bash <(cat; echo 'deploy_lxc main')
  "

  if test ${?} -gt 0; then
    log_fatal "Distant deployment FAILURE (${REMOTE_8EVhoN6FkB3l3ylD})"
    exit 1
  fi

  log_info "Distant deployment SUCCESS (${REMOTE_8EVhoN6FkB3l3ylD})"
  exit
}

# shellcheck disable=SC2317
lxc_predeploy_dummy() {

  return

  # DEMO USAGE:

  if ! do_lxc exists; then true
    # Avoid keeping ROOT_PASS in config in clear text,
    # you can get it from filesystem instead:
    CREATE_PARAMS+=(--password "$(cat ~/secrets/my-virtenv.pass)") || return
  fi

  # Do something more
}

# shellcheck disable=SC2317
lxc_postdeploy_dummy() {

  return

  # DEMO USAGE:

  # Use pre-defined profiles to configure VM for some purpose

  # Includes 'profile_ensure_user'
  profile_ensure_sudoer username "$(openssl passwd -6 -stdin <<< changeme)" 1001 || return
  profile_vaapi || return
  profile_vpn_ready || return
  # Install docker. Includes profile_docker_ready
  # Only centos-like, debian/ubuntu-like and alpine supported
  profile_ensure_docker || return
  ###
  ### Included profiles
  ###
  # # Only makes VM ready for docker, doesn't install
  # profile_docker_ready || return
  #
  # # You'll most likely want bash.
  # # Only centos-like, debian/ubuntu-like and alpine supported
  # profile_ensure_bash || return
  #
  # # Includes profile_ensure_bash. Password must be in hashed form. UID is optional
  # profile_ensure_user username "$(openssl passwd -6 -stdin <<< changeme)" 1001 || return
  #

  log_info "Bind-mount some dir"
  declare do_reboot; do_reboot="$(
    do_lxc ensure_confline \
      "lxc.mount.entry: /pve/dir lxc/dir none bind,create=dir 0 0"
  )" || { log_fatal "Can't mount"; return 1; }

  if ${do_reboot}; then
    (set -x; pct reboot "${CT_ID}" && sleep 5) \
    || return
  fi

  (
    # In-container callback
    upgrade() {
      # Only when systemd is available, otherwise only `! is_pve`
      if systemd-detect-virt >/dev/null 2>&1 && ! is_pve >/dev/null 2>&1; then
        log_info "Guest action ..."

        set -x
        apt-get update -q
        DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -qy

        return
      fi

      log_info "Upgrading container OS"
      do_lxc_attach -- /bin/sh -c "$(declare -f log_info "${FUNCNAME[0]}"); ${FUNCNAME[0]}"
    }

    upgrade || exit
  )
}

# ^^^^^^^^^^^^^^^^^^^^^
# ^^^ END OF CONFIG ^^^





# shellcheck disable=SC2317
deploy_lxc() (
  declare -g SELF="${FUNCNAME[0]}"

  main() {
    parse_params "${@}" || return

    init_internal_vars

    process_configs || return
    run_predeploy || return

    ensure_container || return
    update_config

    configure_container || return
    update_config

    # Detect started state
    declare was_up=false
    do_lxc is_up && was_up=true

    # Give it some time to warm up, less for alpine
    declare -i warm=15
    [[ "${OS_TYPE}" == alpine ]] && warm=5

    do_lxc ensure_up "${warm}" && {
      # Always run this to fix AlmaLinux 8 GPG issue
      profile_fix_almalinux8_gpg
    } && {
      # Perform postdeploys
      run_postdeploy
    }
    declare RC=$?

    declare ct_marker="${CT_ID}${HOST_NAME:+ (${HOST_NAME})}"
    if ${was_up} || ${ONBOOT}; then
      log_info "Starting the container: ${ct_marker}"
      do_lxc ensure_up 0
    else
      log_info "Shutting down the container: ${ct_marker}"
      do_lxc ensure_down
    fi

    return "${RC}"
  }

  parse_params() {
    declare -a invals

    while [[ ${#} -gt 0 ]]; do
      case "${1}" in
        -\?|-h|--help   ) print_help; exit ;;
        *               ) invals+=("${1} invalid argument") ;;
      esac


      shift
    done

    [[ ${#invals[@]}  -lt 1 ]] || {
      log_fatal "${invals[@]}"
      return 1
    }
  }

  print_help() {
    text_nice "
      Just clone the current script and edit the config section in the file top.
      Review all the configuration sections for demo usage.
    "
  }

  init_internal_vars() {
    declare -ga DL_TOOL; download_tool DL_TOOL || return
    declare -g TEMPLATE_FILE

    declare -gr \
      TEMPLATES_HOME=/var/lib/vz/template/cache \
      TEMPLATES_URL=http://download.proxmox.com/images/system

    declare -g \
      CT_ID \
      TEMPLATE \
      PRIVILEGED \
      ONBOOT \
      OS_TYPE \
      HOST_NAME
    declare -ga \
      CREATE_PARAMS \
      SET_PARAMS \
      PREDEPLOY \
      POSTDEPLOY
  }

  # HELPERS
  # ,,,,,,,

  do_lxc()        { lxc_do "${CT_ID}" "${@}"; }
  do_lxc_attach() { lxc-attach -n "${CT_ID}" "${@}"; }

  get_next_id()   { pvesh get /cluster/nextid; }
  list_rootdirs() { pvesm status -content rootdir | cut -d' ' -f1 | tail -n +2; }
  pick_rootdir()  { list_rootdirs | grep -m 1 '.\+'; }
  is_pve()        { pveversion &>/dev/null; }

  log_info()  { printf -- '### ('"${SELF}"') info: %s\n' "${@}" >&2; }
  log_warn()  { printf -- '### ('"${SELF}"') warn: %s\n' "${@}" >&2; }
  log_fatal() { echo '###' >&2; printf -- '### ('"${SELF}"') FATAL: %s\n' "${@}" >&2; echo '###' >&2; }

  # PRE-DEPLOY
  # ,,,,,,,,,,

  process_configs() {
    log_info "Exporting configs ..."

    declare -a  create_params set_params \
                predeploy postdeploy
    declare c; for c in "${DEPLOY_LXC_CONFIGS[@]}"; do
      # Reset from the previous iteration
      CREATE_PARAMS=(); SET_PARAMS=()
      PREDEPLOY=(); POSTDEPLOY=()

      "${c}" || {
        log_fatal "Can't run config function: '${c}'"
        return 1
      }

      create_params+=("${CREATE_PARAMS[@]}")
      set_params+=("${SET_PARAMS[@]}")
      predeploy+=("${PREDEPLOY[@]}")
      postdeploy+=("${POSTDEPLOY[@]}")
    done

    CREATE_PARAMS=("${create_params[@]}")
    SET_PARAMS=("${set_params[@]}")

    # shellcheck disable=SC2128,SC2178
    predeploy="$(
      printf -- '%s\n' "${predeploy[@]}" \
      | uniq_ordered | grep '.\+'
    )" && mapfile -t PREDEPLOY <<< "${predeploy}"

    # shellcheck disable=SC2128,SC2178
    postdeploy="$(
      printf -- '%s\n' "${postdeploy[@]}" \
      | uniq_ordered | grep '.\+'
    )" && mapfile -t POSTDEPLOY <<< "${postdeploy}"
  }

  run_predeploy() {
    declare hook; for hook in "${PREDEPLOY[@]}"; do
      log_info "Running '${hook}' hook ..."
      "${hook}" || {
        log_fatal "Hook '${hook}' failed"
        return 1
      }
    done
  }

  # DEPLOY
  # ,,,,,,

  templates_list() (
    set -o pipefail
    (set -x; "${DL_TOOL[@]}" "${TEMPLATES_URL}") \
    | grep -o 'href="[^"]\+\.tar\..\+"' \
    | sed -e 's/^href="\(.\+\)"/\1/' | sort -V
  )

  detect_template_url() {
    [[ "${1}" =~ ^https?:\/\/ ]] && { echo "${1}"; return; }

    declare template_rex; template_rex="$(escape_sed_expr "${1}")"
    templates_list | (
      set -o pipefail
      grep "^${template_rex}" | tail -n 1 | {
        printf -- '%s/' "${TEMPLATES_URL}"; cat
      }
    )
  }

  ensure_template_file() {
    log_info "Detecting template ..."

    declare template_url; template_url="$(detect_template_url "${TEMPLATE}")" || {
      log_fatal "Can't detect template url for '${TEMPLATE}'"
      return 1
    }

    declare filename; filename="$(basename -- "${template_url}")"
    TEMPLATE_FILE="${TEMPLATES_HOME}/${filename}"

    cat -- "${TEMPLATE_FILE}" &>/dev/null && return

    log_info "Downloading template '${filename}' ..."

    (set -x; "${DL_TOOL[@]}" "${template_url}" | tee -- "${TEMPLATE_FILE}" >/dev/null) || {
      (set -x; rm -f "${TEMPLATE_FILE}")
      log_fatal "Can't download template to '${TEMPLATE_FILE}'"
      return 1
    }
  }

  ensure_container() {
    do_lxc exists && { log_warn "Container already exists"; return; }

    ensure_template_file || return

    log_info "Deploying ${CT_ID}${HOST_NAME:+ (${HOST_NAME})}"

    declare -a cmd=(
      pct create "${CT_ID}" "${TEMPLATE_FILE}" "${CREATE_PARAMS[@]}"
    )
    declare pass_rex='\(--password[= ]\)[^ ]\+'

    # Ensure there is no hook
    do_lxc unhookscript || return

    ( set -o pipefail
      (set -x; "${cmd[@]}" >/dev/null) 3>&1 1>&2 2>&3 \
      | sed -e 's/'"${pass_rex}"'/\1*****/g'
    ) 3>&1 1>&2 2>&3 || {
      log_fatal "Can't create container"
      return 1
    }
  }

  update_config() {
    declare conftext; conftext="$(do_lxc conffile_head)" || return
    declare -a val_filter=(sed -e 's/^[^:]\+:\s*\([^ ]\+\)\s*$/\1/')

    PRIVILEGED="$(grep -q -m 1 '^\s*unprivileged:\s*1\s*$' <<< "${conftext}" && echo false || echo true)"
    ONBOOT="$(grep -q -m 1 '^\s*onboot:\s*1\s*$' <<< "${conftext}" && echo true || echo false)"
    OS_TYPE="$(grep -m 1 '^\s*ostype\s*:\s*' <<< "${conftext}" | "${val_filter[@]}")"
    HOST_NAME="$(grep -m 1 '^\s*hostname:\s*' <<< "${conftext}" | "${val_filter[@]}")"
  }

  configure_container() {
    log_info "Configuring ${CT_ID}${HOST_NAME:+ (${HOST_NAME})} ..."

    if [[ ${#SET_PARAMS[@]} -gt 0 ]]; then
      (set -x; pct set "${CT_ID}" "${SET_PARAMS[@]}" >/dev/null) || {
        log_fatal "Can't apply configuration"
        return 1
      }
    fi

    # Features are automanaged

    declare conftext; conftext="$(do_lxc conffile_head)" || return
    declare features; features="$(
      grep '^\s*features:' <<< "${conftext}" \
      | sed -e 's/[^:]*:\s*\(.*\)$/\1/' \
            -e 's/\(nesting\|keyctl\)=[01]//g' \
            -e 's/^,\+//' -e 's/,\+\s*$//'
    )"

    features+="${features:+,}nesting=1"
    ${PRIVILEGED} || features+=",keyctl=1"
    (set -x; pct set "${CT_ID}" --features "${features}" >/dev/null) || {
      log_fatal "Can't apply configuration"
      return 1
    }
  }

  # POST-DEPLOY
  # ,,,,,,,,,,,

  run_postdeploy() {
    declare hook; for hook in "${POSTDEPLOY[@]}"; do
      log_info "Running '${hook}' hook ..."
      "${hook}" || {
        log_fatal "Hook '${hook}' failed"
        return 1
      }
    done
  }

  # PROFILES
  # ,,,,,,,,

  profile_fix_almalinux8_gpg() {
    # https://almalinux.org/blog/2023-12-20-almalinux-8-key-update/

    if ! is_pve >/dev/null 2>&1; then
      log_info "Guest action ..."

      # shellcheck disable=SC1091
      (. /etc/os-release; echo "${ID}:$(rpm -E '%{rhel}')") \
      | grep -qFx 'almalinux:8' || return 0

      ( set -x
        rpm --import https://repo.almalinux.org/almalinux/RPM-GPG-KEY-AlmaLinux
      )

      return
    fi

    ! [[ "${OS_TYPE}" == centos ]] && return

    log_info "Profile: Fix AlmaLinux 8 GPG key"

    do_lxc_attach -- /bin/sh -c "$(declare -f log_info "${FUNCNAME[0]}"); ${FUNCNAME[0]}"
  }

  profile_ensure_bash() {
    if ! is_pve >/dev/null 2>&1; then
      log_info "Guest action ..."

      _pm_install bash

      return
    fi

    log_info "Profile: Ensure bash"

    do_lxc_attach -- /bin/sh -c "$(declare -f log_info _pm_install "${FUNCNAME[0]}"); ${FUNCNAME[0]}"
  }

  profile_ensure_user() {
    local login="${1}" pass="${2}" uid="${3}"

    if ! is_pve &>/dev/null; then
      log_info "Guest action ..."

      useradd --help &>/dev/null || (
        _pm_install shadow \
        || _pm_install shadow-utils
      ) || return

      declare -a group_mod=(groupmod "${login}")
      declare -a user_mod=(usermod -g "${login}" -s /bin/bash "${login}")

      [[ -n "${uid}" ]] && {
        group_mod+=(-g "${uid}"); user_mod+=(-u "${uid}")
      }

      (set -x; groupadd -f "${login}" && "${group_mod[@]}" >/dev/null) \
      && { id -- "${login}" &>/dev/null || (set -x; useradd -N -m "${login}"); } \
      && (set -x; "${user_mod[@]}" >/dev/null) \
      && (set -x; chpasswd -e <<< "${login}:${pass}")

      return
    fi

    profile_ensure_bash || return

    log_info "Profile: Ensure user '${login}' (${CT_ID}) ..."

    do_lxc_attach -- /bin/bash -c "$(
      declare -f log_info _pm_install "${FUNCNAME[0]}"
    ); ${FUNCNAME[0]} \
      '$(escape_single_quotes "${login}")' \
      '$(escape_single_quotes "${pass}")' \
      '$(escape_single_quotes "${uid}")'
    "
  }

  profile_ensure_sudoer() (
    local login="${1}" pass="${2}" uid="${3}"

    if ! is_pve >/dev/null 2>&1; then
      log_info "Guest action ..."

      _pm_install sudo || return

      local sudo_group=sudo
      getent group wheel >/dev/null 2>&1 && sudo_group=wheel

      (set -x; usermod -aG "${sudo_group}" "${login}" >/dev/null) || return

      if [ "${sudo_group}" = wheel ]; then
        echo '%wheel ALL=(ALL) ALL' | (set -x; tee /etc/sudoers.d/wheel >/dev/null)
      fi

      return
    fi

    profile_ensure_user "${login}" "${pass}" "${uid}" || return

    log_info "Profile: Ensure sudoer '${login}' (${CT_ID}) ..."

    do_lxc_attach -- /bin/sh -c "$(
      declare -f log_info _pm_install "${FUNCNAME[0]}"
    ); ${FUNCNAME[0]} \
      '$(escape_single_quotes "${login}")'
    " || return
  )

  profile_docker_ready() {
    if ! is_pve >/dev/null 2>&1; then
      log_info "Guest action ..."

      (set -x; rc-update add cgroups default >/dev/null)

      return
    fi

    log_info "Profile: Docker ready"

    # Some instruction:
    # https://gist.github.com/afanjul/492ca7b10982f6de2cb2c475fe76af6a

    # # The following seems to be not needed:
    # --unprivileged=0
    # do_lxc ensure_confline 'lxc.apparmor.profile: unconfined'

    if ${PRIVILEGED}; then
      local do_reboot; do_reboot="$(
        do_lxc ensure_confline 'lxc.cap.drop:'
      )" || return

      if ${do_reboot}; then
        ( set -x
          pct reboot "${CT_ID}" && sleep 5
        ) || return
      fi
    fi

    ! [[ "${OS_TYPE}" == alpine ]] && return

    do_lxc_attach -- /bin/sh -c "$(declare -f log_info "${FUNCNAME[0]}"); ${FUNCNAME[0]}"
  }

  profile_ensure_docker() (
    log_info "Profile: Docker"

    # shellcheck disable=SC1091
    install_docker_debian() (
      ! is_pve >/dev/null 2>&1 || return

      log_info "Guest action ..."

      local arch; arch="$(dpkg --print-architecture)"
      local codename; codename="$(. /etc/os-release; echo "${VERSION_CODENAME}")"
      local dist_id; dist_id="$(. /etc/os-release; echo "${ID}")"

      set -x

      # Insstall prereqs
      apt-get update -q >/dev/null \
      && apt-get install -qy ca-certificates curl >/dev/null \
      && install -m 0755 -d /etc/apt/keyrings || return

      # Add the repository to Apt sources:
      curl -fsSL "https://download.docker.com/linux/${dist_id}/gpg" -o /etc/apt/keyrings/docker.asc \
      && chmod a+r /etc/apt/keyrings/docker.asc \
      && {
        echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.asc] \
          https://download.docker.com/linux/${dist_id} ${codename} stable" \
        | tee /etc/apt/sources.list.d/docker.list >/dev/null
      } \
      && apt-get update -q >/dev/null || return

      # Install docker
      apt-get install -qy docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin >/dev/null || return

      apt-get clean -qy >/dev/null; apt-get autoremove -qy >/dev/null
      find /var/lib/apt/lists -mindepth 1 -maxdepth 1 -exec rm -rf {} \;
      return 0
    )

    # install_docker_ubuntu declaration
    eval "$(declare -f install_docker_debian | sed '1 s/debian/ubuntu/')"

    install_docker_centos() (
      ! is_pve >/dev/null 2>&1 || return

      log_info "Guest action ..."

      set -x
      dnf install -qy dnf-plugins-core >/dev/null \
      && dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo >/dev/null \
      && dnf install -qy docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null \
      && sudo systemctl enable -q --now docker >/dev/null \
      || return

      dnf autoremove -qy >/dev/null
      dnf --enablerepo='*' clean all -qy >/dev/null
      find /var/cache/dnf -mindepth 1 -maxdepth 1 -exec rm -rf {} \;
      return 0
    )

    install_docker_alpine() (
      ! is_pve >/dev/null 2>&1 || return

      log_info "Guest action ..."

      set -x
      apk add -q --update --no-cache \
        docker docker-cli-compose \
      && rc-update add -q docker boot \
      || return

      # The service produces some mysterious "limit"-related
      # error, but still starts
      service docker start >/dev/null 2>&1
    )

    declare callback="install_docker_${OS_TYPE}"
    declare -F "${callback}" &>/dev/null || {
      log_fatal "Unsupported platform for docker installation: '${OS_TYPE}'"
      return 1
    }

    profile_docker_ready || return

    do_lxc_attach -- /bin/sh -c "$(declare -f log_info "${callback}"); ${callback}"
  )

  profile_vpn_ready() {
    log_info "Profile: VPN ready"

    # https://pve.proxmox.com/wiki/OpenVPN_in_LXC

    declare -a conflines=(
      "lxc.mount.entry: /dev/net dev/net none bind,create=dir 0 0"
      "lxc.cgroup2.devices.allow: c 10:200 rwm"
    )
    # for GP client in cenos
    [[ "${OS_TYPE}" == centos ]] && conflines+=(
      "lxc.cap.drop:"
    )

    local do_reboot; do_reboot="$(
      do_lxc ensure_confline "${conflines[@]}"
    )" || return

    if ${do_reboot}; then
      ( set -x
        pct reboot "${CT_ID}" && sleep 5
      )
    fi
  }

  profile_vaapi() {
    log_info "Profile: VAAPI"

    declare do_reboot=false
    declare drm_dev=/dev/dri/renderD128

    if ! "${PRIVILEGED}"; then
      [[ -e "${drm_dev}" ]] || return 0

      declare card=/dev/dri/card0
      [[ -e "${card}" ]] || card=/dev/dri/card1

      do_reboot="$(
        do_lxc ensure_dev "${drm_dev},gid=104" "${card},gid=44"
      )" || return
    else
      do_reboot="$(
        do_lxc ensure_confline \
          "lxc.cgroup2.devices.allow: c 226:0 rwm" \
          "lxc.cgroup2.devices.allow: c 226:128 rwm" \
          "lxc.cgroup2.devices.allow: c 29:0 rwm" \
          "lxc.mount.entry: /dev/fb0 dev/fb0 none bind,optional,create=file" \
          "lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir" \
          "lxc.mount.entry: ${drm_dev} ${drm_dev#/*} none bind,optional,create=file"
      )" || return
    fi

    if ${do_reboot}; then
      ( set -x
        pct reboot "${CT_ID}" && sleep 5
      )
    fi
  }

  _pm_install() {
    apt-get --version >/dev/null 2>&1 && { (
      set -x
      apt-get update -q >/dev/null \
      && apt-get install -qy "${@}" >/dev/null
    ); return; }

    dnf --version >/dev/null 2>&1 && { (
      set -x
      dnf install -qy "${@}" >/dev/null
    ); return; }

    apk --version >/dev/null 2>&1 && { (
      set -x
      apk add -q --update --no-cache "${@}" >/dev/null
    ); return; }

    {
      echo '###'
      echo '### fatal: Unsupported distro'
      echo '###'
    } >&2
    return 1
  }

  # INVOKE
  # ,,,,,,

  declare -a EXPORTS=(
    main
  )

  if printf -- '%s\n' "${EXPORTS[@]}" | grep -qFx -- "${1//-/_}"; then
    "${1//-/_}" "${@:2}"
  else
    lh_params unsupported "${1}"; lh_params invalids >&2 && {
      echo "FATAL (${SELF})" >&2
      return 1
    }
  fi
)

# .LH_SOURCE:lib/basic.sh
# .LH_SOURCE:lib/system.sh
# .LH_SOURCE:lib/text.sh
# .LH_SOURCE:pve/lib/lxc-do.sh

# .LH_NOSOURCE

(return &>/dev/null) || deploy_lxc main "${@}"
