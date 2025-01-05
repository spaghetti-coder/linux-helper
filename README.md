<a id="top"></a>

# Linux helper

* [Tools](#tools)
* [Config](#config)
* [Libraries](#libraries)
* [Helpers](#helpers)
* [Proxmox](#proxmox)
* [Development](#development)

## Tools

<a id="bin/compile-bash-file.sh"></a>
<details><summary>bin/compile-bash-file.sh</summary>

  [Link to the section](#bin/compile-bash-file.sh)
  
  **AD HOC:**
  ~~~sh
  # Review and change input params (after "bash -s --")
  # LH_VERSION can be changed to any treeish
  bash -- <(
    LH_VERSION='master'
    curl -V &>/dev/null && dl_tool=(curl -fsSL) || dl_tool=(wget -qO-)
    set -x; "${dl_tool[@]}" "https://github.com/spaghetti-coder/linux-helper/raw/${LH_VERSION:-master}/dist/bin/compile-bash-file.sh" \
    || "${dl_tool[@]}" "https://bitbucket.org/kvedenskii/linux-scripts/raw/${LH_VERSION:-master}/dist/bin/compile-bash-file.sh"
  ) [--] SRC_FILE DEST_FILE LIBS_PATH
  ~~~
  
  
  **MAN:**
  ~~~
  Compile bash script. Processing:
  * Replace '# .LH_SOURCE:path/to/lib.sh' comment lines with content of the
    pointed libs, while path to the lib is relative to LIBS_PATH directory
  * Everything after '# .LH_NOSOURCE' comment in the sourced files is ignored
    for sourcing
  * Sourced code is wrapped with comment. To avoid wrapping use
    '# .LH_SOURCE_NW:path/to/lib.sh' comment
  * Shebang from the sourced files are removed in the resulting file
  
  USAGE:
  =====
  compile-bash-file.sh [--] SRC_FILE DEST_FILE LIBS_PATH
  
  PARAMS:
  ======
  SRC_FILE    Source file
  DEST_FILE   Compilation destination file
  LIBS_PATH   Directory with libraries
  --          End of options
  
  DEMO:
  ====
  # Review the demo project
  cat ./src/lib/world.sh; echo '+++++'; \
  cat ./src/lib/hello.sh; echo '+++++'; \
  cat ./src/bin/script.sh
  ```OUTPUT:
  #!/usr/bin/env bash
  print_world() { echo "world"; }
  # .LH_NOSOURCE
  print_world
  +++++
  #!/usr/bin/env bash
  # .LH_SOURCE:lib/world.sh
  print_hello_world() { echo "Hello $(print_world)"; }
  +++++
  #!/usr/bin/env bash
  # .LH_SOURCE:lib/hello.sh
  print_hello_world
  ```
  
  # Compile to stdout
  compile-bash-file.sh ./src/bin/script.sh /dev/stdout ./src
  ```OUTPUT (stderr ignored):
  #!/usr/bin/env bash
  # .LH_SOURCED: {{ lib/hello.sh }}
  # .LH_SOURCED: {{ lib/world.sh }}
  print_world() { echo "world"; }
  # .LH_SOURCED: {{/ lib/world.sh }}
  print_hello_world() { echo "Hello $(print_world)"; }
  # .LH_SOURCED: {{/ lib/hello.sh }}
  print_hello_world
  ```
  ~~~
  
</details>

<a id="bin/demo.sh"></a>
<details><summary>bin/demo.sh</summary>

  [Link to the section](#bin/demo.sh)
  
  **AD HOC:**
  ~~~sh
  # Review and change input params (after "bash -s --")
  # LH_VERSION can be changed to any treeish
  bash -- <(
    LH_VERSION='master'
    curl -V &>/dev/null && dl_tool=(curl -fsSL) || dl_tool=(wget -qO-)
    set -x; "${dl_tool[@]}" "https://github.com/spaghetti-coder/linux-helper/raw/${LH_VERSION:-master}/dist/bin/demo.sh" \
    || "${dl_tool[@]}" "https://bitbucket.org/kvedenskii/linux-scripts/raw/${LH_VERSION:-master}/dist/bin/demo.sh"
  ) [--ask] [--age AGE='0'] [--domain DOMAIN="$(hostname -f)"] [--] NAME
  ~~~
  
  
  **MAN:**
  ~~~
  Just a demo boilerplate project to get user info.
  
  USAGE:
  =====
  demo.sh [--ask] [--age AGE='0'] [--domain DOMAIN="$(hostname -f)"] [--] NAME
  
  PARAMS:
  ======
  NAME    Person's name
  --      End of options
  --ask     Provoke a prompt for all params
  --age     Person's age
  --domain  Person's domain
  
  DEMO:
  ====
  # With all defaults
  demo.sh Spaghetti
  
  # Provie info interactively
  demo.sh --ask
  ~~~
  
</details>

<a id="bin/ssh-gen.sh"></a>
<details><summary>bin/ssh-gen.sh</summary>

  [Link to the section](#bin/ssh-gen.sh)
  
  **AD HOC:**
  ~~~sh
  # Review and change input params (after "bash -s --")
  # LH_VERSION can be changed to any treeish
  bash -- <(
    LH_VERSION='master'
    curl -V &>/dev/null && dl_tool=(curl -fsSL) || dl_tool=(wget -qO-)
    set -x; "${dl_tool[@]}" "https://github.com/spaghetti-coder/linux-helper/raw/${LH_VERSION:-master}/dist/bin/ssh-gen.sh" \
    || "${dl_tool[@]}" "https://bitbucket.org/kvedenskii/linux-scripts/raw/${LH_VERSION:-master}/dist/bin/ssh-gen.sh"
  ) [--ask] [--host HOST=HOSTNAME] [--port PORT='22'] \
    [--comment COMMENT="$(id -un)@$(hostname -f)"] [--dirname DIRNAME=HOSTNAME] \
    [--filename FILENAME=USER] [--dest-dir DEST_DIR] [--] HOSTNAME USER
  ~~~
  
  
  **MAN:**
  ~~~
  Generate private and public key pair and manage Include entry in ~/.ssh/config.
  
  USAGE:
  =====
  ssh-gen.sh [--ask] [--host HOST=HOSTNAME] [--port PORT='22'] \
    [--comment COMMENT="$(id -un)@$(hostname -f)"] [--dirname DIRNAME=HOSTNAME] \
    [--filename FILENAME=USER] [--dest-dir DEST_DIR] [--] HOSTNAME USER
  
  PARAMS:
  ======
  HOSTNAME  The actual SSH host. With values like '%h' (the target hostname)
            must provide --host and most likely --dirname
  USER      SSH user
  --        End of options
  --ask     Provoke a prompt for all params
  --host    SSH host match pattern
  --port    SSH port
  --comment   Certificate comment
  --dirname   Destination directory name
  --filename  SSH identity key file name
  --dest-dir  Custom destination directory. In case the option is provided
              --dirname option is ignored and Include entry won't be created in
              ~/.ssh/config file. The directory will be autocreated
  
  DEMO:
  ====
  # Generate with all defaults to PK file ~/.ssh/10.0.0.69/user
  ssh-gen.sh 10.0.0.69 user
  
  # Generate to ~/.ssh/_.serv.com/bar instead of ~/.ssh/%h/foo
  ssh-gen.sh --host 'serv.com *.serv.com' --comment Zoo --dirname '_.serv.com' \
    --filename 'bar' -- '%h' foo
  
  # Generate interactively to ~/my/certs/foo (will be prompted for params).
  ssh-gen.sh --ask --dest-dir ~/my/certs/foo
  ~~~
  
</details>

<a id="short/compile-bash-project.sh"></a>
<details><summary>short/compile-bash-project.sh</summary>

  [Link to the section](#short/compile-bash-project.sh)
  
  **AD HOC:**
  ~~~sh
  # Review and change input params (after "bash -s --")
  # LH_VERSION can be changed to any treeish
  bash -- <(
    LH_VERSION='master'
    curl -V &>/dev/null && dl_tool=(curl -fsSL) || dl_tool=(wget -qO-)
    set -x; "${dl_tool[@]}" "https://github.com/spaghetti-coder/linux-helper/raw/${LH_VERSION:-master}/dist/short/compile-bash-project.sh" \
    || "${dl_tool[@]}" "https://bitbucket.org/kvedenskii/linux-scripts/raw/${LH_VERSION:-master}/dist/short/compile-bash-project.sh"
  ) [--ext EXT='.sh']... [--no-ext NO_EXT]... [--] \
    SRC_DIR DEST_DIR
  ~~~
  
  
  **MAN:**
  ~~~
  Shortcut for compile-bash-file.sh to compile complete bash project. Processing:
  * Compile each file under SRC_DIR to same path of DEST_DIR
  * Replace '# .LH_SOURCE:path/to/lib.sh' comment lines with content of the
    pointed libs, while path to the lib is relative to SRC_DIR directory
  * Everything after '# .LH_NOSOURCE' comment in the sourced files is ignored
    for sourcing
  * Sourced code is wrapped with comment. To avoid wrapping use comment
    '# .LH_SOURCE_NW:path/to/lib.sh' or '# .LH_SOURCE_NOW_WRAP:path/to/lib.sh'
  * Shebang from the sourced files are removed in the resulting file
  
  USAGE:
  =====
  compile-bash-project.sh [--ext EXT='.sh']... [--no-ext NO_EXT]... [--] \
    SRC_DIR DEST_DIR
  
  PARAMS:
  ======
  SRC_DIR     Source directory
  DEST_DIR    Compilation destination directory
  --          End of options
  --ext       Array of extension patterns of files to be compiled
  --no-ext    Array of exclude extension patterns
  
  DEMO:
  ====
  # Compile all '.sh' and '.bash' files under 'src' directory to 'dest'
  # excluding files with '.hidden.sh' and '.secret.sh' extensions
  compile-bash-project.sh ./src ./dest --ext '.sh' --ext '.bash' \
    --no-ext '.hidden.sh' --no-ext '.secret.sh'
  ~~~
  
</details>

<a id="short/ssh-gen-github.sh"></a>
<details><summary>short/ssh-gen-github.sh</summary>

  [Link to the section](#short/ssh-gen-github.sh)
  
  **AD HOC:**
  ~~~sh
  # Review and change input params (after "bash -s --")
  # LH_VERSION can be changed to any treeish
  bash -- <(
    LH_VERSION='master'
    curl -V &>/dev/null && dl_tool=(curl -fsSL) || dl_tool=(wget -qO-)
    set -x; "${dl_tool[@]}" "https://github.com/spaghetti-coder/linux-helper/raw/${LH_VERSION:-master}/dist/short/ssh-gen-github.sh" \
    || "${dl_tool[@]}" "https://bitbucket.org/kvedenskii/linux-scripts/raw/${LH_VERSION:-master}/dist/short/ssh-gen-github.sh"
  ) [--ask] [--host HOST='github.com'] \
    [--comment COMMENT="$(id -un)@$(hostname -f)"] [--] [ACCOUNT='git']
  ~~~
  
  
  **MAN:**
  ~~~
  github.com centric shortcut of ssh-gen.sh tool. Generate private and public key
  pair and configure ~/.ssh/config file to use them.
  
  USAGE:
  =====
  ssh-gen-github.sh [--ask] [--host HOST='github.com'] \
    [--comment COMMENT="$(id -un)@$(hostname -f)"] [--] [ACCOUNT='git']
  
  PARAMS:
  ======
  ACCOUNT   Github account name, only used to make cert filename, for SSH
            connection 'git' user will be used.
  --        End of options
  --ask     Provoke a prompt for all params
  --host    SSH host match pattern
  --comment Certificate comment
  
  DEMO:
  ====
  # Generate with all defaults to PK file ~/.ssh/github.com/git
  ssh-gen-github.sh
  
  # Generate to ~/.ssh/github.com/foo
  ssh-gen-github.sh foo --host github.com-foo --comment Zoo
  ~~~
  
</details>

<a id="short/ssh-gen-vc.sh"></a>
<details><summary>short/ssh-gen-vc.sh</summary>

  [Link to the section](#short/ssh-gen-vc.sh)
  
  **AD HOC:**
  ~~~sh
  # Review and change input params (after "bash -s --")
  # LH_VERSION can be changed to any treeish
  bash -- <(
    LH_VERSION='master'
    curl -V &>/dev/null && dl_tool=(curl -fsSL) || dl_tool=(wget -qO-)
    set -x; "${dl_tool[@]}" "https://github.com/spaghetti-coder/linux-helper/raw/${LH_VERSION:-master}/dist/short/ssh-gen-vc.sh" \
    || "${dl_tool[@]}" "https://bitbucket.org/kvedenskii/linux-scripts/raw/${LH_VERSION:-master}/dist/short/ssh-gen-vc.sh"
  ) [--ask] [--host HOST=HOSTNAME] [--port PORT='22'] \
    [--comment COMMENT="$(id -un)@$(hostname -f)"] [--] HOSTNAME [ACCOUNT=git]
  ~~~
  
  
  **MAN:**
  ~~~
  Generic version control system centric shortcut of ssh-gen.sh tool. Generate
  private and public key pair and configure ~/.ssh/config file to use them.
  
  USAGE:
  =====
  ssh-gen-vc.sh [--ask] [--host HOST=HOSTNAME] [--port PORT='22'] \
    [--comment COMMENT="$(id -un)@$(hostname -f)"] [--] HOSTNAME [ACCOUNT=git]
  
  PARAMS:
  ======
  HOSTNAME  VC system hostname
  ACCOUNT   VC system account name, only used to make cert filename, for SSH
            connection 'git' user will be used.
  --        End of options
  --ask     Provoke a prompt for all params
  --host    SSH host match pattern
  --port    SSH port
  --comment Certificate comment
  
  DEMO:
  ====
  # Generate with all defaults to PK file ~/.ssh/github.com/git
  ssh-gen-vc.sh github.com
  
  # Generate to ~/.ssh/github.com/bar with custom hostname and comment
  ssh-gen-vc.sh github.com bar --host github.com-bar --comment Zoo
  ~~~
  
</details>

[To top]

## Config

<a id="config/bash/bashrcd.sh"></a>
<details><summary>config/bash/bashrcd.sh</summary>

  [Link to the section](#config/bash/bashrcd.sh)
  
  **AD HOC:**
  ~~~sh
  # Review and change input params (after "bash -s --")
  # LH_VERSION can be changed to any treeish
  bash -- <(
    LH_VERSION='master'
    curl -V &>/dev/null && dl_tool=(curl -fsSL) || dl_tool=(wget -qO-)
    set -x; "${dl_tool[@]}" "https://github.com/spaghetti-coder/linux-helper/raw/${LH_VERSION:-master}/dist/config/bash/bashrcd.sh" \
    || "${dl_tool[@]}" "https://bitbucket.org/kvedenskii/linux-scripts/raw/${LH_VERSION:-master}/dist/config/bash/bashrcd.sh"
  )
  ~~~
  
  
  **MAN:**
  ~~~
  Create ~/.bashrc.d directory and source all its '*.sh' scripts to ~/.bashrc
  
  USAGE:
  =====
  bashrcd.sh
  
  DEMO:
  ====
  bashrcd.sh
  ~~~
  
</details>

<a id="config/git/git-ps1.sh"></a>
<details><summary>config/git/git-ps1.sh</summary>

  [Link to the section](#config/git/git-ps1.sh)
  
  **AD HOC:**
  ~~~sh
  # Review and change input params (after "bash -s --")
  # LH_VERSION can be changed to any treeish
  bash -- <(
    LH_VERSION='master'
    curl -V &>/dev/null && dl_tool=(curl -fsSL) || dl_tool=(wget -qO-)
    set -x; "${dl_tool[@]}" "https://github.com/spaghetti-coder/linux-helper/raw/${LH_VERSION:-master}/dist/config/git/git-ps1.sh" \
    || "${dl_tool[@]}" "https://bitbucket.org/kvedenskii/linux-scripts/raw/${LH_VERSION:-master}/dist/config/git/git-ps1.sh"
  )
  ~~~
  
  
  **MAN:**
  ~~~
  Cusomize bash PS1 prompt for git
  
  USAGE:
  =====
  git-ps1.sh
  
  DEMO:
  ====
  git-ps1.sh
  ~~~
  
</details>

<a id="config/git/gitconfig.extra.ini"></a>
<details><summary>config/git/gitconfig.extra.ini</summary>

  [Link to the section](#config/git/gitconfig.extra.ini)

  View [`gitconfig.extra.ini`](https://github.com/spaghetti-coder/linux-helper/raw/master/src/asset/conf/git/gitconfig.extra.ini)
  
  **AD HOC:**

  ~~~sh
  # VERSION can be changed to any treeish
  (
    VERSION='master'
    curl -V &>/dev/null && dl_tool=(curl -fsSL) || dl_tool=(wget -qO-)
    set -x; "${dl_tool[@]}" "https://github.com/spaghetti-coder/linux-helper/raw/${VERSION:-master}/src/asset/conf/git/gitconfig.extra.ini" \
    || "${dl_tool[@]}" "https://bitbucket.org/kvedenskii/linux-scripts/raw/${VERSION:-master}/src/asset/conf/git/gitconfig.extra.ini"
  ) | (set -x; tee ~/.gitconfig.lh-extra.ini >/dev/null) && {
    git config --global --get-all include.path | grep -qFx '~/.gitconfig.lh-extra.ini' \
    || (set -x; git config --global --add include.path '~/.gitconfig.lh-extra.ini')
  }
  ~~~
</details>

<a id="config/tmux/tmux-default.sh"></a>
<details><summary>config/tmux/tmux-default.sh</summary>

  [Link to the section](#config/tmux/tmux-default.sh)

  View [`default.conf`](https://github.com/spaghetti-coder/linux-helper/raw/master/src/asset/conf/tmux/default.conf)
  
  **AD HOC:**
  ~~~sh
  # Review and change input params (after "bash -s --")
  # LH_VERSION can be changed to any treeish
  bash -- <(
    LH_VERSION='master'
    curl -V &>/dev/null && dl_tool=(curl -fsSL) || dl_tool=(wget -qO-)
    set -x; "${dl_tool[@]}" "https://github.com/spaghetti-coder/linux-helper/raw/${LH_VERSION:-master}/dist/config/tmux/tmux-default.sh" \
    || "${dl_tool[@]}" "https://bitbucket.org/kvedenskii/linux-scripts/raw/${LH_VERSION:-master}/dist/config/tmux/tmux-default.sh"
  ) [--] [CONFD="${HOME}/.tmux"]
  ~~~
  
  
  **MAN:**
  ~~~
  Generate basic tmux configuration preset and source it to ~/.tmux.conf file. The
  config is with the following content:
  
  ```
  # default.conf
  
  set-option -g prefix C-Space
  set-option -g allow-rename off
  set -g history-limit 100000
  set -g renumber-windows on
  set -g base-index 1
  set -g display-panes-time 3000
  setw -g pane-base-index 1
  setw -g aggressive-resize on
  ```
  
  USAGE:
  =====
  tmux-default.sh [--] [CONFD="${HOME}/.tmux"]
  
  PARAMS:
  ======
  CONFD   Confd directory to store tmux custom configurations
  --      End of options
  
  DEMO:
  ====
  # Generate with all defaults to "${HOME}/.tmux/default.conf"
  tmux-default.sh
  
  # Generate to /etc/tmux/default.conf. Requires sudo for non-root user
  sudo tmux-default.sh /etc/tmux
  ~~~
  
</details>

<a id="config/tmux/tmux-plugins.sh"></a>
<details><summary>config/tmux/tmux-plugins.sh</summary>

  [Link to the section](#config/tmux/tmux-plugins.sh)

  View [`plugins.conf`](https://github.com/spaghetti-coder/linux-helper/raw/master/src/asset/conf/tmux/plugins.conf) and [`appendix.conf`](https://github.com/spaghetti-coder/linux-helper/raw/master/src/asset/conf/tmux/appendix.conf)
  
  **AD HOC:**
  ~~~sh
  # Review and change input params (after "bash -s --")
  # LH_VERSION can be changed to any treeish
  bash -- <(
    LH_VERSION='master'
    curl -V &>/dev/null && dl_tool=(curl -fsSL) || dl_tool=(wget -qO-)
    set -x; "${dl_tool[@]}" "https://github.com/spaghetti-coder/linux-helper/raw/${LH_VERSION:-master}/dist/config/tmux/tmux-plugins.sh" \
    || "${dl_tool[@]}" "https://bitbucket.org/kvedenskii/linux-scripts/raw/${LH_VERSION:-master}/dist/config/tmux/tmux-plugins.sh"
  ) [--] [CONFD="${HOME}/.tmux"]
  ~~~
  
  
  **MAN:**
  ~~~
  Generate plugins tmux configuration preset and source it to ~/.tmux.conf file.
  tmux and git are required to be installed for this script. The configs are with
  the following content:
  
  ```
  # plugins.conf
  
  set -g @plugin 'tmux-plugins/tpm'
  set -g @plugin 'tmux-plugins/tmux-sensible'
  set -g @plugin 'tmux-plugins/tmux-resurrect'
  set -g @plugin 'tmux-plugins/tmux-sidebar'
  
  # set-environment -g TMUX_PLUGIN_MANAGER_PATH '~/.tmux/plugins'
  # run -b '~/.tmux/plugins/tpm/tpm'
  ```
  
  ```
  # appendix.conf
  
  set-environment -g TMUX_PLUGIN_MANAGER_PATH '~/.tmux/plugins'
  run -b '~/.tmux/plugins/tpm/tpm'
  ```
  
  USAGE:
  =====
  tmux-plugins.sh [--] [CONFD="${HOME}/.tmux"]
  
  PARAMS:
  ======
  CONFD   Confd directory to store tmux custom configurations
  --      End of options
  
  DEMO:
  ====
  # Generate with all defaults to "${HOME}/.tmux"/{appendix,plugins}.conf
  tmux-plugins.sh
  
  # Generate to /etc/tmux/{appendix,plugins}.conf. Requires sudo for non-root user
  sudo tmux-plugins.sh /etc/tmux
  ~~~
  
</details>  

[To top]

## Helpers

<a id="helper/docker-template.sh"></a>
<details><summary>helper/docker-template.sh</summary>

  [Link to the section](#helper/docker-template.sh)

  Merge and compile docker-compose template(s).

  **Usage demo**:

  See [`docker-compose.npm.tpl.yaml`](https://github.com/spaghetti-coder/linux-helper/raw/master/src/asset/docker/docker-compose.npm.tpl.yaml) and [`docker-compose.nginx-proxy.tpl.yaml`](https://github.com/spaghetti-coder/linux-helper/raw/master/src/asset/docker/docker-compose.nginx-proxy.tpl.yaml)

  ~~~sh
  # LH_VERSION can be changed to any treeish
  bash -- <(
    LH_VERSION='master'
    curl -V &>/dev/null && dl_tool=(curl -fsSL) || dl_tool=(wget -qO-)
    set -x; "${dl_tool[@]}" "https://github.com/spaghetti-coder/linux-helper/raw/${LH_VERSION:-master}/dist/helper/docker-template.sh" \
    || "${dl_tool[@]}" "https://bitbucket.org/kvedenskii/linux-scripts/raw/${LH_VERSION:-master}/dist/helper/docker-template.sh"
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

<a id="pve/bin/deploy-lxc.sh"></a>
<details><summary>pve/bin/deploy-lxc.sh</summary>

  [Link to the section](#pve/bin/deploy-lxc.sh)
  
  **AD HOC:**
  ~~~sh
  # Review and change input params (after "bash -s --")
  # LH_VERSION can be changed to any treeish
  bash -- <(
    LH_VERSION='master'
    curl -V &>/dev/null && dl_tool=(curl -fsSL) || dl_tool=(wget -qO-)
    set -x; "${dl_tool[@]}" "https://github.com/spaghetti-coder/linux-helper/raw/${LH_VERSION:-master}/dist/pve/bin/deploy-lxc.sh" \
    || "${dl_tool[@]}" "https://bitbucket.org/kvedenskii/linux-scripts/raw/${LH_VERSION:-master}/dist/pve/bin/deploy-lxc.sh"
  ) [ID] [--ask] [--storage STORAGE] [--template TEMPLATE='ubuntu-24.04'] \
    [--disk DISK] [--ram RAM] [--swap SWAP] [--cores CORES] [--privileged] [--onboot] \
    [--ostype OSTYPE] [--pass PASS] [--pass-envvar PASS_ENVVAR='LH_LXC_ROOT_PASS'] \
    [--hostname HOSTNAME] [--net-bridge NET_BRIDGE='vmbr0'] [--ip IP='dhcp'] \
    [--gateway GATEWAY] [--profile PROFILE]... [--after-create AFTER_CREATE]... \
    [--in-container IN_CONTAINER]...
  ~~~
  
  Or download it locally, edit configration section of the downloaded file and execute

  ~~~sh
  # LH_VERSION can be changed to any treeish
  (
    LH_VERSION='master'
    curl -V &>/dev/null && dl_tool=(curl -fsSL) || dl_tool=(wget -qO-)
    set -x; "${dl_tool[@]}" "https://github.com/spaghetti-coder/linux-helper/raw/${LH_VERSION:-master}/dist/pve/bin/deploy-lxc.sh" \
    || "${dl_tool[@]}" "https://bitbucket.org/kvedenskii/linux-scripts/raw/${LH_VERSION:-master}/dist/pve/bin/deploy-lxc.sh"
  ) | (DEST=./my-lxc.sh; set -x; tee -- "${DEST}" >/dev/null; chmod +x -- "${DEST}")
  ~~~
  
  **MAN:**
  ~~~
  Deploy LXC container using self-contained script. Likely supported:
  * alpine
  * centos-like (8+)
  * debian
  * ubuntu
  
  USAGE:
  =====
  deploy-lxc.sh [ID] [--ask] [--storage STORAGE] [--template TEMPLATE='ubuntu-24.04'] \
    [--disk DISK] [--ram RAM] [--swap SWAP] [--cores CORES] [--privileged] [--onboot] \
    [--ostype OSTYPE] [--pass PASS] [--pass-envvar PASS_ENVVAR='LH_LXC_ROOT_PASS'] \
    [--hostname HOSTNAME] [--net-bridge NET_BRIDGE='vmbr0'] [--ip IP='dhcp'] \
    [--gateway GATEWAY] [--profile PROFILE]... [--after-create AFTER_CREATE]... \
    [--in-container IN_CONTAINER]...
  
  PARAMS:
  ======
  ID          Numeric LXC container ID. Defaults to automanaged
  --ask       Provoke a prompt for all params
  --storage   PVE storage to use. Defaults to automanaged
  --template  Container template best guess hint from
              http://download.proxmox.com/images/system
              Or direct http(s) link:
              * https://images.linuxcontainers.org/images/
              * http://mirror.turnkeylinux.org/turnkeylinux/images/proxmox/
              * https://images.lxd.canonical.com/images/
              Demo: https://benheater.com/proxmox-lxc-using-external-templates/
  --ostype    Use if you know what you are doing
  --disk      Disk size in GB. Defaults to template default
  --ram       RAM size in MB. Defaults to PVE default
  --swap      SWAP size in MB. Defaults to PVE default
  --cores     Number of cores. Defaults to all available in PVE host
  --privileged  Privileged container. Can be manipulated by some of profiles
  --onboot      Start container on PVE boot
  --pass        Container root password. If not set will attempt to get it from
                the env variable provided by --pass-envvar. In the end
                container root password must be reachable.
  --pass-envvar Environment variable to read container root password from
  --hostname    Container hostname
  --net-bridge  PVE bridge network
  --ip          Container IP or 'dhcp' if managed by the router
  --gateway     Default gateway. Required when IP is not 'dhcp'
  --profile     Convenience profiles configuring the container for some purpose.
                Can be set multiple times or space separated
  --after-create  Hook function that will run after container created on the PVE
                  machine. Can be set multiple times or space separated. The
                  function must be accessible in the configuration file.
  --in-container  Hook function that will run in the container. The container
                  will be started and stopped automatically. Can be set multiple
                  times or space separated. The function must be accessible in
                  the configuration file.
  
  PROFILES:
  ========
  * comfort - a bit more comfortable environment in the container
  * docker - docker installed (docker-ready profile included)
  * docker-ready - container is ready for docker installation
  * vaapi - VAAPI hardware transcoding
  * vpn-ready - container is ready for VPN
  
  DEMO:
  ====
  # Edit configuration section in deploy-lxc.sh and run it to deploy LXC
  deploy-lxc.sh
  
  # Run overriding some configs in the configuration file and in
  # interactive mode
  LXC_PASS=qwerty deploy-lxc.sh --ask --privileged --disk 45 \
    --pass-env LXC_PASS 120
  ~~~
  
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
    
    
    **AD HOC:**
    ~~~sh
    # Review and change input params (after "bash -s --")
    # LH_VERSION can be changed to any treeish
    bash -- <(
      LH_VERSION='master'
      curl -V &>/dev/null && dl_tool=(curl -fsSL) || dl_tool=(wget -qO-)
      set -x; "${dl_tool[@]}" "https://github.com/spaghetti-coder/linux-helper/raw/${LH_VERSION:-master}/dist/short/compile-bash-project.sh" \
      || "${dl_tool[@]}" "https://bitbucket.org/kvedenskii/linux-scripts/raw/${LH_VERSION:-master}/dist/short/compile-bash-project.sh"
    ) --help | less
    ~~~
    
  </details>
* custom `*.md` files compilation
  * TODO: describe

[To top]

[To top]: #top
