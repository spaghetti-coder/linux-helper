#!/usr/bin/env bash

# shellcheck disable=SC2317
compile_bash_file() (
  declare SELF="${FUNCNAME[0]}"

  # If not a file, default to ssh-gen.sh script name
  declare THE_SCRIPT=compile-bash-file.sh
  grep -q -m 1 -- '.' "${0}" 2>/dev/null && THE_SCRIPT="$(basename -- "${0}")"

  declare LIBS_PATH

  print_help_usage() {
    echo "${THE_SCRIPT} [--] SRC_FILE DEST_FILE LIBS_PATH"
  }

  print_help() {
    text_nice "
      Compile bash script. Processing:
      * Replace '# .LH_SOURCE:path/to/lib.sh' comment lines with content of the
     ,  pointed libs, while path to the lib is relative to LIBS_PATH directory
      * Everything after '# .LH_NOSOURCE' comment in the sourced files is ignored
     ,  for sourcing
      * Sourced code is wrapped with comment. To avoid wrapping use
     ,  '# .LH_SOURCE_NW:path/to/lib.sh' comment
      * Shebang from the sourced files are removed in the resulting file
     ,
      USAGE:
      =====
      $(print_help_usage)
     ,
      PARAMS:
      ======
      SRC_FILE    Source file
      DEST_FILE   Compilation destination file
      LIBS_PATH   Directory with libraries
      --          End of options
     ,
      DEMO:
      ====
      # Review the demo project
      cat ./src/lib/world.sh; echo '+++++'; \\
      cat ./src/lib/hello.sh; echo '+++++'; \\
      cat ./src/bin/script.sh
      \`\`\`OUTPUT:
      #!/usr/bin/env bash
      print_world() { echo \"world\"; }
      # .LH_NOSOURCE
      print_world
      +++++
      #!/usr/bin/env bash
     ,# .LH_SOURCE:lib/world.sh
      print_hello_world() { echo \"Hello \$(print_world)\"; }
      +++++
      #!/usr/bin/env bash
     ,# .LH_SOURCE:lib/hello.sh
      print_hello_world
      \`\`\`
     ,
      # Compile to stdout
      ${THE_SCRIPT} ./src/bin/script.sh /dev/stdout ./src
      \`\`\`OUTPUT (stderr ignored):
      #!/usr/bin/env bash
     ,# .LH_SOURCED: {{ lib/hello.sh }}
     ,# .LH_SOURCED: {{ lib/world.sh }}
      print_world() { echo \"world\"; }
     ,# .LH_SOURCED: {{/ lib/world.sh }}
      print_hello_world() { echo \"Hello \$(print_world)\"; }
     ,# .LH_SOURCED: {{/ lib/hello.sh }}
      print_hello_world
      \`\`\`
    "
  }

  parse_params() {
    declare -a args

    lh_params_reset

    declare endopts=false
    declare param
    while [[ ${#} -gt 0 ]]; do
      ${endopts} && param='*' || param="${1}"

      case "${param}" in
        --            ) endopts=true ;;
        -\?|-h|--help ) print_help; exit ;;
        --usage       ) print_help_usage | text_nice; exit ;;
        -*            ) lh_params_unsupported "${1}" ;;
        *             ) args+=("${1}") ;;
      esac

      shift
    done

    [[ ${#args[@]} -gt 0 ]] && lh_param_set SRC_FILE "${args[0]}"
    [[ ${#args[@]} -gt 1 ]] && lh_param_set DEST_FILE "${args[1]}"
    [[ ${#args[@]} -gt 2 ]] && lh_param_set LIBS_PATH "$(sed -e 's/\/*$//' <<< "${args[2]}")"
    [[ ${#args[@]} -lt 4 ]] || lh_params_unsupported "${args[@]:3}"
  }

  check_required_params() {
    [[ -n "${LH_PARAMS[SRC_FILE]}" ]]   || lh_params_noval SRC_FILE
    [[ -n "${LH_PARAMS[DEST_FILE]}" ]]  || lh_params_noval DEST_FILE
    [[ -n "${LH_PARAMS[LIBS_PATH]}" ]]  || lh_params_noval LIBS_PATH
  }

  replace_callback() {
    declare inc_file="${LH_PARAMS[LIBS_PATH]}/${1}"

    # The lib is already included
    printf -- '%s\n' "${INCLUDED_LIBS[@]}" \
    | grep -qFx -- "${inc_file}" && return

    INCLUDED_LIBS+=("${inc_file}")
    echo "# INC:${inc_file}" >&2

    declare file_path
    file_path="$(realpath --relative-to "${LH_PARAMS[LIBS_PATH]}" -m -- "${inc_file}")"

    # shellcheck disable=SC2034
    REPLACEMENT="$(
      set -o pipefail

      # * Remove shebang
      # * Remove empty lines in the beginning of the file
      # * Up until stop-pattern
      # * Apply offset
      sed -e '1{/^#!/d}' -- "${inc_file}" \
      | sed -e '/./,$!d' | sed -e '/./,$!d' \
      | sed '/^#\s*\.LH_NOSOURCE\s*/Q' | {
        ${LH_NO_WRAP:-false} || echo "# .LH_SOURCED: {{ ${file_path} }}"
        cat
        ${LH_NO_WRAP:-false} || echo "# .LH_SOURCED: {{/ ${file_path} }}"
      }
    )"
  }

  main() {
    # shellcheck disable=SC2015
    parse_params "${@}"
    check_required_params

    lh_params_flush_invalid >&2 && {
      echo "FATAL (${SELF})" >&2
      return 1
    }

    declare dest_dir; dest_dir="$(dirname -- "${LH_PARAMS[DEST_FILE]}")"
    declare content; content="$( set -o pipefail
      cat -- "${LH_PARAMS[SRC_FILE]}" \
      | replace_marker '.LH_SOURCE:' replace_callback '#' \
      | LH_NO_WRAP=true replace_marker '.LH_SOURCE_NW:' replace_callback '#' \
      | LH_NO_WRAP=true replace_marker '.LH_SOURCE_NO_WRAP:' replace_callback '#'
    )" || return $?

    (set -x; mkdir -p -- "${dest_dir}") \
    && {
      if [[ ! -e "${LH_PARAMS[DEST_FILE]}" ]] || [[ -f "${LH_PARAMS[DEST_FILE]}" ]]; then
        # Copy the original fail to ensure same file attributes.
        # Copy only when there is no LH_PARAMS[DEST_FILE] or it is a regular file
        (set -x; cp -- "${LH_PARAMS[SRC_FILE]}" "${LH_PARAMS[DEST_FILE]}")
      fi
    } \
    && (set -x; cat <<< "${content}" > "${LH_PARAMS[DEST_FILE]}") \
    || return $?
  }

  main "${@}"
)

# .LH_SOURCE:lib/text.sh
# .LH_SOURCE:partial/replace-marker.sh
# .LH_SOURCE:base.ignore.sh

# .LH_NOSOURCE

(return &>/dev/null) || {
  compile_bash_file "${@}"
}
