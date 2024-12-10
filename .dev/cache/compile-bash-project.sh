#!/usr/bin/env bash

# shellcheck disable=SC2317
compile_bash_project() (
  { # Service vars
    declare SELF="${FUNCNAME[0]}"

    # If not a file, default to ssh-gen.sh script name
    declare THE_SCRIPT=compile-bash-project.sh
    grep -q -m 1 -- '.' "${0}" 2>/dev/null && THE_SCRIPT="$(basename -- "${0}")"
  }

  declare DEFAULT_EXT='.sh'
  declare -a EXTS
  declare -a NO_EXTS

  declare -a SRC_FILES

  init() {
    # Ensure clean environment
    lh_params reset
  }

  print_usage() { echo "
    ${THE_SCRIPT} [--ext EXT='${DEFAULT_EXT}']... [--no-ext NO_EXT]... [--] \\
   ,  SRC_DIR DEST_DIR
  "; }

  print_help() { text_nice "
    Shortcut for compile-bash-file.sh to compile complete bash project. Processing:
    * Compile each file under SRC_DIR to same path of DEST_DIR
    * Replace '# .LH_SOURCE:path/to/lib.sh' comment lines with content of the
   ,  pointed libs, while path to the lib is relative to SRC_DIR directory
    * Everything after '# .LH_NOSOURCE' comment in the sourced files is ignored
   ,  for sourcing
    * Sourced code is wrapped with comment. To avoid wrapping use comment
   ,  '# .LH_SOURCE_NW:path/to/lib.sh' or '# .LH_SOURCE_NOW_WRAP:path/to/lib.sh'
    * Shebang from the sourced files are removed in the resulting file
   ,
    USAGE:
    =====
    $(print_usage)
   ,
    PARAMS:
    ======
    SRC_DIR     Source directory
    DEST_DIR    Compilation destination directory
    --          End of options
    --ext       Array of extension patterns of files to be compiled
    --no-ext    Array of exclude extension patterns
   ,
    DEMO:
    ====
    # Compile all '.sh' and '.bash' files under 'src' directory to 'dest'
    # excluding files with '.hidden.sh' and '.secret.sh' extensions
    ${THE_SCRIPT} ./src ./dest --ext '.sh' --ext '.bash' \\
   ,  --no-ext '.hidden.sh' --no-ext '.secret.sh'
  "; }

  parse_params() {
    declare -a args

    declare endopts=false
    declare param
    while [[ ${#} -gt 0 ]]; do
      ${endopts} && param='*' || param="${1}"

      # shellcheck disable=SC2015
      case "${param}" in
        --            ) endopts=true ;;
        -\?|-h|--help ) print_help; exit ;;
        --usage       ) print_usage | text_nice; exit ;;
        --ext         ) [[ -n "${2+x}" ]] && { EXTS+=("${2}"); shift; } || lh_params noval EXT ;;
        --no-ext      ) [[ -n "${2+x}" ]] && { NO_EXTS+=("${2}"); shift; } || lh_params noval NO_EXT ;;
        -*            ) lh_params unsupported "${1}" ;;
        *             ) args+=("${1}") ;;
      esac

      shift
    done

    [[ ${#args[@]} -gt 0 ]] && lh_params set SRC_DIR "$(sed -e 's/\/*$//' <<< "${args[0]}")"
    [[ ${#args[@]} -gt 1 ]] && lh_params set DEST_DIR "$(sed -e 's/\/*$//' <<< "${args[1]}")"
    [[ ${#args[@]} -lt 3 ]] || lh_params unsupported "${args[@]:2}"
  }

  check_params() {
    lh_params get SRC_DIR >/dev/null  || lh_params noval SRC_DIR
    lh_params get DEST_DIR >/dev/null || lh_params noval DEST_DIR

    lh_params is-blank SRC_DIR >/dev/null   && lh_params errbag "SRC_DIR can't be blank"
    lh_params is-blank DEST_DIR >/dev/null  && lh_params errbag "DEST_DIR can't be blank"
  }

  apply_defaults() {
    [[ ${#EXTS[@]} -gt 0 ]] || EXTS=("${DEFAULT_EXT}")
  }

  populate_src_files() {
    declare ext_ptn
    declare no_ext_ptn

    declare ext; for ext in "${EXTS[@]}"; do
      ext_ptn+=${ext_ptn:+$'\n'}".*$(escape_sed_expr "${ext}")\$"
    done

    declare ext; for ext in "${NO_EXTS[@]}"; do
      no_ext_ptn+=${no_ext_ptn:+$'\n'}".*$(escape_sed_expr "${ext}")\$"
    done

    declare src_files; src_files="$(find -- "$(lh_params get SRC_DIR)")" || return $?
    src_files="$(sort -n <<< "${src_files}" | grep -if <(cat <<< "${ext_ptn}"))" || return 0
    if [[ -n "${no_ext_ptn+x}" ]]; then
      src_files="$(grep -ivf <(cat <<< "${no_ext_ptn}") <<< "${src_files}" | grep '')" || return 0
    fi

    mapfile -t SRC_FILES <<< "${src_files}"
  }

  main() {
    init
    parse_params "${@}"
    check_params

    lh_params invalids >&2 && {
      echo "FATAL (${SELF})" >&2
      return 1
    }

    apply_defaults
    populate_src_files || return $?

    [[ ${#SRC_FILES[@]} -gt 0 ]] || {
      echo "# ===== ${SELF}: nothing to compile" >&2
      return
    }

    declare src_dir; src_dir="$(lh_params get SRC_DIR)"
    declare dest_dir; dest_dir="$(lh_params get DEST_DIR)"

    echo "# ===== ${SELF}: compiling ${src_dir} => ${dest_dir}" >&2

    declare suffix
    declare dest
    declare rc=0
    declare src; for src in "${SRC_FILES[@]}"; do
      suffix="$(realpath -m --relative-to "${src_dir}" -- "${src}")" || {
        rc=1
        continue
      }

      dest="${dest_dir}/${suffix}"
      printf -- '# COMPILING: %s => %s\n' "${src}" "${dest}"
      (
        set -o pipefail
        (
          compile_bash_file -- "${src}" "${dest}" "${src_dir}" 3>&2 2>&1 1>&3
        ) | sed -e 's/^/  /'
      ) 3>&2 2>&1 1>&3 && {
        printf -- '# OK: %s\n' "${src}"
      } || {
        printf -- '# KO: %s\n' "${src}"
        rc=1
      }
    done

    if [[ ${rc} -gt 0 ]]; then
      echo "# ===== ${SELF} KO: some errors in compilation." >&2
    else
      echo "# ===== ${SELF} OK" >&2
    fi

    return "${rc}"
  }

  main "${@}"
)
# .LH_SOURCED: {{ bin/compile-bash-file.sh }}
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
# .LH_SOURCED: {{ lib/lh-params.sh }}
lh_params() { lh_params_"${1//-/_}" "${@:2}"; }

lh_params_reset() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  declare vname vtype
  for vname in "${!_lh_params_map[@]}"; do
    unset "${vname}"
    declare -"${vtype}"g "${vname}"
  done
}

lh_params_set() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  [[ -n "${2+x}" ]] || { lh_params_noval "${1}"; return 1; }
  # shellcheck disable=SC2034
  LH_PARAMS["${1}"]="${2}"
}

# lh_params_get NAME [DEFAULT]
#
# # Try to get $LH_PARAMS[NAME], fall back to invokation of lh_params_default_NAME,
# # then fallback to $LH_PARAMS_DEFAULTS[NAME] and if doesn't exist RC 1
# lh_params_get NAME
#
# # Try to get $LH_PARAMS[NAME], fall back to DEFAULT_VAL
# lh_params_get NAME DEFAULT_VAL
lh_params_get() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  [[ -n "${LH_PARAMS[${1}]+x}" ]] && { cat <<< "${LH_PARAMS[${1}]}"; return; }
  [[ -n "${2+x}" ]] && { cat <<< "${2}"; return; }
  declare -F "lh_params_default_${1}" &>/dev/null && { "lh_params_default_${1}"; return; }
  [[ -n "${LH_PARAMS_DEFAULTS[${1}]+x}" ]] && { cat <<< "${LH_PARAMS_DEFAULTS[${1}]}"; return; }
  return 1
}

lh_params_is_blank() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  [[ -n "${LH_PARAMS[${1}]+x}" ]] && [[ -z "${LH_PARAMS[${1}]:+x}" ]]
}

lh_params_noval() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  # https://stackoverflow.com/a/13216833
  declare -a issues=("${@/%/ requires a value}")
  lh_params_errbag "${issues[@]}"
}

lh_params_unsupported() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  # https://stackoverflow.com/a/13216833
  declare -a issues=("${@/%/\' param is unsupported}")
  lh_params_errbag "${issues[@]/#/\'}"
}

lh_params_errbag() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  LH_PARAMS_ERRBAG+=("${@}")
}

# lh_params_defaults PARAM_NAME1='DEFAULT_VAL'...
lh_params_defaults() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  declare kv pname pval
  for kv in "${@}"; do
    kv="${kv}="
    pname="${kv%%=*}"
    pval="${kv#*=}"; pval="${pval::-1}"
    LH_PARAMS_DEFAULTS["${pname}"]="${pval}"
  done
}

lh_params_default_string() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }
  cat <<< "${LH_PARAMS_DEFAULTS[${1}]}"
}

lh_params_ask_config() {
  [[ "${FUNCNAME[1]}" != _lh_params_init ]] && { _lh_params_init "${@}"; return $?; }

  declare pname ptext prev_comma=false
  for ptext in "${@}"; do
    [[ "${ptext}" == ',' ]] && { prev_comma=true; continue; }

    ${prev_comma} || [[ -z "${pname}" ]] && {
      pname="${ptext}"
      LH_PARAMS_ASK_PARAMS+=("${pname}")
      prev_comma=false
      continue
    }

    LH_PARAMS_ASK["${pname}"]+="${LH_PARAMS_ASK["${pname}"]+$'\n'}${ptext}"
  done
}

lh_params_ask() {
  declare confirm pname ptext

  [[ -n "${LH_PARAMS_ASK_EXCLUDE+x}" ]] && {
    LH_PARAMS_ASK_EXCLUDE="$(
      # shellcheck disable=SC2001
      sed -e 's/^\s*//' -e 's/\s*$//' <<< "${LH_PARAMS_ASK_EXCLUDE}" \
      | grep -v '^$'
    )"
  }

  while ! [[ "${confirm:-n}" == y ]]; do
    confirm=""

    for pname in "${LH_PARAMS_ASK_PARAMS[@]}"; do
      # Don't prompt for params in LH_PARAMS_ASK_EXCLUDE (text) list
      grep -qFx -- "${pname}" <<< "${LH_PARAMS_ASK_EXCLUDE}" && continue

      read  -erp "${LH_PARAMS_ASK[${pname}]}" \
            -i "$(lh_params_get "${pname}")" "LH_PARAMS[${pname}]"
    done

    echo '============================' >&2

    while [[ ! " y n " == *" ${confirm} "* ]]; do
      read -rp "YES (y) for proceeding or NO (n) to repeat: " confirm
      [[ "${confirm,,}" =~ ^(y|yes)$ ]] && confirm=y
      [[ "${confirm,,}" =~ ^(n|no)$ ]] && confirm=n
    done
  done
}

lh_params_invalids() {
  declare -i rc=1

  [[ ${#LH_PARAMS_ERRBAG[@]} -lt 1 ]] || {
    echo "Issues:"
    printf -- '* %s\n' "${LH_PARAMS_ERRBAG[@]}"
    rc=0
  }

  return ${rc}
}

_lh_params_init() {
  declare -A _lh_params_map=(
    [LH_PARAMS]=A
    [LH_PARAMS_DEFAULTS]=A
    [LH_PARAMS_ASK]=A
    [LH_PARAMS_ASK_PARAMS]=a
    [LH_PARAMS_ERRBAG]=a
  )

  # Ensure global variables
  declare vname vtype
  for vname in "${!_lh_params_map[@]}"; do
    vtype="${_lh_params_map[${vname}]}"
    [[ "$(declare -p "${vname}" 2>/dev/null)" == "declare -${vtype}"* ]] && continue

    unset "${vname}"
    declare -"${vtype}"g "${vname}"
  done

  [[ "${FUNCNAME[1]}" != lh_params_* ]] || {
    unset vname vtype
    "${FUNCNAME[1]}" "${@}"
  }
}
# .LH_SOURCED: {{/ lib/lh-params.sh }}
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

  declare -i RC=0

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

    "${replace_cbk}" "${arg}" || { RC=1; continue; }
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
  return ${RC}
}
# .LH_SOURCED: {{ lib/basic.sh }}
# https://stackoverflow.com/a/2705678
escape_sed_expr()  { sed -e 's/[]\/$*.^[]/\\&/g' <<< "${1-$(cat)}"; }
escape_sed_repl()  { sed -e 's/[\/&]/\\&/g' <<< "${1-$(cat)}"; }

escape_single_quotes()  { declare str="${1-$(cat)}"; cat <<< "${str//\'/\'\\\'\'}"; }
escape_double_quotes()  { declare str="${1-$(cat)}"; cat <<< "${str//\"/\"\\\"\"}"; }
# .LH_SOURCED: {{/ lib/basic.sh }}

# .LH_SOURCED: {{/ partial/replace-marker.sh }}

# .LH_SOURCED: {{/ bin/compile-bash-file.sh }}

# .LH_NOSOURCE

(return &>/dev/null) || {
  compile_bash_project "${@}"
}
