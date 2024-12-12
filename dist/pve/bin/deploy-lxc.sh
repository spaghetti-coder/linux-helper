#!/usr/bin/env bash

# Allows config callbacks nesting
DEPLOY_LXC_CONFIGS=(deploy_lxc_config "${DEPLOY_LXC_CONFIGS[@]}")

deploy_lxc_config() { :
  # Defaults to automanaged
  # lh_params set ID 100

  # Defaults to automanaged
  # lh_params set STORAGE local-lvm

  # Defaults to ubuntu-24.04.
  # Best guess hint from: http://download.proxmox.com/images/system
  # Or direct http(s) link:
  # * https://images.linuxcontainers.org/images/
  # * http://mirror.turnkeylinux.org/turnkeylinux/images/proxmox/
  # * https://images.lxd.canonical.com/images/
  # Demo: https://benheater.com/proxmox-lxc-using-external-templates/
  # FALLBACK_TEMPLATE acts when TEMPLATE download fails
  # lh_params set TEMPLATE almalinux-8
  # lh_params set FALLBACK_TEMPLATE 'https://images.linuxcontainers.org/images/almalinux/8/amd64/default/20241227_23%3A08/rootfs.tar.xz'

  # Use if you know what you are doing
  # lh_params set OSTYPE centos

  # Defaults to template default. In GB
  # lh_params set DISK 20

  # Defaults to PVE default. In MB
  # lh_params set RAM 2048

  # Defaults to PVE default. In MB
  # lh_params set SWAP 1024

  # Defaults to all available in PVE host
  # lh_params set CORES 2

  # Defaults to false.
  # NOTE: can be forcely impacted by some of the profiles
  # lh_params set PRIVILEGED true

  # Defaults to false
  # lh_params set ONBOOT true

  # Container root password. Either PASS or PASS_ENVVAR
  # is required. With both provided PASS will be used
  # lh_params set PASS 'DEMO_PASS'

  # Defaults to LH_LXC_ROOT_PASS
  # lh_params set PASS_ENVVAR 'DEMO_PASS_ENVVAR_NAME'

  # Defaults to unset
  # lh_params set HOSTNAME serv.home

  # Defaults to 'vmbr0'
  # lh_params set NET_BRIDGE vmbr0

  # Defaults to 'dhcp'
  # lh_params set IP 10.0.0.69/32

  # Required for non-dhcp IP, normally router IP
  # lh_params set GATEWAY 10.0.0.1

  # Container profile. See available profiles with `--help`.
  # Can be set multiple times or space-separated
  # lh_params set PROFILE comfort
  # lh_params set PROFILE docker-ready

  # After container create hook script. Runs in the PVE host machine
  # Can be set multiple times or space-separated
  # lh_params set AFTER_CREATE backup_conffile

  # After container create hook script. Runs in the container itself.
  # The function is copied over to the running container and runs
  # isolated from the rest of the configuration script (can't use its
  # functions and variables).
  # Can be set multiple times or space-separated
  # lh_params set IN_CONTAINER 'system_upgrade install_vim'
}

# backup_conffile() {
#   declare -r ct_id="${1}"
#   (set -x; cp "/etc/pve/lxc/${ct_id}.conf" "/root/${ct_id}.conf")
# }

# system_upgrade() { (set -x; dnf upgrade -y >/dev/null); }
# install_vim() { (set -x; dnf install -y vim >/dev/null); }

# ^^^^^^^^^^^^^ #
# CONFIGURATION #
#################

deploy_lxc() {
  { # Service vars
    declare -r SELF="${FUNCNAME[0]}"

    # If not a file, default to deploy-lxc.sh script name
    declare THE_SCRIPT=deploy-lxc.sh
    grep -q -m 1 -- '.' "${0}" 2>/dev/null && THE_SCRIPT="$(basename -- "${0}")"

    declare -r BASE_RAW_URL=https://github.com/spaghetti-coder/linux-helper/raw
    declare -r BASE_RAW_URL_ALT=https://bitbucket.org/kvedenskii/linux-scripts/raw
  }

  supported_dists() { text_nice "
    alpine
    centos-like (8+)
    debian
    ubuntu
  "; }

  print_usage() { echo "
    ${THE_SCRIPT} [ID] [--ask] [--storage STORAGE] [--template TEMPLATE='$(lh_params default-string TEMPLATE)'] \\
   ,  [--disk DISK] [--ram RAM] [--swap SWAP] [--cores CORES] [--privileged] [--onboot] \\
   ,  [--ostype OSTYPE] [--pass PASS] [--pass-envvar PASS_ENVVAR='$(lh_params default-string PASS_ENVVAR)'] \\
   ,  [--hostname HOSTNAME] [--net-bridge NET_BRIDGE='$(lh_params default-string NET_BRIDGE)'] [--ip IP='$(lh_params default-string IP)'] \\
   ,  [--gateway GATEWAY] [--profile PROFILE]... [--after-create AFTER_CREATE]... \\
   ,  [--in-container IN_CONTAINER]...
  "; }

  print_help() { text_nice "
    Deploy LXC container using self-contained script. Likely supported:
    $(supported_dists | sed -e 's/^/* /')
   ,
    USAGE:
    =====
    $(print_usage)
   ,
    PARAMS:
    ======
    ID          Numeric LXC container ID. Defaults to automanaged
    --ask       Provoke a prompt for all params
    --storage   PVE storage to use. Defaults to automanaged
    --template  Container template best guess hint from
   ,            ${TEMPLATES_URL}
   ,            Or direct http(s) link:
   ,            * https://images.linuxcontainers.org/images/
   ,            * http://mirror.turnkeylinux.org/turnkeylinux/images/proxmox/
   ,            * https://images.lxd.canonical.com/images/
   ,            Demo: https://benheater.com/proxmox-lxc-using-external-templates/
    --ostype    Use if you know what you are doing
    --disk      Disk size in GB. Defaults to template default
    --ram       RAM size in MB. Defaults to PVE default
    --swap      SWAP size in MB. Defaults to PVE default
    --cores     Number of cores. Defaults to all available in PVE host
    --privileged  Privileged container. Can be manipulated by some of profiles
    --onboot      Start container on PVE boot
    --pass        Container root password. If not set will attempt to get it from
   ,              the env variable provided by --pass-envvar. In the end
   ,              container root password must be reachable.
    --pass-envvar Environment variable to read container root password from
    --hostname    Container hostname
    --net-bridge  PVE bridge network
    --ip          Container IP or 'dhcp' if managed by the router
    --gateway     Default gateway. Required when IP is not 'dhcp'
    --profile     Convenience profiles configuring the container for some purpose.
   ,              Can be set multiple times or space separated
    --after-create  Hook function that will run after container created on the PVE
   ,                machine. Can be set multiple times or space separated. The
   ,                function must be accessible in the configuration file.
    --in-container  Hook function that will run in the container. The container
   ,                will be started and stopped automatically. Can be set multiple
   ,                times or space separated. The function must be accessible in
   ,                the configuration file.
   ,
    PROFILES:
    ========
    $(profiles_list true | sed -e 's/^/* /')
   ,
    DEMO:
    ====
    # Edit configuration section in ${THE_SCRIPT} and run it to deploy LXC
    ${THE_SCRIPT}
   ,
    # Run overriding some configs in the configuration file and in
    # interactive mode
    LXC_PASS=qwerty ${THE_SCRIPT} --ask --privileged --disk 45 \\
   ,  --pass-env LXC_PASS 120
  "; }

  # shellcheck disable=SC2317
  init() {
    lh_params reset

    declare -g  PROFILE \
                AFTER_CREATE \
                IN_CONTAINER

    declare -g TEMPLATES_URL=http://download.proxmox.com/images/system

    # Configure defaults
    lh_params defaults \
      ASK=false \
      TEMPLATE=ubuntu-24.04 \
      ONBOOT=false \
      PASS_ENVVAR=LH_LXC_ROOT_PASS \
      PRIVILEGED=false \
      NET_BRIDGE=vmbr0 \
      IP=dhcp

    lh_params_default_ID() { pvesh get /cluster/nextid; }
    lh_params_default_STORAGE() { pvesm status -content rootdir | tail -n +2 | cut -d' ' -f1 | grep '.\+'; }
    # shellcheck disable=SC1009
    lh_params_default_PASS() {
      declare env; env="$(lh_params get PASS_ENVVAR)" \
      && [[ (-n "${env}" && -n "${!env}") ]] \
      && printf -- '%s\n' "${!env}"
    }

    lh_params_set_PROFILE() { PROFILE+="${PROFILE:+ }${1}"; }
    lh_params_get_PROFILE() { printf -- '%s\n' "${PROFILE}"; }

    lh_params_set_AFTER_CREATE() { AFTER_CREATE+="${AFTER_CREATE:+ }${1}"; }
    lh_params_get_AFTER_CREATE() { printf -- '%s\n' "${AFTER_CREATE}"; }

    lh_params_set_IN_CONTAINER() { IN_CONTAINER+="${IN_CONTAINER:+ }${1}"; }
    lh_params_get_IN_CONTAINER() { printf -- '%s\n' "${IN_CONTAINER}"; }

    [[ "${#DEPLOY_LXC_CONFIGS[@]}" -lt 1 ]] || {
      declare conf; for conf in "${DEPLOY_LXC_CONFIGS[@]}"; do
        "${conf}"
      done
    }
  }

  parse_params() {
    declare -a args

    while [[ ${#} -gt 0 ]]; do
      case "${1}" in
        -\?|-h|--help       ) print_help; exit ;;
        --usage             ) print_usage | text_nice; exit ;;
        --ask               ) lh_params set ASK true ;;
        --storage           ) lh_params set STORAGE "${@:2:1}"; shift ;;
        --template          ) lh_params set TEMPLATE "${@:2:1}"; shift ;;
        --ostype            ) lh_params set OSTYPE "${@:2:1}"; shift ;;
        --disk              ) lh_params set DISK "${@:2:1}"; shift ;;
        --ram               ) lh_params set RAM "${@:2:1}"; shift ;;
        --swap              ) lh_params set SWAP "${@:2:1}"; shift ;;
        --cores             ) lh_params set CORES "${@:2:1}"; shift ;;
        --privileged        ) lh_params set PRIVILEGED true ;;
        --onboot            ) lh_params set ONBOOT true ;;
        --pass              ) lh_params set PASS "${@:2:1}"; shift ;;
        --pass-envvar       ) lh_params set PASS_ENVVAR "${@:2:1}"; shift ;;
        --hostname          ) lh_params set HOSTNAME "${@:2:1}"; shift ;;
        --net-bridge        ) lh_params set NET_BRIDGE "${@:2:1}"; shift ;;
        --ip                ) lh_params set IP "${@:2:1}"; shift ;;
        --gateway           ) lh_params set GATEWAY "${@:2:1}"; shift ;;
        --profile           ) lh_params set PROFILE "${@:2:1}"; shift ;;
        --after-create      ) lh_params set AFTER_CREATE "${@:2:1}"; shift ;;
        --in-container      ) lh_params set IN_CONTAINER "${@:2:1}"; shift ;;
        -*                  ) lh_params unsupported "${1}" ;;
        *                   ) args+=("${1}") ;;
      esac

      shift
    done

    [[ ${#args[@]} -gt 0 ]] && lh_params set ID "${args[0]}"
    [[ ${#args[@]} -lt 2 ]] || lh_params unsupported "${args[@]:1}"
  }

  trap_ask() {
    "$(lh_params get ASK)" || return 0

    lh_params invalids >&2 && {
      echo "FATAL (${SELF})" >&2
      exit 1
    }

    # shellcheck disable=SC2317
    { # redefine set functions
      declare set_cache
      declare p; for p in PROFILE AFTER_CREATE IN_CONTAINER; do
        set_cache+="${set_cache+$'\n'}$(declare -f lh_params_set_"${p}")"
      done

      lh_params_set_PROFILE() { PROFILE="${1}"; }
      lh_params_set_AFTER_CREATE() { AFTER_CREATE="${1}"; }
      lh_params_set_IN_CONTAINER() { IN_CONTAINER="${1}"; }
    }

    lh_params ask-config \
      , ID "Container ID: " \
      , STORAGE "PVE storage: " \
      , TEMPLATE \
        "# Best guess hint from ${TEMPLATES_URL}." \
        "# Or direct http(s) link:" \
        "# * https://images.linuxcontainers.org/images/" \
        "# * http://mirror.turnkeylinux.org/turnkeylinux/images/proxmox/" \
        "# * https://images.lxd.canonical.com/images/" \
        "# Demo: https://benheater.com/proxmox-lxc-using-external-templates/" \
        "# Supported: $(supported_dists | tr '\n' ',' | sed -e 's/,$//' -e 's/,/, /g')" \
        "Template: " \
      , OSTYPE \
        "# Use if you know what you are doing" \
        "OS type: " \
      , DISK "Disk size in GB: " \
      , RAM "RAM in MB: " \
      , SWAP "SWAP in MB: " \
      , CORES "Cores number: " \
      , PRIVILEGED:bool "Privileged (true/false): " \
      , ONBOOT:bool "Start on PVE boot (true/false): " \
      , PASS:pass "Container root password: " \
      , PASS_ENVVAR "Env variable containing container root password: " \
      , HOSTNAME "Container hostname: " \
      , NET_BRIDGE "PVE network bridge: " \
      , IP "Container IP (like 10.0.0.69/32 or dhcp): " \
      , GATEWAY "Container default gateway (when IP is not dhcp): " \
      , PROFILE \
        "# Available profiles:" \
        "#   $(profiles_list false | tr '\n' ',' | sed -e 's/,$//' -e 's/,/, /g')" \
        "Profiles (space separated): " \
      , AFTER_CREATE "After create hooks (space separated): " \
      , IN_CONTAINER "Container hooks (space separated): "

    lh_params ask

    # Restore set functions
    # shellcheck disable=SC1090
    . <(printf -- '%s\n' "${set_cache}")
  }

  check_params() {
    declare p; for p in \
      ID \
      STORAGE \
      TEMPLATE \
      NET_BRIDGE \
      IP \
    ; do
      lh_params get "${p}" >/dev/null || lh_params noval "${p}"
      lh_params is-blank "${p}" && lh_params errbag "${p} can't be blank"
    done

    # We don't care about PASS if container already exists
    if ! lxc-info "$(lh_params get ID)" &>/dev/null; then
      lh_params get PASS >/dev/null || lh_params noval PASS
      lh_params is-blank PASS && lh_params errbag "PASS can't be blank"
    fi

    lh_params get IP | grep -iqx 'dhcp' || {
      lh_params get GATEWAY >/dev/null || lh_params errbag 'GATEWAY is required with non-dhcp IP'
      lh_params is-blank GATEWAY && lh_params errbag "GATEWAY can't be blank with non-dhcp IP"
    }

    to_bool "$(lh_params get PRIVILEGED)" >/dev/null || lh_params errbag "PRIVILEGED must be a boolean"
    to_bool "$(lh_params get ONBOOT)" >/dev/null || lh_params errbag "ONBOOT must be a boolean"
  }

  main() {
    init
    parse_params "${@}"
    trap_ask
    check_params
    load_hooks

    lh_params invalids >&2 && {
      echo "FATAL (${SELF})" >&2
      return 1
    }

    # Ensure values not automanaged
    lh_params set ID "$(lh_params get ID)"
    lh_params set STORAGE "$(lh_params get STORAGE)"

    apply_profiles
    lh_params invalids >&2 && {
      echo "FATAL (${SELF})" >&2
      return 1
    }

    declare -i RC=0
    declare CT_ID; CT_ID="$(lh_params get ID)"

    if ! lxc-info "${CT_ID}" &>/dev/null; then
      # Deploy the container
      declare tpl; tpl="$(lh_params get TEMPLATE)"
      declare tpl_url; tpl_url="$(detect_tpl_url "${tpl}")" || return
      declare tpl_file; tpl_file="$(download_tpl "${tpl_url}")" || return
      create_container "${tpl_file}" >/dev/null || RC=1

      (set -x; rm -f -- "${tpl_file}")
    fi

    [[ ${RC} -lt 1 ]] || {
      echo "Error creating container" >&2
      echo "FATAL (${SELF})" >&2
      return ${RC}
    }

    configure_container

    # Apply hooks
    apply_after_create
    apply_in_container

    if "$(lh_params get ONBOOT)"; then
      lxc_do "$(lh_params get ID)" ensure-up 0
    fi

    ! lh_params invalids >&2 || {
      echo "(${SELF})" >&2
      return 1
    }
  }

  #################
  # HOOKS HELPERS #
  # ,,,,,,,,,,,,, #

   _load_hooks_helper() {
    declare -n _hooks_queue="${1}"
    declare hook_type="${2^^}" func_prefix="${3}"

    declare hooks_list
    if hooks_list="$(
      lh_params get "${hook_type}" | text_trim | sed -e 's/,\+$//' \
      | sed -e 's/,/ /g' | sed -e 's/\s\+/ /g' | tr ' ' '\n' \
      | uniq_ordered | grep '.'
    )"; then
      declare -a hooks
      mapfile -t hooks <<< "${hooks_list}"

      declare func
      declare h; for h in "${hooks[@]}"; do
        func="${func_prefix}${h//-/_}"

        echo "### > Loading '${func}' function for '${h}' ${hook_type}" >&2

        declare -F "${func}" &>/dev/null && {
          _hooks_queue+=("${func}")
          continue
        }

        lh_params errbag "Function '${func}' for '${h}' ${hook_type} not found"
      done
    fi
  }

  load_hooks() {
    declare -ag LH_LXC_PROFILES \
                LH_LXC_SYSTEM_AFTER_CREATE \
                LH_LXC_AFTER_CREATE \
                LH_LXC_SYSTEM_IN_CONTAINER \
                LH_LXC_IN_CONTAINER \
                LH_LXC_EXCLUDE_HOOKS

    _load_hooks_helper LH_LXC_PROFILES PROFILE lxc_profile_
    _load_hooks_helper LH_LXC_AFTER_CREATE AFTER_CREATE ''
    _load_hooks_helper LH_LXC_IN_CONTAINER IN_CONTAINER ''
  }

  _apply_host_hooks() {
    # shellcheck disable=SC2178
    declare -n _hooks_queue="${1}"
    declare hook_type="${2^^}" type_plural="${3,,}"

    [[ ${#_hooks_queue[@]} -gt 0 ]] || return 0

    declare f; for f in "${_hooks_queue[@]}"; do
      printf -- '%s\n' "${LH_LXC_EXCLUDE_HOOKS[@]}" | grep -qFx "${f}" && continue

      echo "### > Applying '${f}' ${hook_type^^} function" >&2

      "${f}" "$(lh_params get ID)" \
        || lh_params errbag "${hook_type^^} function '${f}' execution error"
    done
    echo "### > Done applying ${type_plural}" >&2
  }

  ####################
  # CONTAINER CREATE #
  # ,,,,,,,,,,,,,,,, #

  templates_list() (
    set -o pipefail
    download_tool "${TEMPLATES_URL}" \
    | grep -o 'href="[^"]\+\.tar\..\+"' \
    | sed -e 's/^href="\(.\+\)"/\1/' | sort -V
  )

  detect_tpl_url() {
    [[ "${1}" =~ ^https?:\/\/ ]] && { echo "${1}"; return; }

    declare template_rex; template_rex="$(escape_sed_expr "${1}")"

    declare url fallback
    if url="$(
      set -o pipefail
      templates_list | grep "^${template_rex}" | tail -n 1
    )"; then
      printf -- '%s/%s\n' "${TEMPLATES_URL}" "${url}"
      return
    elif \
      fallback="$(lh_params get FALLBACK_TEMPLATE)" \
      && [[ "${fallback}" != "${1}" ]] \
    ; then
      detect_tpl_url "${fallback}"
      return
    fi

    echo "Can't detect template: ${1}" >&2
    return 1
  }

  download_tpl() {
    declare tpl_url="${1}"
    declare ext; ext="$(grep -o '\.tar\..\+$' <<< "${tpl_url}")"
    declare tpl_path; tpl_path="$(set -x; mktemp --suffix "${ext}")" || return
    declare -a dl_tool; download_tool dl_tool

    ( set -o pipefail
      {
        (set -x; "${dl_tool[@]}" "${tpl_url}") \
        || {
          declare fallback_url
          declare fallback; fallback="$(lh_params get FALLBACK_TEMPLATE)" \
          && fallback_url="$(detect_tpl_url "${fallback}")" \
          && [[ "${fallback_url}" != "${tpl_url}" ]] \
          && (set -x; "${dl_tool[@]}" "${fallback_url}")
        }
      } | (set -x; tee -- "${tpl_path}") >/dev/null \
    ) || return
    echo "${tpl_path}"
  }

  create_container() {
    declare tpl_file="${1}"

    declare -a create_cmd; create_cmd=(
      pct create "$(lh_params get ID)" "${tpl_file}"
      --password "$(lh_params get PASS)"
      --storage "$(lh_params get STORAGE)"
      --unprivileged "$("$(lh_params get PRIVILEGED)"; echo $?)"
    )

    declare disk; disk="$(lh_params get DISK | grep '.')" && create_cmd+=(--rootfs "${disk}")
    declare ostype; ostype="$(lh_params get OSTYPE | grep '.')" && create_cmd+=(--ostype "${ostype}")

    ( set -o pipefail
      (set -x; "${create_cmd[@]}") 3>&1 1>&2 2>&3 \
      | sed -e 's/\( --password \)\(.\+\)\( --storage .\+\)/\1*****\3/'
    ) 3>&1 1>&2 2>&3
  }

  configure_container() {
    declare CT_ID; CT_ID="$(lh_params get ID)"

    # Ensure correct PRIVILEGED
    lh_params set PRIVILEGED true
    lxc_do "${CT_ID}" conffile-head \
      | grep -qx '\s*unprivileged:\s*1\s*' \
    && lh_params set PRIVILEGED false

    # Configure features
    declare features='nesting=1'
    ! "$(lh_params get PRIVILEGED)" && features+="${features:+,}keyctl=1"

    declare net="name=eth0"
    declare ip; ip="$(lh_params get IP)"; ip="${ip,,}"
    net+="${net:+,}bridge=$(lh_params get NET_BRIDGE),ip=${ip}"
    [[ "${ip}" != 'dhcp' ]] && net+="${net:+,}gw=$(lh_params get GATEWAY)"

    declare -a config_cmd; config_cmd=(
      pct set "${CT_ID}"
      --onboot "$(! "$(lh_params get ONBOOT)"; echo $?)"
      --features "${features}"
      --net0 "${net}"
    )

    declare hostname; hostname="$(lh_params get HOSTNAME | grep '.')" && config_cmd+=(--hostname "${hostname}")
    declare ram; ram="$(lh_params get RAM | grep '.')" && config_cmd+=(--memory "${ram}")
    declare swap; swap="$(lh_params get SWAP | grep '.')" && config_cmd+=(--swap "${swap}")
    declare cores; cores="$(lh_params get CORES | grep '.')" && config_cmd+=(--cores "${cores}")

    (set -x; "${config_cmd[@]}")
  }

  ############
  # PROFILES #
  # ,,,,,,,, #

  apply_profiles() {
    _LH_LXC_PROFILE_RUN=true _apply_host_hooks LH_LXC_PROFILES PROFILE profiles
  }

  profiles_list() {
    declare help="${1-false}"
    declare prefix=lxc_profile_
    declare -a profiles; mapfile -t profiles <<< "$(
      declare -F | rev | cut -d' ' -f1 | rev | grep '^'"${prefix}"'' \
      | sort -n | sed -e 's/^'"${prefix}"'//' -e 's/_/-/g'
    )"

    ${help} && {
      declare ix; for ix in "${!profiles[@]}"; do
        profiles["${ix}"]+=" - $(_LH_LXC_PROFILE_RUN=false "${prefix}${profiles[${ix}]//-/_}")"
      done
    }

    printf -- '%s\n' "${profiles[@]}"
  }

  lxc_profile_comfort() {
    ${_LH_LXC_PROFILE_RUN:-false} || {
      echo "a bit more comfortable environment in the container"
      return
    }

    declare raw_url raw_url_alt
    declare lang="${LANG:-en_US.UTF-8}"
    declare tz; tz="$(cat /etc/timezone 2>/dev/null)"
    [[ -n "${tz}" ]] || tz="UTC"

    lang="$(escape_sed_repl "${lang}")"
    tz="$(escape_sed_repl "${tz}")"
    raw_url="$(escape_sed_repl "${BASE_RAW_URL}")"
    raw_url_alt="$(escape_sed_repl "${BASE_RAW_URL_ALT}")"

    # shellcheck disable=SC2016
    eval -- "$(
      declare -f _int_in_container_comfort \
      | sed -e 's/{{\s*LANG\s*}}/'"${lang}"'/g' \
            -e 's/{{\s*TZ\s*}}/'"${tz}"'/g' \
            -e 's/{{\s*BASE_RAW_URL\s*}}/'"${raw_url}"'/g' \
            -e 's/{{\s*BASE_RAW_URL_ALT\s*}}/'"${raw_url_alt}"'/g'
    )"

    LH_LXC_SYSTEM_IN_CONTAINER+=(_int_in_container_comfort)
  }

  lxc_profile_docker() {
    ${_LH_LXC_PROFILE_RUN:-false} || {
      echo "docker installed (docker-ready profile included)"
      return
    }

    # Force execute docker-ready profile and exclude it from
    # the hooks queue if it's not already executed
    if \
      ! printf -- '%s\n' "${LH_LXC_PROFILES[@]}" \
      | grep -Fx -B 999 "${FUNCNAME[0]}" \
      | grep -qFx 'lxc_profile_docker_ready' \
    ; then
      lxc_profile_docker_ready
    fi
    LH_LXC_EXCLUDE_HOOKS+=(lxc_profile_docker_ready)

    # required AFTER_CREATE to not overtake docker-ready IN_DOCKER
    LH_LXC_SYSTEM_AFTER_CREATE+=(_int_after_create_docker)
  }

  lxc_profile_docker_ready() {
    ${_LH_LXC_PROFILE_RUN:-false} || {
      echo "container is ready for docker installation"
      return
    }

    # Some instruction:
    # https://gist.github.com/afanjul/492ca7b10982f6de2cb2c475fe76af6a

    # # The following seems to be not needed:
    # lh_params set PRIVILEGED true
    # # not needed in _int_after_create_docker_ready
    # lxc_do "${ct_id}" ensure-confline 'lxc.apparmor.profile: unconfined'

    LH_LXC_SYSTEM_AFTER_CREATE+=(_int_after_create_docker_ready)
  }

  lxc_profile_vaapi() {
    ${_LH_LXC_PROFILE_RUN:-false} || {
      echo "VAAPI hardware transcoding"
      return
    }

    LH_LXC_SYSTEM_AFTER_CREATE+=(_int_after_create_vaapi)
  }

  lxc_profile_vpn_ready() {
    ${_LH_LXC_PROFILE_RUN:-false} || {
      echo "container is ready for VPN"
      return
    }

    LH_LXC_SYSTEM_AFTER_CREATE+=(_int_after_create_vpn_ready)
  }

  ################
  # AFTER_CREATE #
  # ,,,,,,,,,,,, #

  apply_after_create() {
    # Merge system and user defined AFTER_CREATE prioritizing system ones
    LH_LXC_AFTER_CREATE=("${LH_LXC_SYSTEM_AFTER_CREATE[@]}" "${LH_LXC_AFTER_CREATE[@]}")
    _apply_host_hooks LH_LXC_AFTER_CREATE AFTER_CREATE after_create
  }

  _int_after_create_docker() {
    LH_LXC_SYSTEM_IN_CONTAINER+=(_int_in_container_docker)
  }

  _int_after_create_docker_ready() {
    declare -r ct_id="${1}"
    lxc_do "${ct_id}" ensure-confline 'lxc.cap.drop:'

    if grep -q '^\s*ostype:\s*alpine\s*$' "/etc/pve/lxc/${ct_id}.conf"; then
      LH_LXC_SYSTEM_IN_CONTAINER+=(_int_in_container_docker_ready_alpine)
    fi
  }

  _int_after_create_vaapi() {
    declare -r ct_id="${1}"
    declare drm_dev=/dev/dri/renderD128

    if ! "$(lh_params get PRIVILEGED)"; then
      [[ -e "${drm_dev}" ]] || return 0

      declare card=/dev/dri/card0
      [[ -e "${card}" ]] || card=/dev/dri/card1

      lxc_do "${ct_id}" ensure-dev "${drm_dev},gid=104" "${card},gid=44"
      return
    fi

    lxc_do "${ct_id}" ensure-confline \
      "lxc.cgroup2.devices.allow: c 226:0 rwm" \
      "lxc.cgroup2.devices.allow: c 226:128 rwm" \
      "lxc.cgroup2.devices.allow: c 29:0 rwm" \
      "lxc.mount.entry: /dev/fb0 dev/fb0 none bind,optional,create=file" \
      "lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir" \
      "lxc.mount.entry: ${drm_dev} ${drm_dev#/*} none bind,optional,create=file"
  }

  _int_after_create_vpn_ready() {
    declare -r ct_id="${1}"

    # https://pve.proxmox.com/wiki/OpenVPN_in_LXC
    declare -a conflines=(
      "lxc.mount.entry: /dev/net dev/net none bind,create=dir 0 0"
      "lxc.cgroup2.devices.allow: c 10:200 rwm"
    )
    # for GP client in cenos
    grep -q '\s*ostype:\s*centos\s*' "/etc/pve/lxc/${ct_id}.conf" && conflines+=("lxc.cap.drop:")

    lxc_do "${ct_id}" ensure-confline "${conflines[@]}"
  }

  ################
  # IN_CONTAINER #
  # ,,,,,,,,,,,, #

  apply_in_container() {
    # Merge system and user defined IN_CONTAINER prioritizing system ones
    LH_LXC_IN_CONTAINER=("${LH_LXC_SYSTEM_IN_CONTAINER[@]}" "${LH_LXC_IN_CONTAINER[@]}")

    [[ ${#LH_LXC_IN_CONTAINER[@]} -gt 0 ]] || return 0

    declare ct_id; ct_id="$(lh_params get ID)"
    declare was_up; was_up=false

    lxc_do "${ct_id}" is-up && was_up=true

    declare func
    declare -i warm=15
    declare ix; for ix in "${!LH_LXC_IN_CONTAINER[@]}"; do
      [[ ${ix} -gt 0 ]] && warm=5

      func="${LH_LXC_IN_CONTAINER[${ix}]}"

      echo "### > Applying '${func}' IN_CONTAINER function" >&2

      lxc_do "${ct_id}" ensure-up ${warm}
      lxc_do "${ct_id}" exec-cbk "${func}" \
      || lh_params errbag "IN_CONTAINER function '${func}' execution error"

      lxc_do "${ct_id}" ensure-down
    done
    echo "### > Done applying IN_CONTAINER" >&2

    if ${was_up}; then lxc_do "${ct_id}" ensure-up; fi
  }

  _int_in_container_comfort() {
    declare lang='{{ LANG }}'
    declare tz='{{ TZ }}'
    declare base_raw_url='{{ BASE_RAW_URL }}'
    declare base_raw_url_alt='{{ BASE_RAW_URL_ALT }}'

    declare -a packages=(
      bash-completion curl tzdata
    )

    if apt-get --version &>/dev/null; then
      ( set -x
        apt-get update \
        && apt-get install -y "${packages[@]}" \
          passwd locales \
        || exit
      ) >/dev/null

      # Set locale
      declare lang_rex; lang_rex="$(sed -e 's/[]\/$*.^[]/\\&/g' <<< "${lang}")"
      (set -x; sed -i 's/^\s*\#\s*\('"${lang_rex}"'.*\)$/\1/' /etc/locale.gen)
      declare locale_line; locale_line=$(grep -e "^${lang_rex}" /etc/locale.gen | cut -d' ' -f1 | head -n 1)
      echo "LANG=${locale_line}" | (set -x; tee -- /etc/default/locale >/dev/null)
      locale-gen >/dev/null
      export LANG="${locale_line}"

      (
        apt-get clean -y; apt-get autoremove -y
        find /var/lib/apt/lists -mindepth 1 -maxdepth 1 -exec rm -rf {} \;
      ) >/dev/null
    elif dnf --version &>/dev/null; then
      # to lazy for locales
      ( set -x
        dnf install -y epel-release
        dnf install -y "${packages[@]}" \
          util-linux-user \
        || exit

        dnf -y autoremove >/dev/null
        dnf -y --enablerepo='*' clean all >/dev/null
        find /var/cache/dnf -mindepth 1 -maxdepth 1 -exec rm -rf {} \;
      ) >/dev/null || return
    elif apk --version &>/dev/null; then
      # locales are not supported
      ( set -x
        apk add --update --no-cache "${packages[@]}" \
          shadow \
        || exit
      ) >/dev/null || return
    else
      echo "Can't detect package manager" >&2
      return 1
    fi

    # https://wiki.alpinelinux.org/wiki/Change_default_shell
    _iife_make_bash_default_shell() {
      unset _iife_make_bash_default_shell
      (set -x; chsh -s /bin/bash >/dev/null) || return
      (set -x; touch ~/.bashrc) || return
      if ! grep -q '^[^#]\+\/\.bashrc' ~/.bash_profile 2>/dev/null; then
        # Ensure .bashrc is loaded for login shell
        (set -x; tee -a ~/.bash_profile <<< '. ~/.bashrc' >/dev/null) || return
      fi
    }; _iife_make_bash_default_shell

    _iife_install_git_ps1() {
      unset _iife_install_git_ps1
      declare path='master/dist/config/git/git-ps1.sh'
      ( set -x
        {
          curl -fsSL "${base_raw_url}/${path}" \
            || curl -fsSL "${base_raw_url_alt}/${path}"
        } | bash -s --
      )
    }; _iife_install_git_ps1

    # https://wiki.alpinelinux.org/wiki/Setting_the_timezone
    _iife_set_timezone() {
      unset _iife_set_timezone
      (set -x; ln -sf "/usr/share/zoneinfo/${tz}" /etc/localtime) || return
      (set -x; tee -- /etc/timezone <<< "${tz}" >/dev/null) || return
    }; _iife_set_timezone

    _iife_cleanup() (
      unset _iife_cleanup

      set -x
      find /tmp /var/tmp -mindepth 1 -maxdepth 1 -exec rm -rf {} \; 2>/dev/null
      find /var/log/ -type f -exec truncate -s 0 {} \;
    ); _iife_cleanup

    return 0
  }

  _int_in_container_docker() {
    if apt-get --version &>/dev/null; then
      declare arch; arch="$(dpkg --print-architecture)"
      declare codename; codename="$(. /etc/os-release && echo "${VERSION_CODENAME}")"
      declare dist_id; dist_id="$(. /etc/os-release && echo "${ID}")"

      ( set -x

        # Insstall prereqs
        apt-get update
        apt-get install -y ca-certificates curl
        install -m 0755 -d /etc/apt/keyrings

        # Add the repository to Apt sources:
        curl -fsSL "https://download.docker.com/linux/${dist_id}/gpg" -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc
        tee /etc/apt/sources.list.d/docker.list <<< "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.asc] \
          https://download.docker.com/linux/${dist_id} ${codename} stable"
        apt-get update

        # Install docker
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

        apt-get clean -y; apt-get autoremove -y
        find /var/lib/apt/lists -mindepth 1 -maxdepth 1 -exec rm -rf {} \;
      ) >/dev/null || return
    elif dnf --version &>/dev/null; then
      ( set -x
        dnf install -y dnf-plugins-core \
        && dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo \
        && dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
        && sudo systemctl enable --now docker \
        || exit

        dnf -y autoremove >/dev/null
        dnf -y --enablerepo='*' clean all >/dev/null
        find /var/cache/dnf -mindepth 1 -maxdepth 1 -exec rm -rf {} \;
      ) >/dev/null || return
    elif apk --version &>/dev/null; then
      ( set -x
        apk add --update --no-cache \
          docker docker-cli-compose \
        && rc-update add docker boot \
        || exit

        # # Don's start the service, it will produce errors
        # service docker start
      ) >/dev/null || return
    else
      echo "Can't detect package manager" >&2
      return 1
    fi
  }

  _int_in_container_docker_ready_alpine() {
    # https://docs.genesys.com/Documentation/System/latest/DDG/InstallationofDockeronAlpineLinux
    (set -x; rc-update add cgroups default >/dev/null)

    # Run docker daemon on starup:
    #   rc-update add docker boot
  }

  ##########
  # INVOKE #
  # ,,,,,, #

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
}
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
# .LH_SOURCED: {{ lib/text.sh }}
# shellcheck disable=SC2001
# shellcheck disable=SC2120
text_ltrim() { sed -e 's/^\s\+//' <<< "${1-$(cat)}"; }
text_rtrim() { sed -e 's/\s\+$//' <<< "${1-$(cat)}"; }
text_trim() { text_ltrim <<< "${1-$(cat)}" | text_rtrim; }
text_rmblank() { grep -v '^\s*$' <<< "${1-$(cat)}"; return 0; }
text_nice() { text_trim <<< "${1-$(cat)}" | text_rmblank | sed -e 's/^,//'; }
# .LH_SOURCED: {{/ lib/text.sh }}
# .LH_SOURCED: {{ pve/lib/lxc-do.sh }}
# shellcheck disable=SC2317
lxc_do() (
  # lxc_do CT_ID COMMAND [ARG...]

  declare SELF="${FUNCNAME[0]}"

  declare CONFFILE_SNAPSHOT_REX='^\s*\[.\+\]\s*'

  conffile_head() {
    # conffile_head || { ERR_BLOCK }

    ( set -o pipefail
      grep -m1 -B 9999 -- "${CONFFILE_SNAPSHOT_REX}" "${CT_CONFFILE}" 2>/dev/null \
      | head -n -1
    ) || cat -- "${CT_CONFFILE}" 2>/dev/null || {
      lh_params errbag "Can't read conffile '${CT_CONFFILE}'"
      return 1
    }
  }

  conffile_tail() {
    # conffile_tail || { ERR_BLOCK }

    ( set -o pipefail
      grep -m1 -A 9999 -- "${CONFFILE_SNAPSHOT_REX}" "${CT_CONFFILE}" \
      | head -n -1
    )

    [[ ${?} -lt 2 ]] || {
      lh_params errbag "Can't read conffile '${CT_CONFFILE}'"
      return 1
    }
  }

  ensure_confline() {
    # ensure_confline CONFLINE... || { ERR_BLOCK }

    declare head; head="$(conffile_head)" || return
    declare tail; tail="$(conffile_tail)" || return
    [[ -n "${tail}" ]] && tail=$'\n\n'"${tail}"

    declare rex changed=false
    declare line; for line in "${@}"; do
      line="$(sed -e 's/^\s*//' -e 's/\s*$//' <<< "${line}")"
      rex="$(_confline_to_match_rex "${line}")"

      (set -x; grep -qx -- "${rex}" <<< "${head}") || {
        [[ ${?} -lt 2 ]] || return
        head+="${head+$'\n'}${line}"
        changed=true
      }
    done

    ! ${changed} && return

    printf -- '%s%s\n' "${head}" "${tail}" | (
      set -x; tee -- "${CT_CONFFILE}" >/dev/null
    )
  }

  ensure_no_confline() {
    # ensure_confline CONFLINE... || { ERR_BLOCK }

    declare head; head="$(conffile_head)" || return
    declare tail; tail="$(conffile_tail)" || return
    [[ -n "${tail}" ]] && tail=$'\n\n'"${tail}"

    declare rex_file
    declare line; for line in "${@}"; do
      rex_file+="${rex_file:+$'\n'}$(_confline_to_match_rex "${line}")"
    done

    [[ -z "${rex_file}" ]] && return

    head="$(grep -vxf <(cat <<< "${rex_file}") <<< "${head}")"

    printf -- '%s%s\n' "${head}" "${tail}" | (
      set -x; tee -- "${CT_CONFFILE}" >/dev/null
    )
  }

  ensure_dev() {
    # ensure_dev DEV_LINE... || { ERR_BLOCK }
    # ensure_dev '/dev/dri/renderD128,gid=104'

    declare rc=0

    declare head; head="$(conffile_head)" || return

    declare -a allowed_nums
    declare tmp; tmp="$(_allowed_device_nums dev)" \
    && mapfile -t allowed_nums <<< "${tmp}"

    declare -a add_devs
    declare dev rex dev_num ctr=0
    declare line; for line in "${@}"; do
      line="$(sed -e 's/^\s*//' -e 's/\s*$//' <<< "${line}")"
      dev="$(cut -d, -f1 <<< "${line},")"

      rex='\s*dev[0-9]\+[:=]\s*'"$(escape_sed_expr "${dev}")"'\(,.*\)\?\s*'
      (grep -qxe "${rex}" <<< "${head}") && continue

      dev_num="${allowed_nums[${ctr}]}"
      [[ -n "${dev_num}" ]] || {
        rc=$?
        lh_params errbag "No slot for dev '${line}'"
        continue
      }

      add_devs+=("dev${dev_num}: ${line}")
      (( ctr++ ))
    done

    ensure_confline "${add_devs[@]}" || rc=$?
    return "${rc}"
  }

  ensure_nodev() {
    # ensure_nodev DEV_PATH... || { ERR_BLOCK }
    # ensure_nodev '/dev/dri/renderD128'

    declare rex_file
    declare dev; for dev in "${@}"; do
      rex_file+="${rex_file:+$'\n'}"'\s*dev[0-9]\+:\s*'"$(escape_sed_expr "${dev}")"'\(,.\+\)\?\s*'
    done

    [[ -z "${rex_file}" ]] && return

    declare head; head="$(conffile_head)" || return
    declare -a nodevs
    mapfile -t nodevs <<< "$(grep -xf <(cat <<< "${rex_file}") <<< "${head}")"

    ensure_no_confline "${nodevs[@]}"
  }

  ensure_mount() {
    # ensure_mount MP_LINE... || { ERR_BLOCK }
    # ensure_mount '/host/dir,mp=/ct/mountpoint,mountoptions=noatime,replicate=0,backup=0'

    declare -i rc=0

    declare head; head="$(conffile_head)" || return

    declare -a allowed_nums
    declare tmp; tmp="$(_allowed_device_nums dev)" \
    && mapfile -t allowed_nums <<< "${tmp}"

    declare -a add_mps
    declare volume mp mp_rex=',mp=[^,]\+'
    declare rex1 rex2 mp_num ctr=0
    declare line; for line in "${@}"; do
      line="$(sed -e 's/^\s*//' -e 's/\s*$//' <<< "${line}")"
      volume="$(cut -d, -f1 <<< "${line},")"
      mp="$(
        set -o pipefail
        grep -o -- "${mp_rex}" <<< "${line}"
      )" || {
        rc=$?
        lh_params errbag "No mount point 'mp=' detected in '${line}'"
        continue
      }

      rex1='^\s*mp[0-9]\+[:=]\s*'"$(escape_sed_expr "${volume}"),"
      rex2="$(escape_sed_expr "${mp}")"
      (grep -e "${rex1}" <<< "${head}" | grep -qe "${rex2}") && continue

      mp_num="${allowed_nums[${ctr}]}"
      [[ -n "${mp_num}" ]] || {
        rc=$?
        lh_params errbag "No slot for mp '${line}'"
        continue
      }

      add_mps+=("mp${mp_num}: ${line}")
      (( ctr++ ))
    done

    ensure_confline "${add_mps[@]}" || rc=$?
    return "${rc}"
  }

  ensure_umount() {
    # ensure_mount CT_MP... || { ERR_BLOCK }
    # ensure_mount /ct/mountpoint

    declare rex_file
    declare mp; for mp in "${@}"; do
      rex_file+="${rex_file:+$'\n'}"'\s*mp[0-9]\+:.*,mp='"$(escape_sed_expr "${mp}")"'\(,.\+\)\?\s*'
    done

    [[ -z "${rex_file}" ]] && return

    declare head; head="$(conffile_head)" || return
    declare -a umounts
    mapfile -t umounts <<< "$(grep -xf <(cat <<< "${rex_file}") <<< "${head}")"

    ensure_no_confline "${umounts[@]}"
  }

  ensure_down() {
    # ensure_down || { ERR_BLOCK }

    if ! is_down; then
      (set -x; pct shutdown "${CT_ID}")
    fi
  }

  ensure_up() {
    # ensure_up [WARMUP_SEC=5] || { ERR_BLOCK }

    declare warm="${1-5}"

    if ! is_up; then
      (set -x; pct start "${CT_ID}") || return
      (set -x; lxc-wait "${CT_ID}" --state="RUNNING" -t 10)
    fi

    # Give it time to warm up the services
    warm="$(( warm - "$(get_uptime)" ))"
    if [[ "${warm}" -gt 0 ]]; then (set -x; sleep "${warm}" ); fi
  }

  exec_cbk() {
    # exec_cbk [-v|--verbose] FUNCNAME [ARG...] || { ERR_BLOCK }

    declare -a prefix=(true)

    [[ "${1}" =~ ^(-v|--verbose)$ ]] && { prefix=(set -x); shift; }

    declare cbk="${1}"; shift
    declare -a args

    declare arg; for arg in "${@}"; do
      args+=("'$(escape_single_quotes "${arg}")'")
    done

    declare cmd
    cmd="$(declare -f "${cbk}")" || return
    cmd+="${cmd:+$'\n'}${cbk}"
    [[ ${#args[@]} -lt 1 ]] || cmd+=' '
    cmd+="${args[*]}"

    # Attempt to install bash if not installed
    lxc-attach -n "${CT_ID}" -- bash -c true 2>/dev/null
    [[ $? == 127 ]] && (
      set -x
      lxc-attach -n "${CT_ID}" -- /bin/sh -c \
        'apk add --update --no-cache bash 2>/dev/null'
    )
    [[ $? == 127 ]] && (
      set -x
      lxc-attach -n "${CT_ID}" -- /bin/sh -c \
        'dnf install -y bash 2>/dev/null'
    )
    [[ $? == 127 ]] && (
      set -x
      lxc-attach -n "${CT_ID}" -- /bin/sh -c \
        '(apt-get --version && apt-get update && apt-get install -y bash) >/dev/null'
    )

    ("${prefix[@]}"; lxc-attach -n "${CT_ID}" -- bash -c -- "${cmd}")
  }

  get_uptime() (
    # get_uptime

    lxc-attach -n "${CT_ID}" -- /bin/sh -c '
      grep -o '^[0-9]\+' /proc/uptime 2>/dev/null
    ' || echo 0
  )

  is_down() {
    # is_down && { IS_DOWN_BLOCK } || { IS_UP_BLOCK }

    pct status "${CT_ID}" | grep -q ' stopped$'
  }

  is_up() {
    # is_up && { IS_UP_BLOCK } || { IS_DOWN_BLOCK }

    pct status "${CT_ID}" | grep -q ' running$'
  }

  _allowed_device_nums() {
    declare device_name="${1}"
    declare head; head="$(conffile_head)" || return

    declare busy_nums; busy_nums="$(
      grep -o "^${device_name}[0-9]\+:" <<< "${head}" \
      | sed -e "s/^${device_name}//" -e 's/:$//' | sort -n
    )"
    grep -vFxf <(echo "${busy_nums}") <<< "$(seq 0 255)"
  }

  _confline_to_match_rex() {
    declare line="${1}" opt val
    line="$(sed -e 's/^\s*//' -e 's/\s*$//' <<< "${line}")"
    opt="$(cut -d: -f1 <<< "${line}:")"
    val="$(cut -d: -f2- <<< "${line}:" | sed -e 's/^\s*//' -e 's/:$//')"
    echo '\s*'"$(escape_sed_expr "${opt}")"'\s*[:=]\s*'"$(escape_sed_expr "${val}")"'\s*'
  }

  # ^^^^^^^^^ #
  # FUNCTIONS #
  #############

  declare -ar EXPORTS=(
    conffile_head
    conffile_tail
    ensure_confline
    ensure_no_confline
    ensure_dev
    ensure_nodev
    ensure_mount
    ensure_umount
    ensure_down
    ensure_up
    exec_cbk
    get_uptime
    is_down
    is_up
  )

  declare -r CT_ID="${1}"; shift
  declare -r CT_CONFFILE="/etc/pve/lxc/${CT_ID}.conf"

  if [[ -z "${CT_ID:+x}" ]]; then
    lh_params errbag "CT_ID is required, and can't be empty"; lh_params invalids >&2 && {
      echo "FATAL (${SELF})" >&2
      return 1
    }
  fi

  # shellcheck disable=SC2015
  if ! printf -- '%s\n' "${EXPORTS[@]}" | grep -qFx -- "${1//-/_}"; then
    lh_params unsupported "${1}"
  else
    "${1//-/_}" "${@:2}"
  fi
  declare -i RC=$?

  ! lh_params invalids >&2 || {
    RC=$?
    echo "FATAL (${SELF})" >&2
  }

  return ${RC}
)
# .LH_SOURCED: {{/ pve/lib/lxc-do.sh }}

# .LH_NOSOURCE

(return 0 &>/dev/null) || {
  deploy_lxc main "${@}"
}
