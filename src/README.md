# Linux helper

* [Tools](#tools)
* [Libraries](#libraries)
* [Development](#development)

## Tools

<details><summary>bin/ssh-gen.sh</summary>
  <!-- .LH_ADHOC:bin/ssh-gen.sh -->
  <!-- .LH_HELP:bin/ssh-gen.sh -->
</details>  
<details><summary>bin/compile-bash-file.sh</summary>
  <!-- .LH_ADHOC:bin/compile-bash-file.sh -->
  <!-- .LH_HELP:bin/compile-bash-file.sh -->
</details>  
<details><summary>short/compile-bash-project.sh</summary>
  <!-- .LH_ADHOC:short/compile-bash-project.sh -->
  <!-- .LH_HELP:short/compile-bash-project.sh -->
</details>  
<details><summary>short/ssh-gen-github.sh</summary>
  <!-- .LH_ADHOC:short/ssh-gen-github.sh -->
  <!-- .LH_HELP:short/ssh-gen-github.sh -->
</details>  

## Libraries

TODO

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
