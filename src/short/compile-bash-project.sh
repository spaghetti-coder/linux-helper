#!/usr/bin/env bash

# .LH_SOURCE:bin/compile-bash-file.sh
# .LH_SOURCE:lib/basic.sh
# .LH_SOURCE:lib/text.sh

# shellcheck disable=SC2317
compile_bash_project() (
  declare SELF="${FUNCNAME[0]}"

  declare SRC_DIR
  declare DEST_DIR
  declare -a EXTS
  declare -a NO_EXTS

  declare -a SRC_FILES

  declare -a ERRBAG

  print_help_usage() {
    echo "
      ${THE_SCRIPT} [--ext EXT='.sh'...] [--no-ext EXT=''...] [--] \\
     ,  SRC_DIR DEST_DIR
    "
  }

  print_help() {
    # If not a file, default to ssh-gen.sh script name
    declare THE_SCRIPT=compile-bash-project.sh
    grep -q -m 1 -- '.' "${0}" 2>/dev/null && THE_SCRIPT="$(basename -- "${0}")"

    if declare -F "print_help_${1,,}" &>/dev/null; then
      print_help_usage | text_nice
      exit
    fi

    text_nice "
      Shortcut for compile-bash-file.sh.
     ,
      IMPORTANT: DEST_DIR gets deleted in the beginning of processing.
     ,
      Compile bash project. Processing:
      * Compile each file under SRC_DIR to same path of DEST_DIR
      * Replace '# .LH_SOURCE:path/to/lib.sh' comment lines with content of the
     ,  pointed libs, while path to the lib is relative to SRC_DIR directory
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
      ${THE_SCRIPT} ./src ./dest --ext '.sh' --ext='.bash' \\
     ,  --no-ext '.hidden.sh' --no-ext='.secret.sh'
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
        --ext         ) EXTS+=("${2}"); shift ;;
        --ext=*       ) EXTS+=("${1#*=}") ;;
        --no-ext      ) NO_EXTS+=("${2}"); shift ;;
        --no-ext=*    ) NO_EXTS+=("${1#*=}") ;;
        *             ) args+=("${1}") ;;
      esac

      shift
    done

    [[ ${#args[@]} -gt 0 ]] && SRC_DIR="${args[0]}"
    [[ ${#args[@]} -gt 1 ]] && DEST_DIR="${args[1]}"
    [[ ${#args[@]} -lt 3 ]] || {
      ERRBAG+=(
        "Unsupported params:"
        "$(printf -- '* %s\n' "${args[@]:2}")"
      )

      return 1
    }
  }

  validate_required_args() {
    declare rc=0
    [[ -n "${SRC_DIR}" ]] || { rc=1; ERRBAG+=("SRC_DIR is required"); }
    [[ -n "${DEST_DIR}" ]] || { rc=1; ERRBAG+=("DEST_DIR is required"); }
    return "${rc}"
  }

  flush_errbag() {
    echo "FATAL (${SELF})"
    printf -- '%s\n' "${ERRBAG[@]}"
  }

  apply_defaults() {
    [[ ${#EXTS[@]} -gt 0 ]] || EXTS=('.sh')

    # Remove trailing slash if any
    SRC_DIR="${SRC_DIR%/}"
    DEST_DIR="${DEST_DIR%/}"
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

    declare src_files; src_files="$(find "${SRC_DIR}")" || return $?
    src_files="$(sort -n <<< "${src_files}" | grep -if <(cat <<< "${ext_ptn}"))" || return 0
    if [[ -n "${no_ext_ptn+x}" ]]; then
      src_files="$(grep -ivf <(cat <<< "${no_ext_ptn}") <<< "${src_files}" | grep '')" || return 0
    fi

    mapfile -t SRC_FILES <<< "${src_files}"
  }

  main() {
    # shellcheck disable=SC2015
    parse_params "${@}" \
    && validate_required_args \
    || { flush_errbag; return 1; }

    apply_defaults
    populate_src_files || return $?

    [[ ${#SRC_FILES[@]} -gt 0 ]] || {
      echo "# ===== ${SELF}: nothing to compile" >&2
      return
    }

    echo "# ===== ${SELF}: compiling ${SRC_DIR} => ${DEST_DIR}" >&2

    (set -x; rm -rf "${DEST_DIR}")

    declare suffix
    declare dest
    declare rc=0
    declare src; for src in "${SRC_FILES[@]}"; do
      suffix="$(realpath -m --relative-to "${SRC_DIR}" -- "${src}")" || {
        rc=1
        continue
      }

      dest="${DEST_DIR}/${suffix}"
      printf -- '# COMPILING: %s => %s\n' "${src}" "${dest}"
      (
        set -o pipefail
        (
          compile_bash_file -- "${src}" "${dest}" "${SRC_DIR}" 3>&2 2>&1 1>&3
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

# .LH_NOSOURCE

(return &>/dev/null) || {
  compile_bash_project "${@}"
}
