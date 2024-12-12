<a id="top"></a>

# Linux helper

* [Tools](#tools)
* [Config](#config)
* [Proxmox](#proxmox)
* [Libraries](#libraries)
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

## Proxmox

<a id="pve/bin/deploy-lxc.sh"></a>
<details><summary>pve/bin/deploy-lxc.sh</summary>

  [Link to the section](#pve/bin/deploy-lxc.sh)

  <!-- .LH_ADHOC_USAGE:pve/bin/deploy-lxc.sh -->
  Or download it locally, edit configration section of the downloaded file and execute

  ~~~sh
  # LH_VERSION can be changed to any treeish
  (
    LH_VERSION='master'
    curl -V &>/dev/null && dl_tool=(curl -fsSL) || dl_tool=(wget -qO-)
    set -x; "${dl_tool[@]}" "@@BASE_RAW_URL/${LH_VERSION:-master}/dist/pve/bin/deploy-lxc.sh" \
    || "${dl_tool[@]}" "@@BASE_RAW_URL_ALT/${LH_VERSION:-master}/dist/pve/bin/deploy-lxc.sh"
  ) | (DEST=./my-lxc.sh; set -x; tee -- "${DEST}" >/dev/null; chmod +x -- "${DEST}")
  ~~~
  <!-- .LH_HELP:pve/bin/deploy-lxc.sh -->
</details>  

[To top]

## Libraries

TODO

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
