<a id="top"></a>

# Linux helper

* [Tools](#tools)
* [Config](#config)
* [Libraries](#libraries)
* [Development](#development)

## Tools

<a id="bin/compile-bash-file.sh"></a>
<details><summary>bin/compile-bash-file.sh</summary>
  <!-- .LH_ADHOC:bin/compile-bash-file.sh -->
  <!-- .LH_HELP:bin/compile-bash-file.sh -->
</details>  
<a id="bin/ssh-gen.sh"></a>
<details><summary>bin/ssh-gen.sh</summary>
  <!-- .LH_ADHOC:bin/ssh-gen.sh -->
  <!-- .LH_HELP:bin/ssh-gen.sh -->
</details>  
<a id="short/compile-bash-project.sh"></a>
<details><summary>short/compile-bash-project.sh</summary>
  <!-- .LH_ADHOC:short/compile-bash-project.sh -->
  <!-- .LH_HELP:short/compile-bash-project.sh -->
</details>  
<a id="short/ssh-gen-github.sh"></a>
<details><summary>short/ssh-gen-github.sh</summary>
  <!-- .LH_ADHOC:short/ssh-gen-github.sh -->
  <!-- .LH_HELP:short/ssh-gen-github.sh -->
</details>  

[To top]

## Config

<a id="config/tmux"></a>
<details><summary>config/tmux</summary>

  `TMUX_CONFD` - tmux confd directory. To install to some system directory prefix the command with `sudo`.

  To view the configurations pass `--info` flag as the first param to the scripts.

  Install tmux basic configurations.

  ~~~sh
  # default.conf
  bash <(
    # Can be changed to tag or commit ID
    VERSION="master"
    curl -V &>/dev/null && dl_tool=(curl -sfL) || dl_tool=(wget -qO-)
    set -x; "${dl_tool[@]}" "@@BASE_RAW_URL/${VERSION}/dist/config/tmux/default.sh" \
    || "${dl_tool[@]}" "@@BASE_RAW_URL_ALT/${VERSION}/dist/config/tmux/default.sh"
  ) [TMUX_CONFD="${HOME}/.tmux"]
  ~~~

  Install tmux plugins configurations (requires git and tmux installed):

  ~~~sh
  # plugins.conf
  bash <(
    # Can be changed to tag or commit ID
    VERSION="master"
    curl -V &>/dev/null && dl_tool=(curl -sfL) || dl_tool=(wget -qO-)
    set -x; "${dl_tool[@]}" "@@BASE_RAW_URL/${VERSION}/dist/config/tmux/plugins.sh" \
    || "${dl_tool[@]}" "@@BASE_RAW_URL_ALT/${VERSION}/dist/config/tmux/plugins.sh"
  ) [TMUX_CONFD="${HOME}/.tmux"]
  ~~~
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
./.dev/compile.sh
```

Compiler searches in the `src/*.sh` comments of type

```sh
# .LH_SOURCE:lib/basic.sh
```

* `# .LH_SOURCE:` is the marker for replacing this comment with a library code. Must be in the very beginning of the line.
* `lib/basic.sh` is path to the file that will be included. The path is within `src` directory.
* `# .LH_NOSOURCE` comment in the lib file and following lines up to the end of file won't be included.

The compiled files go to the `dist` directory

[To top]

[To top]: #top
