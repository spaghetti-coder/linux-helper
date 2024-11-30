<a id="top"></a>

# Linux helper

* [Tools](#tools)
* [Config](#config)
* [Libraries](#libraries)
* [Development](#development)

## Tools

<a id="bin/compile-bash-file.sh"></a>
<details><summary>bin/compile-bash-file.sh</summary>
  
  **AD HOC:**
  ~~~sh
  # Review and change input params
  bash <(
    # Can be changed to tag or commit ID
    VERSION="master"
    curl -V &>/dev/null && dl_tool=(curl -sL) || dl_tool=(wget -qO-)
    set -x; "${dl_tool[@]}" "https://raw.githubusercontent.com/spaghetti-coder/linux-helper/${VERSION}/dist/bin/compile-bash-file.sh" \
    || "${dl_tool[@]}" "https://bitbucket.org/kvedenskii/linux-scripts/raw/${VERSION}/dist/bin/compile-bash-file.sh"
  ) \
    [--] SRC_FILE DEST_FILE LIBS_PATH
  ~~~
  
  
  **MAN:**
  ~~~
  Compile bash script. Processing:
  * Replace '# .LH_SOURCE:path/to/lib.sh' comment lines with content of the
    pointed libs, while path to the lib is relative to LIBS_PATH directory
  * Everything after '# .LH_NOSOURCE' comment in the sourced files is
    ignored for sourcing
  * Sourced code is embraced with comment
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
<a id="bin/ssh-gen.sh"></a>
<details><summary>bin/ssh-gen.sh</summary>
  
  **AD HOC:**
  ~~~sh
  # Review and change input params
  bash <(
    # Can be changed to tag or commit ID
    VERSION="master"
    curl -V &>/dev/null && dl_tool=(curl -sL) || dl_tool=(wget -qO-)
    set -x; "${dl_tool[@]}" "https://raw.githubusercontent.com/spaghetti-coder/linux-helper/${VERSION}/dist/bin/ssh-gen.sh" \
    || "${dl_tool[@]}" "https://bitbucket.org/kvedenskii/linux-scripts/raw/${VERSION}/dist/bin/ssh-gen.sh"
  ) \
    [--port PORT='22'] [--host HOST=HOSTNAME] \
    [--comment COMMENT="$(id -un)@$(hostname -f)"] [--dirname DIRNAME=HOSTNAME] \
    [--filename FILENAME=USER] [--dest-dir DEST_DIR="${HOME}/.ssh/"HOSTNAME] \
    [--ask] [--] USER HOSTNAME
  ~~~
  
  
  **MAN:**
  ~~~
  Generate private and public key pair and manage Include entry in ~/.ssh/config
  file. For option replacements environment variables can be used, by prefixing
  env var with 'SG_', turning opt name to uppercase and replacing '-' with '_'
  (--dest-dir ~/serv.com/ => SG_DEST_DIR="${HOME}/serv.com/")
  
  USAGE:
  =====
  ssh-gen.sh [--port PORT='22'] [--host HOST=HOSTNAME] \
    [--comment COMMENT="$(id -un)@$(hostname -f)"] [--dirname DIRNAME=HOSTNAME] \
    [--filename FILENAME=USER] [--dest-dir DEST_DIR="${HOME}/.ssh/"HOSTNAME] \
    [--ask] [--] USER HOSTNAME
  
  PARAMS:
  ======
  USER      SSH user
  HOSTNAME  The actual SSH host. When values like '%h' (the target hostname)
            used, must provide --host and most likely --dirname
  --        End of options
  --port    SSH port
  --host    SSH host match pattern
  --comment   Certificate comment
  --dirname   Destination directory name
  --filename  Destination file name
  --dest-dir  Custom destination directory. In case the option is provided
              --dirname option is ignored and Include entry won't be created in
              ~/.ssh/config file. The directory will be autocreated
  --ask       Provoke a prompt for all params
  
  DEMO:
  ====
  # Generate with all defaults to PK file ~/.ssh/serv.com/user
  ssh-gen.sh user serv.com
  
  # Generate to ~/.ssh/_.serv.com/bar instead of ~/.ssh/10.0.0.69/foo
  SG_DIRNAME='_.serv.com' SG_HOST='serv.com *.serv.com' \
    ssh-gen.sh --filename='bar' --comment Zoo -- foo 10.0.0.69
  
  # Generate interactively to ~/my/certs/foo (will be prompted for params)
  ssh-gen.sh --ask --dest-dir ~/my/certs/foo
  ~~~
  
</details>  
<a id="short/compile-bash-project.sh"></a>
<details><summary>short/compile-bash-project.sh</summary>
  
  **AD HOC:**
  ~~~sh
  # Review and change input params
  bash <(
    # Can be changed to tag or commit ID
    VERSION="master"
    curl -V &>/dev/null && dl_tool=(curl -sL) || dl_tool=(wget -qO-)
    set -x; "${dl_tool[@]}" "https://raw.githubusercontent.com/spaghetti-coder/linux-helper/${VERSION}/dist/short/compile-bash-project.sh" \
    || "${dl_tool[@]}" "https://bitbucket.org/kvedenskii/linux-scripts/raw/${VERSION}/dist/short/compile-bash-project.sh"
  ) \
    [--ext EXT='.sh'...] [--no-ext EXT=''...] [--] \
    SRC_DIR DEST_DIR
  ~~~
  
  
  **MAN:**
  ~~~
  Shortcut for compile-bash-file.sh.
  
  IMPORTANT: DEST_DIR gets deleted in the beginning of processing.
  
  Compile bash project. Processing:
  * Compile each file under SRC_DIR to same path of DEST_DIR
  * Replace '# .LH_SOURCE:path/to/lib.sh' comment lines with content of the
    pointed libs, while path to the lib is relative to SRC_DIR directory
  * Everything after '# .LH_NOSOURCE' comment in the sourced files is
    ignored for sourcing
  * Sourced code is embraced with comment
  * Shebang from the sourced files are removed in the resulting file
  
  USAGE:
  =====
  compile-bash-project.sh [--ext EXT='.sh'...] [--no-ext EXT=''...] [--] \
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
  compile-bash-project.sh ./src ./dest --ext '.sh' --ext='.bash' \
    --no-ext '.hidden.sh' --no-ext='.secret.sh'
  ~~~
  
</details>  
<a id="short/ssh-gen-github.sh"></a>
<details><summary>short/ssh-gen-github.sh</summary>
  
  **AD HOC:**
  ~~~sh
  # Review and change input params
  bash <(
    # Can be changed to tag or commit ID
    VERSION="master"
    curl -V &>/dev/null && dl_tool=(curl -sL) || dl_tool=(wget -qO-)
    set -x; "${dl_tool[@]}" "https://raw.githubusercontent.com/spaghetti-coder/linux-helper/${VERSION}/dist/short/ssh-gen-github.sh" \
    || "${dl_tool[@]}" "https://bitbucket.org/kvedenskii/linux-scripts/raw/${VERSION}/dist/short/ssh-gen-github.sh"
  ) \
    [--host HOST='github.com'] \
    [--comment COMMENT="$(id -un)@$(hostname -f)"] [--] [ACCOUNT='git']
  ~~~
  
  
  **MAN:**
  ~~~
  Generate private and public key pair and configure ~/.ssh/config file to
  use them. It is a github centric shortcut of ssh-gen.sh tool.
  
  USAGE:
  =====
  ssh-gen-github.sh [--host HOST='github.com'] \
    [--comment COMMENT="$(id -un)@$(hostname -f)"] [--] [ACCOUNT='git']
  
  PARAMS (=DEFAULT_VALUE):
  ======
  ACCOUNT   Github account, only used to form cert filename
  --        End of options
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
    set -x; "${dl_tool[@]}" "https://raw.githubusercontent.com/spaghetti-coder/linux-helper/${VERSION}/dist/config/tmux/default.sh" \
    || "${dl_tool[@]}" "https://bitbucket.org/kvedenskii/linux-scripts/raw/${VERSION}/dist/config/tmux/default.sh"
  ) [TMUX_CONFD="${HOME}/.tmux"]
  ~~~

  Install tmux plugins configurations (requires git and tmux installed):

  ~~~sh
  # plugins.conf
  bash <(
    # Can be changed to tag or commit ID
    VERSION="master"
    curl -V &>/dev/null && dl_tool=(curl -sfL) || dl_tool=(wget -qO-)
    set -x; "${dl_tool[@]}" "https://raw.githubusercontent.com/spaghetti-coder/linux-helper/${VERSION}/dist/config/tmux/plugins.sh" \
    || "${dl_tool[@]}" "https://bitbucket.org/kvedenskii/linux-scripts/raw/${VERSION}/dist/config/tmux/plugins.sh"
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
