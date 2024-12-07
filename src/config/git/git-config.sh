#!/usr/bin/env bash

# .LH_SOURCE:lib/text.sh
# .LH_SOURCE:base.ignore.sh

git_config() (
  declare SELF="${FUNCNAME[0]}"

  declare TEMPLATE; TEMPLATE="$(cat <<'HEREDOC_END'
# .LH_SOURCE_NW:asset/template/git/gitconfig.extra.ini
HEREDOC_END
)"

  # If not a file, default to ssh-gen.sh script name
  declare THE_SCRIPT=git-config.sh
  grep -q -m 1 -- '.' "${0}" 2>/dev/null && THE_SCRIPT="$(basename -- "${0}")"

  # This is required for lh_params_apply_defaults
  # shellcheck disable=SC2034
  declare -A LH_DEFAULTS=(
    [DEFAULT_BRANCH]="master"
    [EDITOR]="vim"
    [DIFF_TOOL]="vimdiff"
    [MERGE_TOOL]="vimdiff"
  )

  print_help_usage() { echo "
    ${THE_SCRIPT} [--default-branch DEFAULT_BRANCH='${LH_DEFAULTS[DEFAULT_BRANCH]}'] \\
   ,  --editor [EDITOR='${LH_DEFAULTS[EDITOR]}'] --diff-tool [DIFF_TOOL='${LH_DEFAULTS[DIFF_TOOL]}'] \\
   ,  --merge-tool [MERGE_TOOL='${LH_DEFAULTS[MERGE_TOOL]}'] [--ask] [--] NAME EMAIL
  "; }

  # shellcheck disable=SC2001
  print_help() { text_nice "
    Generate a custom ~/.gitconfig.extra.ini and attach it to the main ~/.gitignore.
    The template is:
   ,
    \`\`\`
    $(sed -e 's/^/,/' <<< "${TEMPLATE}")
    \`\`\`
   ,
    USAGE:
    =====
    $(print_help_usage)
   ,
    PARAMS:
    ======
    NAME    Git user name
    EMAIL   Git user email
    --      End of options
    --default-branch  Self-explanatory
    --editor          Self-explanatory
    --diff-tool       Self-explanatory
    --merge-tool      Self-explanatory
    --ask             Provoke a prompt for all params
   ,
    DEMO:
    ====
    # With all possible defaults
    ${THE_SCRIPT} 'Anonymous user' anonymous@dev.null
   ,
    # Prompt for params
    ${THE_SCRIPT} --ask
  "; }

  parse_params() {
    declare -a args

    lh_params_reset

    declare endopts=false
    declare param
    while [[ ${#} -gt 0 ]]; do
      ${endopts} && param='*' || param="${1}"

      case "${param}" in
        --                ) endopts=true ;;
        -\?|-h|--help     ) print_help; exit ;;
        --usage           ) print_help_usage | text_nice; exit ;;
        --default-branch  ) lh_param_set DEFAULT_BRANCH "${@:2:1}"; shift ;;
        --editor          ) lh_param_set EDITOR "${@:2:1}"; shift ;;
        --diff-tool       ) lh_param_set DIFF_TOOL "${@:2:1}"; shift ;;
        --merge-tool      ) lh_param_set MERGE_TOOL "${@:2:1}"; shift ;;
        --ask             ) lh_param_set ASK true ;;
        -*                ) lh_params_unsupported "${1}" ;;
        *                 ) args+=("${1}") ;;
      esac

      shift
    done

    [[ ${#args[@]} -gt 0 ]] && lh_param_set NAME "${args[0]}"
    [[ ${#args[@]} -gt 1 ]] && lh_param_set EMAIL "${args[1]}"
    [[ ${#args[@]} -lt 3 ]] || lh_params_unsupported "${args[@]:2}"
  }

  trap_ask() {
    ! ${LH_PARAMS[ASK]-false} && return 0

    declare confirm

    while ! [[ "${confirm:-n}" == y ]]; do
      confirm=""

      read -erp "Name: " -i "${LH_PARAMS[NAME]}" 'LH_PARAMS[NAME]'
      read -erp "Email: " -i "${LH_PARAMS[EMAIL]}" 'LH_PARAMS[EMAIL]'
      read -erp "Default branch: " -i \
        "${LH_PARAMS[DEFAULT_BRANCH]-${LH_DEFAULTS[DEFAULT_BRANCH]}}" \
        'LH_PARAMS[DEFAULT_BRANCH]'
      read -erp "Editor: " -i "${LH_PARAMS[EDITOR]-${LH_DEFAULTS[EDITOR]}}" 'LH_PARAMS[EDITOR]'
      read -erp "Diff tool: " -i "${LH_PARAMS[DIFF_TOOL]-${LH_DEFAULTS[DIFF_TOOL]}}" 'LH_PARAMS[DIFF_TOOL]'
      read -erp "Merge tool: " -i "${LH_PARAMS[MERGE_TOOL]-${LH_DEFAULTS[MERGE_TOOL]}}" 'LH_PARAMS[MERGE_TOOL]'

      echo '============================'

      while [[ ! " y n " == *" ${confirm} "* ]]; do
        read -rp "YES (y) for proceeding or NO (n) to repeat: " confirm
        [[ "${confirm,,}" =~ ^(y|yes)$ ]] && confirm=y
        [[ "${confirm,,}" =~ ^(n|no)$ ]] && confirm=n
      done
    done
  }

  check_required_params() {
    [[ -n "${LH_PARAMS[NAME]}" ]] || lh_params_noval NAME
    [[ -n "${LH_PARAMS[EMAIL]}" ]] || lh_params_noval EMAIL
  }

  apply_defaults() {
    lh_params_apply_defaults
  }

  main() {
    # shellcheck disable=SC2015
    parse_params "${@}"
    trap_ask
    check_required_params

    lh_params_flush_invalid >&2 && {
      echo "FATAL (${SELF})" >&2
      return 1
    }

    apply_defaults

    echo "Name: ${LH_PARAMS[NAME]}"
    echo "Age: ${LH_PARAMS[AGE]}"
  }

  main "${@}"
)

# .LH_NOSOURCE

(return &>/dev/null) || {
  git_config "${@}"
}
