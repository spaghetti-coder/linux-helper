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
    #   openssl passwd -6 -salt "$(openssl rand -hex 6)" -stdin <<< PASSWORD
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
  # * OS_TYPE     Actual Guest OS type
  # * PRIVILEGED  Actual privileged state with value of true / false

  # Better prefix hooks with 'lxc_' to avoid overriding
  # of deploy_lxc internal functions
  PREDEPLOY=(lxc_predeploy_dummy)
  POSTDEPLOY=(lxc_postdeploy_dummy)
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
  declare -g SELF="${FUNCNAME[0]}"

  main() {
    init_internal_vars

    process_configs || return
    run_predeploy || return

    ensure_container || return
    update_config

    configure_container || return

    # Always run this to fix AlmaLinux 8 GPG issue
    profile_fix_almalinux8_gpg || return

    run_postdeploy || return 1

    if ${ONBOOT}; then
      log_info "Starting the container"
      do_lxc ensure_up 0
    fi
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
      OS_TYPE
    declare -ga \
      CREATE_PARAMS \
      SET_PARAMS \
      PREDEPLOY \
      POSTDEPLOY
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

  process_configs() {
    log_info "Exporting configs ..."

    declare -a  create_params set_params \
                predeploy postdeploy
    declare c; for c in "${DEPLOY_LXC_CONFIGS[@]}"; do
      # Reset from the previous iteration
      CREATE_PARAMS=(); SET_PARAMS=()
      PREDEPLOY=(); POSTDEPLOY=()

      "${c}" || return

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
    declare pass_rex=''\''\?\(--password[= ]\)[^ ]\+'

    ( set -o pipefail
      (set -x; "${cmd[@]}") 3>&1 1>&2 2>&3 \
      | sed -e 's/'"${pass_rex}"'/\1*****/g'
    ) 3>/dev/null 1>&2 2>&3 || {
      log_fatal "Can't create container"
      return 1
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
      pct set "${CT_ID}" --features "${features}" "${SET_PARAMS[@]}"
    )

    (set -x; "${cmd[@]}") || {
      log_fatal "Can't apply configuration"
      return 1
    }
  }

  # POST-DEPLOY
  # ,,,,,,,,,,,

  process_postdeploy() {
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
