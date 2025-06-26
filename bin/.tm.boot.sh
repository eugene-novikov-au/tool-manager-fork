[[ -n "${__TM_BOOTSTRAP_SH_INITED:-}" ]] && return || __TM_BOOTSTRAP_SH_INITED=1;

TM_LOG_TIMINGS="${TM_LOG_TIMINGS:-}"
if [[ "$TM_LOG_TIMINGS" == "1" ]]; then
  export __PS4_ORG="${PS4:-}"
  START_TIME=`date +%s%N`; export PS4='+[$(((`date +%s%N`-$START_TIME)/1000000))ms][p${BASHPID}][${BASH_SOURCE}:${LINENO}]: ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'; set -x;
fi

export TM_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}" )/.." && pwd)"
# Relies on _realpath from .tm.common.sh (sourced at the top of this script).
export TM_BIN="$TM_HOME/bin"
export TM_LIB_BASH="$TM_HOME/lib/bash"

# prefix seperator
# for plugin names
__TM_SEP_PREFIX_NAME=":"
# for dirs (s we can't use the above)
__TM_SEP_PREFIX_DIR="__" 

# ensure the logging is loaded first
source "$TM_LIB_BASH/tm/lib.log.sh"
# then the '_tm::source' functions are available
source "$TM_LIB_BASH/tm/lib.source.sh"

_source_once "$TM_LIB_BASH/tm/lib.util.sh"
#
# This script bootstraps the entire tools process. Expected to be run once in a bash login script.
# Key responsibilities:
# - Defines core functions for sourcing, reloading, path management.
# - Sets up TM_ environment variables via _tm::boot::init.
# - Sources other core library scripts (.tm.common.sh, .tm.plugin.sh, .tm.plugins.sh).
# - Defines the main _tm::boot::load function called by the entry .bashrc.
#

if [[ ! "$(echo "${BASH_VERSION:-0}" | grep -e '^[5-9]\..*' )" ]]; then
  _err "ERROR: Incompatible bash version, expect bash version 5 or later, installed is '${BASH_VERSION:-0}'"
  # If this script is meant to be sourced, 'return 1' is appropriate.
  return 1
fi

_trap_error(){
  _tm::trap::error
}

_tm::boot::refresh() {
  _info "Reloading $__TM_NAME..."
    _tm::boot::__clear_cache
    _tm::plugins:regenerate_all_wrapper_scripts
    _tm::boot::load

    _info "...$__TM_NAME reloaded"
}
#
# Reload a given plugin, or reload all
#
#  $1 -(optional) name of the plugin
#
_tm::boot::reload() {
  local plugin_name="${1:-}"
  _tm::log::name "$__TM_NAME"
  _tm::source::include_once @tm/lib.common.sh .tm.plugin.sh .tm.plugins.sh .tm.common.sh

  # reload all
  # note that order is very important here, as we are clearing things, we need to be
  # careful the functions are called in the right order again to resetup the env
  _info "Reloading $__TM_NAME..."
  _tm::boot::__clear_cache
  _tm::boot::init
  _tm::plugins::regenerate_all_wrapper_scripts
  _tm::boot::load
  _info "...$__TM_NAME reloaded"
  _tm::log::pop
}

# Main loading function for the Tool Manager, typically called after _tm::boot::init.
# This function is responsible for making the Tool Manager's commands and
# enabled plugin commands available in the PATH, and for loading the
# active environments of all enabled plugins.
#
# Behavior:
#   - Adds the core Tool Manager binary directory ($TM_BIN) to PATH.
#   - Adds the directory containing plugin command wrappers ($TM_PLUGINS_BIN_DIR) to PATH.
#   - Calls `_tm::plugins::load_all_enabled` to source the .bashrc and other
#     environment scripts for each enabled plugin.
#   - Warns if plugin loading fails but does not terminate the shell.
_tm::boot::load(){
  if [[ "${TM_PLUGINS_LOADED:-0}" == "1" ]] && [[ "${TM_RELOAD:-}" != "1" ]]; then
    _debug "plugins already loaded"
    return
  fi
  export TM_PLUGINS_LOADED="1"
  # lazy load the deps
  _tm::source::include_once @tm/lib.common.sh 
  _tm::source::once "$TM_BIN/.tm.plugin.sh" "$TM_BIN/.tm.plugins.sh" "$TM_BIN/.tm.common.sh"
  _tm::plugins::load_all_enabled || _warn "Error loading tool-manager (tm) and plugins. Some features may be unavailable."
}

# Clears cached script execution status variables (matching `__TM_CACHE_*`).
# This allows parts of the system to be re-initialized or re-sourced
# during a reload or specific operations.
_tm::boot::__clear_cache() {
  local key
  for key in "$(compgen -v | grep -E "^__TM_CACHE_" || true )"; do
    unset "$key" || true
  done
  unset TM_PLUGINS_LOADED
}

# Core initialization function for the Tool Manager.
# This function is called once when .tm.boot.sh is sourced.
# It sets up all fundamental environment variables, defines standard paths,
# sources the main library scripts (.tm.common.sh, .tm.plugin.sh, .tm.plugins.sh),
# and ensures necessary directories for tm operation exist.
_tm::boot::init() {
  # --- Core Tool Manager Paths ---
  # scripts which are provided by default, but can be overridden by plugins
  TM_BIN_DEFAULTS="$TM_HOME/bin-defaults"
  # __TM_NAME: Internal name for the tool manager.
  __TM_NAME="tool-manager"
  __TM_PLUGIN_ID="tm:plugin::tool-manager::"
  __TM_NO_VENDOR="default"

  # --- Logging and Debugging Flags ---
  TM_RELOAD="${TM_RELOAD:-0}"

  _tm::log::name "$__TM_NAME"

  local config_dir="${XDG_CONFIG_HOME:-"$HOME/.config"}"
  local state_dir="${XDG_STATE_HOME:-"$HOME/.local/share"}"
  
  # --- Variable Data and Runtime Paths ---
  # Base directory for tool-manager's variable data (logs, PIDs, etc.).
  TM_VAR_DIR="$state_dir/tool-manager"
  TM_CACHE_DIR="${TM_CACHE_DIR:-"${XDG_CACHE_HOME:-$HOME/.cache}/tool-manager"}"
  
  # Directory for storing Process ID (PID) files of background plugin services.
  TM_PLUGINS_PID_DIR="$TM_VAR_DIR/plugins-pid"
  # --- Plugin Structure Paths ---
  # Directory where wrapper scripts for plugin commands are generated. This dir is added to PATH.
  TM_PLUGINS_BIN_DIR="$TM_VAR_DIR/plugins-bin"  
  # Base directory where plugin repositories are cloned.
  TM_PLUGINS_INSTALL_DIR="$TM_HOME/plugins"
  # Directory for user-specific plugin configurations (e.g., <plugin_name>.bashrc files).
  TM_PLUGINS_CFG_DIR="$config_dir/tool-manager"
  # where plugin virtual environments are placed (pip/uv/conda etc)
  TM_PLUGINS_VENV_DIR="$TM_VAR_DIR/plugin-venv"
  # Directory containing symbolic links to currently enabled plugins.
  TM_PLUGINS_ENABLED_DIR="$TM_VAR_DIR/plugins/enabled"

  TM_SPACE_DIR="${TM_SPACE_DIR:-$HOME/space}"
  
  # --- Docker Integration (Placeholder) ---
  # Flag to control if plugins (if supported) should run in Docker. Currently minimal use in core.
  TM_BASH_USE_DOCKER="${TM_BASH_USE_DOCKER:-0}"

  # --- General Configuration ---
  # THese dirs contains *.ini files defining the available plugins
  # Allows users to add their own custom plugin definition files.
  TM_PLUGINS_REGISTRY_DIR="${TM_PLUGINS_REGISTRY_DIR:-}" # custom user one
  TM_PLUGINS_DEFAULT_REGISTRY_DIR="$TM_HOME/plugin-registry" # default built in one

  # --- Directory Creation ---
  # Ensure all necessary operational directories exist.
  mkdir -p "$TM_VAR_DIR" \
            "$TM_PLUGINS_INSTALL_DIR" \
            "$TM_PLUGINS_ENABLED_DIR" \
            "$TM_PLUGINS_BIN_DIR" \
            "$TM_PLUGINS_CFG_DIR" \
            "$TM_PLUGINS_PID_DIR"
  
    # the tool-manager bins dirs. 
  _tm::util::add_to_path "$TM_BIN" "$TM_PLUGINS_BIN_DIR" "$TM_BIN_DEFAULTS" 
  
  _debug "TM initialized. TM_HOME: $TM_HOME, Plugin install dir: $TM_PLUGINS_INSTALL_DIR"
  _tm::log::pop
}

_tm::trap::error(){
  trap '_tm::trap::__stacktrace' ERR
}

_tm::trap::__stacktrace(){
  local exit_code=$?
  >&2 echo "ERROR: Script '${BASH_SOURCE[0]}' failed at line ${LINENO} with exit code $exit_code "
  #>&2 echo "Uncaught error!:"
  if command -v _tm::log::stacktrace &>/dev/null; then
    _tm::log::stacktrace
  else
    local i=0
    local line file func
    while read -r line func file < <(caller $i); do
        echo "${file}:${line} ${func}()"
      ((i++))
    done
  fi
  exit $exit_code # Exit with the same error code
}

_tm::boot::init