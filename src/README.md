<a id="top"></a>

# Linux helper

* [Tools](#tools)
* [Config](#config)
* [Libraries](#libraries)
* [Development](#development)

## Tools

<!-- .LH_DETAILS:bin/compile-bash-file.sh -->
<!-- .LH_DETAILS:bin/ssh-gen.sh -->
<!-- .LH_DETAILS:short/compile-bash-project.sh -->
<!-- .LH_DETAILS:short/ssh-gen-github.sh -->

[To top]

## Config

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
