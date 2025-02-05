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

<a id="asset/gotify-push.sh"></a>
<details><summary>asset/gotify-push.sh</summary>

  [Link to the section](#asset/gotify-push.sh)

  View [`gotify-push.sh`](https://github.com/spaghetti-coder/linux-helper/raw/master/dist/asset/gotify-push.sh)
  
  **AD HOC:**

  ~~~sh
  # VERSION can be changed to any treeish
  (
    VERSION='master'
    curl -V &>/dev/null && dl_tool=(curl -fsSL) || dl_tool=(wget -qO-)
    set -x; "${dl_tool[@]}" "https://github.com/spaghetti-coder/linux-helper/raw/${VERSION:-master}/dist/asset/gotify-push.sh" \
    || "${dl_tool[@]}" "https://bitbucket.org/kvedenskii/linux-scripts/raw/${VERSION:-master}/dist/asset/gotify-push.sh"
  ) | (set -x; tee ~/gotify-push.sh >/dev/null && chmod +x ~/gotify-push.sh)
  ~~~
</details>

<a id="asset/dydns.sh"></a>
<details><summary>asset/dydns.sh</summary>

  [Link to the section](#asset/dydns.sh)

  **AD HOC:**

  ~~~sh
  # VERSION can be changed to any treeish
  (
    VERSION='master'
    curl -V &>/dev/null && dl_tool=(curl -fsSL) || dl_tool=(wget -qO-)
    set -x; "${dl_tool[@]}" "https://github.com/spaghetti-coder/linux-helper/raw/${VERSION:-master}/dist/asset/dydns.sh" \
    || "${dl_tool[@]}" "https://bitbucket.org/kvedenskii/linux-scripts/raw/${VERSION:-master}/dist/asset/dydns.sh"
  ) | (set -x; tee ~/dydns.sh >/dev/null && chmod +x ~/dydns.sh)
  ~~~
  
  **MAN:**
  ~~~
  Update dynamic DNS. Supported providers:
  * duckdns
  * dynu
  * now-dns
  * ydns
  
  For help on a specific provider issue:
    dydns.sh PROVIDER --help
  
  Requirements:
  * bash
  * curl
  * crontab (only for configuring scheduled IP updates)
  
  USAGE:
  =====
  # Token and domains must be provided either via environment
  # variables or via options
  [export <PROVIDER_PREFIX>_TOKEN=...]
  [export <PROVIDER_PREFIX>_DOMAINS=...]
  [export <PROVIDER_PREFIX>_SCHEDULE=...]
  [export <PROVIDER_PREFIX>_ONDONE=...]
  dydns.sh PROVIDER [DOMAINS...] [--token TOKEN] \
    [--ondone ONDONE_SCRIPT] [--schedule SCHEDULE [--dry]]
  
  DEMO:
  ====
  #
  # Provider:           now-dns (https://now-dns.com)
  # Domains:            site1.mypi.co, site2.ddns.cam
  # Registration email: foo@bar.baz
  # Token:              secret-token
  #
  
  # Update domains manually
  dydns.sh now-dns --token 'foo@bar.baz:secret-token' \
    'site1.mypi.co,site2.ddns.cam'
  
  # Same, but domains are in multiple positional params
  dydns.sh now-dns --token 'foo@bar.baz:secret-token' \
    'site1.mypi.co' 'site2.ddns.cam'
  
  # Same, but using env variables. Domains are only comma-separated
  export NOW_DNS_TOKEN='foo@bar.baz:secret-token'
  export NOW_DNS_DOMAINS='site1.mypi.co,site2.ddns.cam'
  dydns.sh now-dns
  
  # Install 'now-dns' provider to ${HOME}/.dydns/now-dns dorectory, schedule DyDNS
  # updates with ~/log.sh script run on each update. To access installed provider:
  #   "${HOME}/.dydns/now-dns/now-dns.sh" `# with --help flag to view help`
  # Also the following crontab entry will be created:
  #   */5 * * * * ... '/home/bug1/.dydns/now-dns/now-dns.sh'
  # After installing all desired providers 'dydns.sh' script can be deleted.
  dydns.sh now-dns --schedule '*/5 * * * *' --ondone ~/log.sh \
    --token 'foo@bar.baz:secret-token' 'site1.mypi.co,site2.ddns.cam'
  # Optionally create the log script
  printf -- '%s\n' '#!/usr/bin/env bash' '' \
    '# RC - 0 for successful update or 1 for failure' \
    '# MSG - response message from the provider' \
    'echo "RC=${1}; MSG=${2}; PROVIDER=${3}; DOMAINS=${4}" >> ~/dydns.log' \
    > ~/log.sh; chmod +x ~/log.sh
  
  # Same as previous, but without logger and cron configuration. They can be
  # configured later with the installed provider script (see its '--help').
  dydns.sh now-dns --dry --schedule '*/5 * * * *' \
    --token 'foo@bar.baz:secret-token' 'site1.mypi.co,site2.ddns.cam'
  ~~~
  
</details>

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

<a id="pve/bin/deploy-lxc.tpl.sh"></a>
<details><summary>pve/bin/deploy-lxc.tpl.sh</summary>

  [Link to the section](#pve/bin/deploy-lxc.tpl.sh)

  **AD HOC:**
  ~~~sh
  # LH_VERSION can be changed to any treeish
  (
    LH_VERSION='master'
    curl -V &>/dev/null && dl_tool=(curl -fsSL) || dl_tool=(wget -qO-)
    set -x; "${dl_tool[@]}" "https://github.com/spaghetti-coder/linux-helper/raw/${LH_VERSION:-master}/dist/pve/bin/deploy-lxc.tpl.sh" \
    || "${dl_tool[@]}" "https://bitbucket.org/kvedenskii/linux-scripts/raw/${LH_VERSION:-master}/dist/pve/bin/deploy-lxc.tpl.sh"
  ) | (DEST=./my-lxc.sh; set -x; tee -- "${DEST}" >/dev/null; chmod +x -- "${DEST}")
  ~~~
  
  **MAN:**
  ~~~
  Just clone the current script and edit the config section in the file top.
  Review all the configuration sections for demo usage.
  ~~~
  
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
