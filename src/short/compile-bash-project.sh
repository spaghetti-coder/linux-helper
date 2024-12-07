#!/usr/bin/env bash

# shellcheck disable=SC2317
compile_bash_project() (
  declare SELF="${FUNCNAME[0]}"

  # If not a file, default to ssh-gen.sh script name
  declare THE_SCRIPT=compile-bash-project.sh
  grep -q -m 1 -- '.' "${0}" 2>/dev/null && THE_SCRIPT="$(basename -- "${0}")"

  declare -a EXTS
  declare -a NO_EXTS

  declare -a SRC_FILES

  print_help_usage() {
    echo "
      ${THE_SCRIPT} [--ext EXT='.sh']... [--no-ext NO_EXT]... [--] \\
     ,  SRC_DIR DEST_DIR
    "
  }

  print_help() {
    text_nice "
      Shortcut for compile-bash-file.sh.
     ,
      Compile bash project. Processing:
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
      $(print_help_usage)
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
    "
  }

  parse_params() {
    declare -a args

    lh_params_reset

    declare endopts=false
    declare param
    while [[ ${#} -gt 0 ]]; do
      ${endopts} && param='*' || param="${1}"

      # shellcheck disable=SC2015
      case "${param}" in
        --            ) endopts=true ;;
        -\?|-h|--help ) print_help; exit ;;
        --usage       ) print_help_usage | text_nice; exit ;;
        --ext         ) [[ -n "${2+x}" ]] && EXTS+=("${2}") || lh_params_noval EXT; shift ;;
        --no-ext      ) [[ -n "${2+x}" ]] && NO_EXTS+=("${2}") || lh_params_noval NO_EXT; shift ;;
        -*            ) lh_params_unsupported "${1}" ;;
        *             ) args+=("${1}") ;;
      esac

      shift
    done

    [[ ${#args[@]} -gt 0 ]] && lh_param_set SRC_DIR "$(sed -e 's/\/*$//' <<< "${args[0]}")"
    [[ ${#args[@]} -gt 1 ]] && lh_param_set DEST_DIR "$(sed -e 's/\/*$//' <<< "${args[1]}")"
    [[ ${#args[@]} -lt 3 ]] || lh_params_unsupported "${args[@]:2}"
  }

  check_required_params() {
    [[ -n "${LH_PARAMS[SRC_DIR]}" ]]  || lh_params_noval SRC_DIR
    [[ -n "${LH_PARAMS[DEST_DIR]}" ]] || lh_params_noval DEST_DIR;
  }

  apply_defaults() {
    [[ ${#EXTS[@]} -gt 0 ]] || EXTS=('.sh')
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

    declare src_files; src_files="$(find "${LH_PARAMS[SRC_DIR]}")" || return $?
    src_files="$(sort -n <<< "${src_files}" | grep -if <(cat <<< "${ext_ptn}"))" || return 0
    if [[ -n "${no_ext_ptn+x}" ]]; then
      src_files="$(grep -ivf <(cat <<< "${no_ext_ptn}") <<< "${src_files}" | grep '')" || return 0
    fi

    mapfile -t SRC_FILES <<< "${src_files}"
  }

  main() {
    # shellcheck disable=SC2015
    parse_params "${@}"
    check_required_params

    lh_params_flush_invalid >&2 && {
      echo "FATAL (${SELF})" >&2
      return 1
    }

    apply_defaults
    populate_src_files || return $?

    [[ ${#SRC_FILES[@]} -gt 0 ]] || {
      echo "# ===== ${SELF}: nothing to compile" >&2
      return
    }

    echo "# ===== ${SELF}: compiling ${SRC_DIR} => ${DEST_DIR}" >&2

    declare suffix
    declare dest
    declare rc=0
    declare src; for src in "${SRC_FILES[@]}"; do
      suffix="$(realpath -m --relative-to "${LH_PARAMS[SRC_DIR]}" -- "${src}")" || {
        rc=1
        continue
      }

      dest="${LH_PARAMS[DEST_DIR]}/${suffix}"
      printf -- '# COMPILING: %s => %s\n' "${src}" "${dest}"
      (
        set -o pipefail
        (
          compile_bash_file -- "${src}" "${dest}" "${LH_PARAMS[SRC_DIR]}" 3>&2 2>&1 1>&3
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
# .LH_SOURCE:lib/text.sh
# .LH_SOURCE:base.ignore.sh

# .LH_NOSOURCE

(return &>/dev/null) || {
  compile_bash_project "${@}"
}
