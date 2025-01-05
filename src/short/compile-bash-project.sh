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

    lh_params_set_EXT() { EXTS+=("${1}"); }
    lh_params_set_NO_EXT() { NO_EXTS+=("${1}"); }
  }

  print_usage() { text_nice "
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

    USAGE:
    =====
    $(print_usage | sed 's/^/,/')

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
        --usage       ) print_usage; exit ;;
        --ext         ) lh_params set EXT "${@:2:1}"; shift ;;
        --no-ext      ) lh_params set NO_EXT "${@:2:1}"; shift ;;
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

# .LH_SOURCE:bin/compile-bash-file.sh
# .LH_SOURCE:lib/basic.sh
# .LH_SOURCE:lib/lh-params.sh
# .LH_SOURCE:lib/text.sh

# .LH_NOSOURCE

(return &>/dev/null) || {
  compile_bash_project "${@}"
}
