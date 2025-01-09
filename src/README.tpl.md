<a id="top"></a>

# Linux helper

* [Tools](#tools)
* [Config](#config)
* [Libraries](#libraries)
* [Helpers](#helpers)
* [Proxmox](#proxmox)
---
* [Tips](#tips)
* [Development](#development)

## Tools

<!-- .LH_DETAILS:bin/compile-bash-file.sh -->
<!-- .LH_DETAILS:bin/demo.sh -->
<!-- .LH_DETAILS:bin/ssh-gen.sh -->
<!-- .LH_DETAILS:short/compile-bash-project.sh -->
<!-- .LH_DETAILS:short/ssh-gen-github.sh -->
<!-- .LH_DETAILS:short/ssh-gen-vc.sh -->

[To top]

## Config

<!-- .LH_DETAILS:config/bash/bashrcd.sh -->
<!-- .LH_DETAILS:config/git/git-ps1.sh -->

<a id="config/git/gitconfig.extra.ini"></a>
<details><summary>config/git/gitconfig.extra.ini</summary>

  [Link to the section](#config/git/gitconfig.extra.ini)

  View [`gitconfig.extra.ini`](@@BASE_RAW_URL/master/src/asset/conf/git/gitconfig.extra.ini)
  
  **AD HOC:**

  ~~~sh
  # VERSION can be changed to any treeish
  (
    VERSION='master'
    curl -V &>/dev/null && dl_tool=(curl -fsSL) || dl_tool=(wget -qO-)
    set -x; "${dl_tool[@]}" "@@BASE_RAW_URL/${VERSION:-master}/src/asset/conf/git/gitconfig.extra.ini" \
    || "${dl_tool[@]}" "@@BASE_RAW_URL_ALT/${VERSION:-master}/src/asset/conf/git/gitconfig.extra.ini"
  ) | (set -x; tee ~/.gitconfig.lh-extra.ini >/dev/null) && {
    git config --global --get-all include.path | grep -qFx '~/.gitconfig.lh-extra.ini' \
    || (set -x; git config --global --add include.path '~/.gitconfig.lh-extra.ini')
  }
  ~~~
</details>

<a id="config/tmux/tmux-default.sh"></a>
<details><summary>config/tmux/tmux-default.sh</summary>

  [Link to the section](#config/tmux/tmux-default.sh)

  View [`default.conf`](@@BASE_RAW_URL/master/src/asset/conf/tmux/default.conf)
  <!-- .LH_ADHOC_USAGE:config/tmux/tmux-default.sh -->
  <!-- .LH_HELP:config/tmux/tmux-default.sh -->
</details>

<a id="config/tmux/tmux-plugins.sh"></a>
<details><summary>config/tmux/tmux-plugins.sh</summary>

  [Link to the section](#config/tmux/tmux-plugins.sh)

  View [`plugins.conf`](@@BASE_RAW_URL/master/src/asset/conf/tmux/plugins.conf) and [`appendix.conf`](@@BASE_RAW_URL/master/src/asset/conf/tmux/appendix.conf)
  <!-- .LH_ADHOC_USAGE:config/tmux/tmux-plugins.sh -->
  <!-- .LH_HELP:config/tmux/tmux-plugins.sh -->
</details>  

[To top]

## Helpers

<a id="helper/docker-template.sh"></a>
<details><summary>helper/docker-template.sh</summary>

  [Link to the section](#helper/docker-template.sh)

  Merge and compile docker-compose template(s).

  **Usage demo**:

  See [`docker-compose.npm.tpl.yaml`](@@BASE_RAW_URL/master/src/asset/docker/docker-compose.npm.tpl.yaml) and [`docker-compose.nginx-proxy.tpl.yaml`](@@BASE_RAW_URL/master/src/asset/docker/docker-compose.nginx-proxy.tpl.yaml)

  ~~~sh
  # LH_VERSION can be changed to any treeish
  bash -- <(
    LH_VERSION='master'
    curl -V &>/dev/null && dl_tool=(curl -fsSL) || dl_tool=(wget -qO-)
    set -x; "${dl_tool[@]}" "@@BASE_RAW_URL/${LH_VERSION:-master}/dist/helper/docker-template.sh" \
    || "${dl_tool[@]}" "@@BASE_RAW_URL_ALT/${LH_VERSION:-master}/dist/helper/docker-template.sh"
  ) @npm @nginx-proxy \ # merge npm and nginx-proxy templates
    NPM_UID 1000 \
    NPM_GID=1000 \ # Same as 'NPM_GID 1000'
    +NPM_ENVIRONMENT 'VIRTUAL_HOST=foo.bar' \
    +NPM_ENVIRONMENT='VIRTUAL_PORT=8080' \ # Same as +'NPM_ENVIRONMENT=VIRTUAL_PORT=8080'
    -NPM_PORT_HTTP \ # Remove NPM_PORT_* lines
    -NPM_PORT_HTTPS \
    -NPM_PORT_ADMIN \
    -NPM_PORTS \ # Remove ports node to avoid invalid docker-compose file
    +NPM_OPTS network_mode=host \ # Same as +'NPM_OPTS network_mode host', +'NPM_OPTS=network_mode=host'
    -NGINX_PROXY_PORT_HTTP=8080
    -NGINX_PROXY_PORTS
  ~~~
</details>  

[To top]

## Libraries

TODO

[To top]

## Proxmox

<a id="pve/bin/deploy-lxc.tpl.sh"></a>
<details><summary>pve/bin/deploy-lxc.tpl.sh</summary>

  [Link to the section](#pve/bin/deploy-lxc.tpl.sh)

  **AD HOC:**
  ~~~sh
  # LH_VERSION can be changed to any treeish
  (
    LH_VERSION='master'
    curl -V &>/dev/null && dl_tool=(curl -fsSL) || dl_tool=(wget -qO-)
    set -x; "${dl_tool[@]}" "@@BASE_RAW_URL/${LH_VERSION:-master}/dist/pve/bin/deploy-lxc.tpl.sh" \
    || "${dl_tool[@]}" "@@BASE_RAW_URL_ALT/${LH_VERSION:-master}/dist/pve/bin/deploy-lxc.tpl.sh"
  ) | (DEST=./my-lxc.sh; set -x; tee -- "${DEST}" >/dev/null; chmod +x -- "${DEST}")
  ~~~

  <!-- .LH_HELP:pve/bin/deploy-lxc.tpl.sh -->
</details>  

[To top]

## Tips

<details><summary>PVE: Change hostname</summary>

[Change hostname Proxmox](https://bobcares.com/blog/change-hostname-proxmox/)
</details>

<details><summary>PVE: Create / configure LXC container</summary>

```sh
# 
# CREATE
# 

CT_ID="$(pvesh get /cluster/nextid)"  # Or numeric 100+ CT_ID value
TEMPLATE="$(
  template=TEMPLATE_FILE
  tmp="$(ext=".tar.${template##*.tar.}"; set -x; mktemp --suffix "${ext}")"
  curl -fsSL http://download.proxmox.com/images/system/${template} \
  | (set -x; tee -- "${tmp}"); echo "${tmp}"
)"  # Or: TEMPLATE=/var/lib/vz/template/cache/TEMPLATE_FILE
NET='name=eth0,bridge=vmbr0,ip=dhcp'  # Or: NET='...,ip=10.0.0.69/8,gw=10.0.0.1'

pct create "${CT_ID}" "${TEMPLATE}" \
  --unprivileged 1 \
  --net0 "${NET}" \
  --password "$(openssl passwd -6 -salt "$(openssl rand -hex 6)" -stdin <<< changeme)" \
  --storage local-lvm

# 
# CONFIGURE: basic
# 

# `--features nesting=1` # when `--unprivileged 0`
pct set CT_ID \
  --timezone host \
  --features nesting=1,keyctl=1 \
  --onboot 1 \
  --cores 1 \
  --memory 2048 \
  --swap 1024 \
  --hostname HOSTNAME \
  --tags 'TAG1;TAG2'

# https://almalinux.org/blog/2023-12-20-almalinux-8-key-update/
# AlmaLinux < 9 fix GPG (with running container):
lxc-attach -n CT_ID -- \
  rpm --import https://repo.almalinux.org/almalinux/RPM-GPG-KEY-AlmaLinux

# 
# CONFIGURE: docker-ready
# 

# With `--features nesting=1,keyctl=1`
# or `--unprivileged 0 --features nesting=1`
# no additional settings required except for alpine

# Alpine only (with running container):
lxc-attach -n CT_ID -- \
  rc-update add cgroups default >/dev/null

# Alpine install docker (with running container):
lxc-attach -n CT_ID -- /bin/sh -c "
  apk add --update --no-cache docker docker-cli-compose
  rc-update add docker boot

  # May produce some 'limit' error that seems to be harmless
  service docker start
"

# 
# CONFIGURE: VPN-ready
# 
# * https://pve.proxmox.com/wiki/OpenVPN_in_LXC
# 

cat <<-'EOF' | set -e 's/^\s*//' | (set -x; tee -a /etc/pve/lxc/CT_ID.conf)
  lxc.mount.entry: /dev/net dev/net none bind,create=dir 0 0
  lxc.cgroup2.devices.allow: c 10:200 rwm
EOF

# Plus for GP in CentOS-likes
echo "lxc.cap.drop:" | (set -x; tee -a /etc/pve/lxc/CT_ID.conf)

# 
# CONFIGURE: VAAPI
# 

# Unprivileged
if [[ -e /dev/dri/renderD128 ]]; then
  echo 'dev0: /dev/dri/renderD128,gid=104'

  if [[ -e /dev/dri/card1 ]]; then
    echo 'dev1: /dev/dri/card1,gid=44'
  else
    echo 'dev1: /dev/dri/card0,gid=44'
  fi
fi | (set -x; tee -a /etc/pve/lxc/CT_ID.conf)

# Privileged
cat <<-'EOF' | set -e 's/^\s*//' | (set -x; tee -a /etc/pve/lxc/CT_ID.conf)
  lxc.cgroup2.devices.allow: c 226:0 rwm
  lxc.cgroup2.devices.allow: c 226:128 rwm
  lxc.cgroup2.devices.allow: c 29:0 rwm
  lxc.mount.entry: /dev/fb0 dev/fb0 none bind,optional,create=file
  lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir
  lxc.mount.entry: /dev/dri/card1 dev/dri/card1 none bind,optional,create=file
EOF
```
</details>

<details><summary>Ubuntu: Configure static IP</summary>

```yaml
## Reference: https://openvpn.net/as-docs/tutorials/tutorial--static-ip-on-ubuntu.html

## Modify the configuration
# cat /etc/netplan/01-netcfg.yaml
network:
  ethernets:
    eth0:           # Ethernet interface. `ip link` to list all available
    dhcp4: false    # Disable DHCP
    addresses: [192.0.2.2/24]  # Static IP / subnet mask
    routes:
      - to: default
        via: 192.0.2.254          # Default gateway
    nameservers:
      address: [192.168.0.2.254]  # DNS servers

## Apply the configuration
# netplan apply
```
</details>

[To top]

## Development

### Initial development setup

In order to configure local git hooks, issue inside the repository root directory:

```sh
./.dev/dev-init.sh
```

### Code compilation

Code compilation happens on `pre-commit`. It can be done manually by issuing:

```sh
./.dev/build.sh
```

This triggers:

* `short/compile-bash-project.sh src dest --no-ext '.ignore.sh'`. <details>
    <summary>More details on compilation processing</summary>
    
    <!-- .LH_ADHOC:short/compile-bash-project.sh --help | less -->
  </details>
* custom `*.md` files compilation
  * TODO: describe

[To top]

[To top]: #top
