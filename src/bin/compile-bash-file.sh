#!/usr/bin/env bash

# shellcheck disable=SC2317
compile_bash_file() (
  { # Service vars
    declare -r SELF="${FUNCNAME[0]}"

    # If not a file, default to demo.sh script name
    declare THE_SCRIPT=demo.sh
    grep -q -m 1 -- '.' "${0}" 2>/dev/null && THE_SCRIPT="$(basename -- "${0}")"
  }

  print_usage() { echo "
    ${THE_SCRIPT} [--] SRC_FILE DEST_FILE LIBS_PATH
  "; }

  print_help() { text_nice "
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
    $(print_usage)
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
  "; }

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
        --usage       ) print_usage | text_nice; exit ;;
        -*            ) lh_params_unsupported "${1}" ;;
        *             ) args+=("${1}") ;;
      esac

      shift
    done

    [[ ${#args[@]} -gt 0 ]] && lh_params set SRC_FILE "${args[0]}"
    [[ ${#args[@]} -gt 1 ]] && lh_params set DEST_FILE "${args[1]}"
    [[ ${#args[@]} -gt 2 ]] && lh_params set LIBS_PATH "$(sed -e 's/\/*$//' <<< "${args[2]}")"
    [[ ${#args[@]} -lt 4 ]] || lh_params unsupported "${args[@]:3}"
  }

  check_params() {
    lh_params get SRC_FILE >/dev/null   || lh_params noval SRC_FILE
    lh_params get DEST_FILE >/dev/null  || lh_params noval DEST_FILE
    lh_params get LIBS_PATH >/dev/null  || lh_params noval LIBS_PATH

    lh_params is-blank SRC_FILE   && lh_params errbag "SRC_FILE can't be blank"
    lh_params is-blank DEST_FILE  && lh_params errbag "DEST_FILE can't be blank"
    lh_params is-blank LIBS_PATH  && lh_params errbag "LIBS_PATH can't be blank"
  }

  replace_cbk() {
    declare libs_path; libs_path="$(lh_params get LIBS_PATH)"
    declare inc_file="${libs_path}/${1}"

    # The lib is already included
    printf -- '%s\n' "${INCLUDED_LIBS[@]}" \
    | grep -qFx -- "${inc_file}" && return

    INCLUDED_LIBS+=("${inc_file}")
    echo "# INC:${inc_file}" >&2

    declare file_path
    file_path="$(realpath --relative-to "${libs_path}" -m -- "${inc_file}")"

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
    check_params

    lh_params invalids >&2 && {
      echo "FATAL (${SELF})" >&2
      return 1
    }

    declare content; content="$( set -o pipefail
      cat -- "$(lh_params get SRC_FILE)" \
      | replace_marker '.LH_SOURCE:' replace_cbk '#' \
      | LH_NO_WRAP=true replace_marker '.LH_SOURCE_NW:' replace_cbk '#' \
      | LH_NO_WRAP=true replace_marker '.LH_SOURCE_NO_WRAP:' replace_cbk '#'
    )" || return $?

    declare src_file; src_file="$(lh_params get SRC_FILE)"
    declare dest_file; dest_file="$(lh_params get DEST_FILE)"
    declare dest_dir; dest_dir="$(dirname -- "$(lh_params get DEST_FILE)")"

    (set -x; mkdir -p -- "${dest_dir}") \
    && {
      if [[ ! -e "$(lh_params get DEST_FILE)" ]] || [[ -f "$(lh_params get DEST_FILE)" ]]; then
        # Copy the original file to ensure same file attributes.
        # Copy only when there is no LH_PARAMS[DEST_FILE] or it is a regular file
        (set -x; cp -- "${src_file}" "${dest_file}")
      fi
    } \
    && (
      set -x; cat <<< "${content}" > "${dest_file}"
    ) \
    || return $?
  }

  main "${@}"
)

# .LH_SOURCE:lib/lh-params.sh
# .LH_SOURCE:lib/text.sh
# .LH_SOURCE:partial/replace-marker.sh

# .LH_NOSOURCE

(return &>/dev/null) || {
  compile_bash_file "${@}"
}
