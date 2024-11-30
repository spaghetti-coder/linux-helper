#!/usr/bin/env bash
# .LH_SOURCED: {{ lib/text.sh }}
# shellcheck disable=SC2001
# shellcheck disable=SC2120
text_ltrim() { sed -e 's/^\s\+//' <<< "${1-$(cat)}"; }
text_rtrim() { sed -e 's/\s\+$//' <<< "${1-$(cat)}"; }
text_trim() { text_ltrim <<< "${1-$(cat)}" | text_rtrim; }
text_rmblank() { grep -v '^\s*$' <<< "${1-$(cat)}"; return 0; }
text_nice() { text_trim <<< "${1-$(cat)}" | text_rmblank | sed -e 's/^,//'; }
# .LH_SOURCED: {{/ lib/text.sh }}
# .LH_SOURCED: {{ partial/replace-marker.sh }}
# .LH_SOURCED: {{ lib/basic.sh }}
# https://stackoverflow.com/a/2705678
escape_sed_expr()  { sed -e 's/[]\/$*.^[]/\\&/g' <<< "${1-$(cat)}"; }
escape_sed_repl()  { sed -e 's/[\/&]/\\&/g' <<< "${1-$(cat)}"; }
# .LH_SOURCED: {{/ lib/basic.sh }}

# cat FILE | get_marker_lines MARKER REPLACE_CBK [COMMENT_PREFIX] [COMMENT_SUFFIX]
replace_marker() {
  declare marker="${1}" \
          replace_cbk="${2}" \
          prefix \
          suffix
  declare content; content="$(cat)"

  [[ ${#} -gt 2 ]] && prefix="${3}"
  [[ ${#} -gt 3 ]] && suffix="${4}"

  declare marker_rex; marker_rex="$(escape_sed_expr "${marker}")"
  declare prefix_rex; prefix_rex="$(escape_sed_expr "${prefix}")"
  declare suffix_rex; suffix_rex="$(escape_sed_expr "${suffix}")"

  declare rex; rex="$(
    printf -- '\(\s*\)%s\s*%s\(.*\)%s\s*' \
      "${prefix_rex}" "${marker_rex}" "${suffix_rex}"
  )"

  declare line \
          number \
          offset \
          REPLACEMENT \
          arg
  while line="$(
    set -o pipefail
    grep -n -m 1 -- "^${rex}\$" <<< "${content}" \
    | sed -e 's/^\([0-9]\+:\)'"${rex}"'$/\1\2\3/' | text_rtrim
  )"; do
    # Explicitely remove REPLACEMENT VALUE
    REPLACEMENT=''

    number="${line%%:*}"
    line="${line#*:}"
    offset="$(grep -o '^\s*' <<< "${line}")"
    arg="$(text_ltrim "${line}")"

    "${replace_cbk}" "${arg}" || continue
    if [[ -n "${REPLACEMENT}" ]]; then
      # shellcheck disable=SC2001
      REPLACEMENT="$(sed -e 's/^/'"${offset}"'/' <<< "${REPLACEMENT}")"$'\n'
    fi

    content="$(
      printf -- '%s\n%s%s\n' \
        "$(head -n $((number - 1)) <<< "${content}")" \
        "${REPLACEMENT}" \
        "$(tail -n +$((number + 1)) <<< "${content}")"
    )"
  done

  printf -- '%s\n' "${content}"
}

# .LH_SOURCED: {{/ partial/replace-marker.sh }}

# shellcheck disable=SC2317
compile_bash_file() (
  declare SELF="${FUNCNAME[0]}"

  declare SRC_FILE
  declare DEST_FILE
  declare LIBS_PATH

  declare -a ERRBAG

  print_help_usage() {
    echo "${THE_SCRIPT} [--] SRC_FILE DEST_FILE LIBS_PATH"
  }

  print_help() {
    # If not a file, default to ssh-gen.sh script name
    declare THE_SCRIPT=compile-bash-file.sh
    grep -q -m 1 -- '.' "${0}" 2>/dev/null && THE_SCRIPT="$(basename -- "${0}")"

    if declare -F "print_help_${1,,}" &>/dev/null; then
      print_help_usage | text_nice
      exit
    fi

    text_nice "
      Compile bash script. Processing:
      * Replace '# .LH_SOURCE:path/to/lib.sh' comment lines with content of the
     ,  pointed libs, while path to the lib is relative to LIBS_PATH directory
      * Everything after '# .LH_NOSOURCE' comment in the sourced files is
     ,  ignored for sourcing
      * Sourced code is embraced with comment
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

    declare endopts=false
    declare param
    while [[ ${#} -gt 0 ]]; do
      ${endopts} && param='*' || param="${1}"

      case "${param}" in
        --            ) endopts=true ;;
        -\?|-h|--help ) print_help "${@:2}"; exit ;;
        *             ) args+=("${1}") ;;
      esac

      shift
    done

    [[ ${#args[@]} -gt 0 ]] && SRC_FILE="${args[0]}"
    [[ ${#args[@]} -gt 1 ]] && DEST_FILE="${args[1]}"
    [[ ${#args[@]} -gt 2 ]] && LIBS_PATH="${args[2]}"
    [[ ${#args[@]} -lt 4 ]] || {
      ERRBAG+=(
        "Unsupported params:"
        "$(printf -- '* %s\n' "${args[@]:3}")"
      )

      return 1
    }
  }

  validate_required_args() {
    declare rc=0
    [[ -n "${SRC_FILE}" ]] || { rc=1; ERRBAG+=("SRC_FILE is required"); }
    [[ -n "${DEST_FILE}" ]] || { rc=1; ERRBAG+=("DEST_FILE is required"); }
    [[ -n "${LIBS_PATH}" ]] || { rc=1; ERRBAG+=("LIBS_PATH is required"); }
    return "${rc}"
  }

  flush_errbag() {
    echo "FATAL (${SELF})"
    printf -- '%s\n' "${ERRBAG[@]}"
  }

  replace_callback() {
    declare inc_file="${LIBS_PATH}/${1}"

    # The lib is already included
    printf -- '%s\n' "${INCLUDED_LIBS[@]}" \
    | grep -qFx -- "${inc_file}" && return

    INCLUDED_LIBS+=("${inc_file}")
    printf -- '# INC:%s\n' "${inc_file}" >&2

    declare file_path
    file_path="$(realpath --relative-to "${LIBS_PATH}" -m -- "${inc_file}")"

    # shellcheck disable=SC2034
    REPLACEMENT="$(
      # * Remove shebang
      # * Remove empty lines in the beginning of the file
      # * Up until stop-pattern
      # * Apply offset
      sed -e '1{/^#!/d}' -- "${inc_file}" \
      | sed -e '/./,$!d' | sed -e '/./,$!d' \
      | sed '/^#\s*\.LH_NOSOURCE\s*/Q' | {
        echo "# .LH_SOURCED: {{ ${file_path} }}"
        cat
        echo "# .LH_SOURCED: {{/ ${file_path} }}"
      }
    )"
  }

  main() {
    # shellcheck disable=SC2015
    parse_params "${@}" \
    && validate_required_args \
    || { flush_errbag; return 1; }

    declare dest_dir; dest_dir="$(dirname -- "${DEST_FILE}")"
    declare content; content="$( set -o pipefail
      cat -- "${SRC_FILE}" \
      | replace_marker '.LH_SOURCE:' replace_callback '#'
    )" || return $?

    (set -x; mkdir -p -- "${dest_dir}") \
    && {
      if [[ ! -e "${DEST_FILE}" ]] || [[ -f "${DEST_FILE}" ]]; then
        # Copy the original fail to ensure same file attributes.
        # Copy only when there is no DEST_FILE or it is a regular file
        (set -x; cp -- "${SRC_FILE}" "${DEST_FILE}")
      fi
    } \
    && (set -x; cat <<< "${content}" > "${DEST_FILE}") \
    || return $?
  }

  main "${@}"
)

# .LH_NOSOURCE

(return &>/dev/null) || {
  compile_bash_file "${@}"
}
