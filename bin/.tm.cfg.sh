
#[[ -n "${__TM_PLUGIN_CFG_SH_SOURCED:-}" ]] && return 0; export __TM_PLUGIN_CFG_SH_SOURCED=1;

# This script provides functions for getting and setting global/tm/user/plugin-specific
# configuration values. Configuration is typically stored in per-plugin
# '.env' files within the $TM_PLUGINS_CFG_DIR.
# Functions support reading, writing, and interactively prompting for
# configuration keys.
#

_tm::source::include @tm/lib.util.sh @tm/lib.file.env.sh

_tm::cfg::get_cfg_editor(){
  [[ -n "${1:-}" ]] && local default="$1" || true
  local editor="$(_tm::cfg::get --tm --key TM_CFG_EDITOR --default ${default:-${EDITOR:-code}} --no-prompt)"
  if [[ "$editor" == "" ]]; then
        editor="${default:-code}"
  fi
  _fail_if_not_installed "$editor" "No suitable editor found. Please set your \$TM_CFG_EDITOR environment variable or specify an editor command. Provided default '${1:-}'"

  echo -n "$editor"
}

_tm::cfg::get_editor(){
  [[ -n "${1:-}" ]] && local default="$1" || true
  #local editor_cmd="${1:-}"
  local editor="$(_tm::cfg::get --tm --key TM_DIR_EDITOR --default ${default:-${EDITOR:-code}})"
  if [[ "$editor" == "" ]]; then
        editor="${default:-code}"
  fi
  # Determine the editor to use
#   if [[ -z "$editor_cmd" ]]; then
#    while IFS=' ' read -r possible; do
#     _debug "trying editor:$possible"
#     if command -v "$possible" &>/dev/null; then
#         editor_cmd="$possible"
#         break
#     fi
#     done  < <(echo "$possible_editors")
#   fi

  _fail_if_not_installed "$editor" "No suitable editor found. Please set your \$TM_DIR_EDITOR environment variable or specify an editor command. Provided default '${1:-}'"

  echo -n "$editor" 
}
