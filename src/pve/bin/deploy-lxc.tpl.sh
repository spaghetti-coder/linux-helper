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
    # Or '...,ip=10.0.0.69/8,gw=10.0.0.1'. Don't forget IP prefix and GW
    --net0='name=eth0,bridge=vmbr0,ip=dhcp'
    # `pick_storage` to automanage STORAGE_ID
    --storage="$(pick_storage)" # local-lvm
    --rootfs=5  # In GB, optional
    --unprivileged=1
    # Don't keep plain password, hash with:
    #   # https://bamtech.medium.com/how-to-create-a-hashed-password-1b85a4ebe54
    #   openssl passwd -6 -salt "$(openssl rand -base64 8)" -stdin <<< PASSWORD
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

  # Predeploy stage available variables:
  # * LXC_CREATE  # Assoc key-val of CREATE_PARAMS without dashes
  # * LXC_SET     # Assoc key-val of SET_PARAMS without dashes
  #
  # Postdeploy stage available variables:
  # * CT_ID       With fixed container id
  # * OS_TYPE     Guest OS type
  # * PRIVILEGED  With value of true / false

  # Better prefix hooks with 'lxc_' to avoid overriding
  # of deploy_lxc internal functions
  PREDEPLOY_HOOKS=(lxc_predeploy_dummy "${PREDEPLOY_HOOKS[@]}")
  POSTDEPLOY_HOOKS=(lxc_postdeploy_dummy "${POSTDEPLOY_HOOKS[@]}")
}

# shellcheck disable=SC2317
lxc_predeploy_dummy() {

  return

  # DEMO USAGE:

  if ! do_lxc exists; then true
    # Avoid keeping ROOT_PASS in config in clear text,
    # you can get it from filesystem instead:
    ROOT_PASS="$(cat ~/secrets/my-virtenv.pass)"
  fi

  # Do something more
}

# TODO:
# * profile_comfort ?

# shellcheck disable=SC2317
lxc_postdeploy_dummy() {

  return

  # DEMO USAGE:

  # Use pre-defined profiles, configure VM for some purpose
  profile_vaapi
  profile_vpn_ready
  # Only makes VM ready for docker, doesn't install
  profile_docker_ready
  # Install docker. Includes profile_docker_ready
  # Only centos-like, debian/ubuntu-like and alpine supported
  profile_docker

  log_info "Bind-moun some dir"
  do_lxc ensure_confline \
    "lxc.mount.entry: /pve/dir lxc/dir none bind,create=dir 0 0" \
  || log_fatal "Can't mount"

  log_info "Upgrading container OS"
  (
    # In-container callback
    upgrade() {
      set -x
      apt-get update -q
      DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -qy
    }

    declare was_up=false
    do_lxc is_up && was_up=true
    # 15 secs to warm up
    do_lxc ensure_up 15 || { log_fatal "Can't start the container"; exit 1; }

    lxc_attach -- /bin/sh -c "$(declare -f update); update"

    if ! ${was_up}; then
      do_lxc ensure_down
    fi
  )
}

# ^^^^^^^^^^^^^^^^^^^^^
# ^^^ END OF CONFIG ^^^





# shellcheck disable=SC2317
deploy_lxc() (
  main() {
    export_configs || return
    run_predeploy || return
    validate_config || return

    declare existed=false
    do_lxc exists && existed=true

    ensure_container >/dev/null || return
    update_config

    # No need to break the process if container existed
    configure_container >/dev/null || { ! ${existed} && return 1; }

    # Always run this to fix AlmaLinux 8 GPG issue
    profile_fix_almalinux8_gpg

    process_postdeploy || { ! ${existed} && return 1; }

    if ${ONBOOT}; then
      log_info "Starting the container"
      do_lxc ensure_up 0
    fi
  }

  { # Internal vars
    declare -r SELF="${FUNCNAME[0]}"

    declare CT_ID TEMPLATE
    declare -a PCT_CREATE_PARAMS PCT_SET_PARAMS

    # Initial deployment options
    declare TEMPLATE \
            STORAGE \
            DISK \
            PRIVILEGED \
            ROOT_PASS \
            OS_TYPE \
            BRIDGE \
            IP \
            GATEWAY

    # Config deployment options
    declare RAM \
            SWAP \
            CORES \
            ONBOOT \
            HOST_NAME \
            TAGS=()

    declare -a  PREDEPLOY_HOOKS \
                POSTDEPLOY_HOOKS

    declare -a DL_TOOL; download_tool DL_TOOL
    declare -r TEMPLATES_URL=http://download.proxmox.com/images/system
    declare -r TEMPLATES_HOME=/var/lib/vz/template/cache
    declare TEMPLATE_FILE
  }

  # HELPERS
  # ,,,,,,,

  do_lxc() { lxc_do "${CT_ID}" "${@}"; }
  lxc_attach() { lxc-attach -n "${CT_ID}" "${@}"; }
  get_next_id() { pvesh get /cluster/nextid; }
  list_storages() { pvesm status -content rootdir | cut -d' ' -f1 | tail -n +2; }
  pick_storage() { list_storages | grep -m 1 '.\+'; }
  log_info() { printf -- '### ('"${SELF}"') info: %s\n' "${@}" >&2; }
  log_warn() { printf -- '### ('"${SELF}"') warn: %s\n' "${@}" >&2; }
  log_fatal() { echo '###' >&2; printf -- '### ('"${SELF}"') FATAL: %s\n' "${@}" >&2; echo '###' >&2; }

  # PRE-DEPLOY
  # ,,,,,,,,,,

  export_configs() {
    declare c; for c in "${DEPLOY_LXC_CONFIGS[@]}"; do
      "${c}" || return
    done
  }

  run_predeploy() {
    declare uniq; uniq="$(
      printf -- '%s\n' "${PREDEPLOY_HOOKS[@]}" \
      | uniq_ordered | grep '.\+'
    )" && mapfile -t uniq <<< "${uniq}"

    declare hook; for hook in "${uniq[@]}"; do
      log_info "Running '${hook}' hook"
      "${hook}" || {
        log_fatal "Hook '${hook}' failed"
        return 1
      }
    done
  }

  validate_config_ip() {
    declare label="${1}"
    declare ip="${2}"
    declare -n _errbag="${3}"
    declare prefix; prefix="$(cut -d'/' -f2- <<< "${ip}/" | sed 's/.$//')"

    {
      grep -qx '[0-9]\+' <<< "${prefix}" \
      && [[ ${prefix} -ge 0 ]] \
      && [[ ${prefix} -le 32 ]]
    } || _errbag+=("${label} has invalid prefix")

    ip="$(cut -d'/' -f1 <<< "${ip}/")"
    # https://stackoverflow.com/a/35701965
    if ! [[ "$ip" =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]; then
      _errbag+=("${label} invalid format")
    fi
  }

  validate_config() {
    declare -a errbag

    grep -qx '[1-9][0-9]\{2,\}' <<< "${CT_ID}" || errbag+=(
      "CT_ID must be a starting from 100 numeric"
    )

    declare -a opts_required
    declare -a opts_numeric=(RAM SWAP CORES)
    declare -a opts_bool=(ONBOOT)
    declare -a opts_arr=(TAGS)

    if ! do_lxc exists; then
      opts_required=(TEMPLATE ROOT_PASS BRIDGE "${opts_required[@]}")
      opts_numeric=(DISK "${opts_numeric[@]}")
      opts_bool=(PRIVILEGED "${opts_bool[@]}")

      list_storages | grep -qx "$(escape_sed_expr "${STORAGE}")" || errbag+=(
        "STORAGE invalid: '${STORAGE}'"
      )

      if [[ "${IP}" != dhcp ]]; then
        opts_required+=(GATEWAY)
        validate_config_ip IP "${IP}" errbag
        # Dummy prefix for GATEWAY
        validate_config_ip GATEWAY "${GATEWAY}/32" errbag
      fi
    fi

    declare opt; for opt in "${opts_required[@]}"; do
      grep -qx '.\+' <<< "${!opt}" || errbag+=(
        "${opt} is required"
      )
    done

    declare opt; for opt in "${opts_numeric[@]}"; do
      grep -qx '\([1-9][0-9]*\)\?' <<< "${!opt}" || errbag+=(
        "${opt} must be a numeric"
      )
    done

    declare opt; for opt in "${opts_bool[@]}"; do
      grep -qx '\(true\|false\)' <<< "${!opt}" || errbag+=(
        "${opt} must have a value of true or false"
      )
    done

    declare meta
    declare opt; for opt in "${opts_arr[@]}"; do
      meta="$(declare -p -- "${opt}" 2>/dev/null | head -n 1)"
      grep -q '^declare -a' <<< "${meta}" || {
        errbag+=("${opt} must be an array")
        continue
      }
    done

    declare hook; for hook in "${PREDEPLOY_HOOKS[@]}"; do
      declare -F "${hook}" &>/dev/null || errbag+=(
        "PREDEPLOY_HOOK function '${hook}' doesn't exist"
      )
    done

    declare hook; for hook in "${POSTDEPLOY_HOOKS[@]}"; do
      declare -F "${hook}" &>/dev/null || errbag+=(
        "POSTDEPLOY_HOOK function '${hook}' doesn't exist"
      )
    done

    [[ ${#errbag[@]} -lt 1 ]] || {
      log_fatal "${errbag[@]}"
      return 1
    }
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
    log_info "Detecting template"

    declare template_url; template_url="$(detect_template_url "${TEMPLATE}")" || {
      log_fatal "Can't detect template url for '${TEMPLATE}'"
      return 1
    }

    declare filename; filename="$(basename -- "${template_url}")"
    TEMPLATE_FILE="${TEMPLATES_HOME}/${filename}"

    cat -- "${TEMPLATE_FILE}" &>/dev/null && return

    log_info "Downloading template '${filename}'"

    (set -x; "${DL_TOOL[@]}" "${template_url}" | tee -- "${TEMPLATE_FILE}") || {
      log_fatal "Can't download '${filename}' to '${TEMPLATE_FILE}'"
      (set -x; rm -f "${TEMPLATE_FILE}")
      return
    }
  }

  ensure_container() {
    do_lxc exists && { log_warn "Container already exists"; return; }

    ensure_template_file || return

    log_info "Deploying ${CT_ID}${HOST_NAME:+ (${HOST_NAME})}"

    declare net="name=eth0,bridge=${BRIDGE},ip=${IP}"
    [[ -n "${GATEWAY}" ]] && net+=",gw=${GATEWAY}"

    declare -a cmd=(
      pct create "${CT_ID}" "${TEMPLATE_FILE}"
        --unprivileged "$(${PRIVILEGED}; echo $?)"
        --net0 "${net}"
        --password "${ROOT_PASS}"
        --storage "${STORAGE}"
    )

    [[ -n "${OS_TYPE}" ]] && cmd+=(--ostype "${OS_TYPE}")
    [[ -n "${DISK}" ]] && cmd+=(--rootfs "${DISK}")

    ( set -o pipefail
      (set -x; "${cmd[@]}") 3>&1 1>&2 2>&3 \
      | sed -e 's/\( --password \)\(.\+\)\( --storage .\+\)/\1*****\3/'
    ) 3>&1 1>&2 2>&3 || {
      log_fatal "Can't create container"; return 1
    }
  }

  update_config() {
    declare conftext; conftext="$(pct config "${CT_ID}" --current)" || return

    OS_TYPE="$(grep -m 1 '^\s*ostype\s*:\s*' <<< "${conftext}" | sed -e 's/^.\+:\s*\([^ ]\+\)\s*$/\1/')"
    PRIVILEGED="$(grep -q -m 1 '^\s*unprivileged:\s*1\s*$' <<< "${conftext}" && echo false || echo true)"
  }

  configure_container() {
    log_info "Configurint ${CT_ID}${HOST_NAME:+ (${HOST_NAME})}"

    declare features; features='nesting=1'
    ${PRIVILEGED} || features+=",keyctl=1"

    declare -a cmd=(
      pct set "${CT_ID}" --timezone host
      --features "${features}"
      --onboot "$(! ${ONBOOT}; echo $?)"
    )

    [[ -n "${RAM}" ]] && cmd+=(--memory "${RAM}")
    [[ -n "${SWAP}" ]] && cmd+=(--swap "${SWAP}")
    [[ -n "${CORES}" ]] && cmd+=(--cores "${CORES}")
    [[ -n "${HOST_NAME}" ]] && cmd+=(--hostname "${HOST_NAME}")
    [[ ${#TAGS[@]} -gt 0 ]] && cmd+=(
      --tags "$(text_trim "${TAGS[*]}" | sed -e 's/\s\+/;/g')"
    )

    (set -x; "${cmd[@]}") || {
      log_fatal "Can't apply configuration"; return 1
    }
  }

  # POST-DEPLOY
  # ,,,,,,,,,,,

  process_postdeploy() {
    declare uniq; uniq="$(
      printf -- '%s\n' "${POSTDEPLOY_HOOKS[@]}" \
      | uniq_ordered | grep '.\+'
    )" && mapfile -t uniq <<< "${uniq}"

    declare hook; for hook in "${uniq[@]}"; do
      log_info "Running '${hook}' hook"
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

    ! [[ "${OS_TYPE}" == centos ]] && return

    log_info "Profile: Fix AlmaLinux 8 GPG key"

    (
      # shellcheck disable=SC1091
      fix_gpg_key() {
        (. /etc/os-release; echo "${ID}:$(rpm -E '%{rhel}')") \
        | grep -qFx 'almalinux:8' || return 0

        set -x
        # Give it some more time to worm up
        sleep 10
        rpm --import https://repo.almalinux.org/almalinux/RPM-GPG-KEY-AlmaLinux
      }

      declare was_up=false
      do_lxc is_up && was_up=true
      do_lxc ensure_up 5 || { log_fatal "Can't start the container"; return 1; }

      lxc_attach -- /bin/sh -c "$(declare -f fix_gpg_key); fix_gpg_key" || {
        log_warn "Some issue with fixing GPG key"
      }

      if ! ${was_up}; then
        do_lxc ensure_down
      fi
    )
  }

  profile_docker_ready() {
    log_info "Profile: Docker ready"

    # Some instruction:
    # https://gist.github.com/afanjul/492ca7b10982f6de2cb2c475fe76af6a

    # # The following seems to be not needed:
    # PRIVILEGED=true
    # do_lxc ensure_confline 'lxc.apparmor.profile: unconfined'

    do_lxc ensure_confline 'lxc.cap.drop:' || return

    if [[ "${OS_TYPE}" == alpine ]]; then
      (
        add_cgroups() {
          set -x; rc-update add cgroups default >/dev/null
        }

        declare was_up=false
        do_lxc is_up && was_up=true
        do_lxc ensure_up 5 || { log_fatal "Can't start the container"; return 1; }

        lxc_attach -- /bin/sh -c "$(declare -f add_cgroups); add_cgroups" || {
          log_warn "Some issue with adding cgroups"
        }

        if ! ${was_up}; then
          do_lxc ensure_down
        fi
      )
    fi
  }

  profile_docker() (
    log_info "Profile: Docker"

    # shellcheck disable=SC1091
    install_docker_debian() (
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

    install_docker_centos() ( set -x
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

    install_docker_alpine() ( set -x
      apk add -q --update --no-cache \
        docker docker-cli-compose \
      && rc-update add -q docker boot \
      || return

      # The service produces some mysterious "limit"-related
      # error, but seems to work fine
      service docker start &>/dev/null; return 0
    )

    declare callback="install_docker_${OS_TYPE}"
    declare -F "${callback}" &>/dev/null || {
      log_fatal "Unsupported platform for docker installation: '${OS_TYPE}'"
      return 1
    }

    profile_docker_ready

    declare -i warm=15
    [[ "${OS_TYPE}" == alpine ]] && warm=5

    declare was_up=false
    do_lxc is_up && was_up=true
    do_lxc ensure_up "${warm}" || {
      log_fatal "Can't start the container"
      return 1
    }

    lxc_attach -- /bin/sh -c "$(declare -f "${callback}"); ${callback}" || {
      log_warn "Some issue installing docker"
    }

    if ! ${was_up}; then
      do_lxc ensure_down
    fi
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

    do_lxc ensure_confline "${conflines[@]}"
  }

  profile_vaapi() {
    log_info "Profile: VAAPI"

    declare drm_dev=/dev/dri/renderD128

    if ! "${PRIVILEGED}"; then
      [[ -e "${drm_dev}" ]] || return 0

      declare card=/dev/dri/card0
      [[ -e "${card}" ]] || card=/dev/dri/card1

      do_lxc ensure_dev "${drm_dev},gid=104" "${card},gid=44"
      return
    fi

    do_lxc ensure_confline \
      "lxc.cgroup2.devices.allow: c 226:0 rwm" \
      "lxc.cgroup2.devices.allow: c 226:128 rwm" \
      "lxc.cgroup2.devices.allow: c 29:0 rwm" \
      "lxc.mount.entry: /dev/fb0 dev/fb0 none bind,optional,create=file" \
      "lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir" \
      "lxc.mount.entry: ${drm_dev} ${drm_dev#/*} none bind,optional,create=file"
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
