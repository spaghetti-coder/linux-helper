<a id="top"></a>

# Linux helper

* [Tools](#tools)
* [Config](#config)
* [Libraries](#libraries)
* [Development](#development)

## Tools

<a id="bin/compile-bash-file.sh"></a>
<details><summary>bin/compile-bash-file.sh</summary>
  <!-- .LH_ADHOC_USAGE:bin/compile-bash-file.sh -->
  <!-- .LH_HELP:bin/compile-bash-file.sh -->
</details>  
<a id="bin/ssh-gen.sh"></a>
<details><summary>bin/ssh-gen.sh</summary>
  <!-- .LH_ADHOC_USAGE:bin/ssh-gen.sh -->
  <!-- .LH_HELP:bin/ssh-gen.sh -->
</details>  
<a id="short/compile-bash-project.sh"></a>
<details><summary>short/compile-bash-project.sh</summary>
  <!-- .LH_ADHOC_USAGE:short/compile-bash-project.sh -->
  <!-- .LH_HELP:short/compile-bash-project.sh -->
</details>  
<a id="short/ssh-gen-github.sh"></a>
<details><summary>short/ssh-gen-github.sh</summary>
  <!-- .LH_ADHOC_USAGE:short/ssh-gen-github.sh -->
  <!-- .LH_HELP:short/ssh-gen-github.sh -->
</details>  

[To top]

## Config

<a id="config/tmux/tmux-default.sh"></a>
<details><summary>config/tmux/tmux-default.sh</summary>
  <!-- .LH_ADHOC_USAGE:config/tmux/tmux-default.sh -->
  <!-- .LH_HELP:config/tmux/tmux-default.sh -->
</details>

<a id="config/tmux/tmux-plugins.sh"></a>
<details><summary>config/tmux/tmux-plugins.sh</summary>
  <!-- .LH_ADHOC_USAGE:config/tmux/tmux-plugins.sh -->
  <!-- .LH_HELP:config/tmux/tmux-plugins.sh -->
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

* `short/compile-bash-project.sh src dest --no-ext '.ignore.sh'`
* custom `*.md` files compilation
  * TODO: describe

[To top]

[To top]: #top
