#
# bin/.tm.plugin.sh
#
# This script provides core functions for managing individual Tool Manager plugins.
# Responsibilities include:
#   - Loading plugin environments (_tm::plugin::load).
#   - Enabling and disabling plugins (_tm::plugin::enable, _tm::plugin::__disable).
#   - Discovering scripts within plugins (_tm::plugin::__find_scripts_in).
#   - Generating command wrapper scripts for plugins (_tm::plugin::__generate_wrapper_scripts).
#   - Parsing qualified plugin names with prefixs (_tm::parse::plugin_name).
#


#
# _tm::plugin::reload
#
# Reloads a specific Tool Manager plugin if it is currently enabled.
# This involves disabling the plugin, re-enabling it, and regenerating its wrapper scripts.
# If the plugin is not enabled, it logs a warning and performs no operation.
#
# Args:
#   $1 - plugin_reload: The name of an associative array containing plugin details.
#                       Expected keys: 'qname' (qualified name), 'enabled_dir'.
#  $2 - (optional) auto_yes, if '1' then prompts are automatically yes
# Usage:
#   declare -A my_plugin
#   _tm::parse::plugin my_plugin "myplugin"
#   _tm::plugin::reload my_plugin
#
_tm::plugin::reload(){
  local -n plugin_reload="$1"
  local auto_yes="${2:-0}"

  local qname="${plugin_reload[qname]}"
  local enabled_link="${plugin_reload[enabled_dir]}"
    _info "Reloading plugin '${qname}' ('$enabled_link')..."

  if [[ -L "$enabled_link" ]]; then
    _trace "plugin_reload=${!plugin_reload[*]}"
    _tm::plugin::disable plugin_reload
    _tm::plugin::enable plugin_reload "$auto_yes"
    _tm::plugin::regenerate_wrapper_scripts plugin_reload
  else
    _warn "'${qname}' is not enabled. Ignoring reload"
  fi
  _info "...plugin '${qname}' reloaded"
}

#
# Load the given plugin if not already loaded
#
# $1 - the plugin associative array
#
_tm::plugin::load() {
  local -n plugin_load="$1"

  local plugin_dir="${plugin_load[install_dir]}"
  local plugin_name="${plugin_load[name]}"
  local enabled_dir="${plugin_load[enabled_dir]}"
  local is_tool_manager=${plugin_load[tm]}
  local qname="${plugin_load[qname]}"

  _trace "loading plugin '$qname' ..."

  if [[ ! -d "$plugin_dir" ]]; then # Check existence first
    _warn "Plugin directory '$plugin_dir' not found. Skipping load."
    return 1
  fi

  _debug "Found plugin directory: $plugin_dir"

  if [[ ${is_tool_manager} == false ]] && [[ ! -L "$enabled_dir" ]]; then
    _error "plugin '$plugin_dir' is not enabled as there is no '$enabled_dir' symlink"
    _fail "no plugin '$qname' (from $plugin_dir)"
  fi
  
  _debug "loading plugin ${qname} from '$plugin_dir' ..."
  _pushd "$plugin_dir" || { _error "Failed to pushd to '$plugin_dir'"; return 1; }
  _tm::log::push_child "plugin/$(basename "$plugin_dir")"

  local original_path="$PATH"

  # capture current settings, to restore later
  local restore_options=$(set +o)
  # TODO: review this. now use .env files?
  # run custom config first
  local plugin_custom_bashrc="$TM_PLUGINS_CFG_DIR/$plugin_name.bashrc"
  _trace "looking for '$plugin_custom_bashrc'"

  if [[ -f "$plugin_custom_bashrc" ]]; then
    _tm::source "$plugin_custom_bashrc"
  fi

  # the plugin config can then use the custom config
  local plugin_bashrc="$plugin_dir/.bashrc"
  _trace "looking for '$plugin_bashrc'"

  if [[ -f "$plugin_bashrc" ]] && [[ "$plugin_bashrc" != "$TM_HOME/.bashrc" ]]; then
     _tm::source "$plugin_bashrc"
  fi

  if [[ -d "$plugin_dir/bashrc.d" ]]; then
    _debug "scanning for *.bashrc files in '$plugin_dir/bashrc.d'"
    for file in "$plugin_dir/bashrc.d/"*.bashrc; do
      if [[ -f "$file" ]]; then
        _debug "  loading bashrc: $file"
        _tm::source "$file"
      fi
    done
  fi

  if [[ -d "$plugin_dir/service.d" ]]; then
    for file in "$plugin_dir/service.d/"*.sh; do
      #TODO: check if service already running (existing pid). If so, stop it, and start again?
      _debug "starting service: $file"
      # Track PID in the central TM_PLUGINS_PID_DIR
      if [[ -f "$file" ]]; then
        mkdir -p "$TM_PLUGINS_PID_DIR/$plugin_name"
        local service_name
        service_name=$(basename "$file" .sh)
        local pid_file="$TM_PLUGINS_PID_DIR/$plugin_name/${service_name}.pid"
        
        "$file" &
        local pid="$!"
        echo "$pid" > "$pid_file"
        _debug "service '$service_name' started with PID $pid (PID file: $pid_file)"
      fi
    done
  fi
  _popd
  
  if [[ ! "$original_path" == "$PATH" ]]; then
    _info "PATH was updated by $plugin_dir"
  fi

  _tm::log::pop
  _debug "...plugin loaded"

  # restore options, in case plugins have set various flags
  # also prevent adding to history ?
  HISTCONTROL=ignorespace eval " $restore_options" 
}


#
# Function to collect non-hidden recursive directories within the given dir
#
# $1 - the dir to scan
#
_tm::plugin::__add_scripts_to_path() {
  local bin_dir="$1"
  if [[ ! -d "$bin_dir" ]]; then
    return
  fi

  _debug "scanning '$bin_dir' for script paths"
  # Find directories and capture into a local array
  local -a found_dirs=()
  mapfile -t found_dirs < <(find "$bin_dir" -type d \( -name ".*" -prune -o -print \))
  _debug "found dirs: ${found_dirs[*]}"

  # Append found directories to the global array if any were found
  _tm::boot::add_to_path "${found_dirs[@]}"
}


#
# Recursively find all executable scripts in a the given bin dir that match an optional filter
#
# This will ignore any 'hidden' dir starting with '.', though the passed in dir can be a hidden one
#
# Arguments:
#   $1 - bin_dir: The directory to scan for scripts
#
# Usage:
#   _tm::plugin::__find_scripts_in <plugin_dir>/bin 
#
# Output:
#   List of matching script files, one per line
#
_tm::plugin::__find_scripts_in() {
  local bin_dir="$1"
  # Only filter out hidden subdirectories, not the base directory itself
  if [[ -d "$bin_dir" ]]; then
    find "$bin_dir" -type f \( -not -path "$bin_dir/*/.*" \)  -not -path "$bin_dir/.*" | sort | while read -r file; do
      if [[ "$(basename "$file")" != *.md ]]; then
        if head -n 1 "$file" | grep -q "^#!"; then
          echo "$file"
        fi
      fi
    done
  fi
}

#
# _tm::plugin::enable
#
# Enables a Tool Manager plugin by creating a symlink from its install directory to the enabled directory.
# This function also handles the execution of optional 'plugin-requires' and 'plugin-enable' scripts
# located within the plugin's directory.
#
# Args:
#   $1 - plugin_enable: The name of an associative array containing plugin details.
#                       Expected keys: 'qname' (qualified name), 'install_dir', 'enabled_dir', 'tm' (boolean).
#  $2 - (optional) auto_yes, if '1' then prompts are automatically yes
#
# Behavior:
#   - Skips enabling if the plugin is the tool-manager itself (always enabled).
#   - Checks if the plugin directory exists. If not, it logs an error and fails.
#   - If the plugin is already enabled (symlink exists), it logs an informational message and returns.
#   - Creates the necessary directory structure for the symlink if it doesn't exist.
#   - Creates a symbolic link from the plugin's install directory to the enabled directory.
#   - Calls `_tm::plugin::__generate_wrapper_scripts` to create wrapper scripts for the plugin's commands.
#   - If a 'plugin-requires' script exists, it prompts the user to run it. If the user agrees,
#     the script is executed. Errors are warned but do not prevent enablement.
#   - If a 'plugin-enable' script exists, it is executed. If this script fails, the symlink is removed.
#   - Logs informational messages about the enablement process.
#   - Calls `_tm::plugin::load` to load the plugin's environment.
#
# Usage:
#   declare -A my_plugin
#   _tm::parse::plugin my_plugin "myvendor/myplugin"
#   _tm::plugin::enable my_plugin
#
_tm::plugin::enable() {
  local -n plugin_enable="$1"
  local auto_yes="${2:-0}"

  local plugin_dir="${plugin_enable[install_dir]}"
  local qname="${plugin_enable[qname]}"
  local enabled_dir="${plugin_enable[enabled_dir]}"
  local vendor="${plugin_enable[vendor]}"
  local plugin_cfg_sh="${plugin_enable[cfg_sh]}"

  #_trace "enabling plugin: '${qname}'"
  local is_tool_manager=${plugin_enable[tm]}

  if [[ $is_tool_manager == true ]]; then
    _info "Skipping 'enabling' the tool-manager plugin as it's allways enabled"
    return $_true
  fi

  if [[ ! -d "$plugin_dir" ]]; then
    _error "No plugin dir '$plugin_dir' exists for plugin '${qname}'"
    _error "Could not enable plugin. Run 'tm-plugin-ls' for available plugins"
    return $_false
  else
    if [[ -L "$enabled_dir" ]]; then
      _info "plugin '${qname}' already enabled"
    else
      _info "enabling plugin '${qname}' in '$plugin_dir'"
      mkdir -p "$(dirname "$enabled_dir")"
      ln -s "$plugin_dir/" "$enabled_dir" || { 
        _error "Failed to create symlink for plugin '${qname}' from '$plugin_dir/' to '$enabled_dir'." 
        _tm::plugins::reload_all_enabled
        return $_false
      }

      _tm::plugin::__generate_wrapper_scripts plugin_enable 

      # plugin requires script
      local requires_script="$plugin_dir/plugin-requires"
      if [[ -f "$requires_script" ]]; then
        local yn=""
        if [[ "$auto_yes" == '1' ]]; then
          yn='y'
        fi
        if _confirm "Plugin has a 'plugin-requires' script ('$requires_script'), should I run it?" yn; then
            _info "Running plugin requires script: '$requires_script'"
            chmod a+x "$requires_script" || true
            ( "$requires_script" ) || _warn "Error running requires script: '$requires_script'. Ignoring failures, disable/re-enable to run again"
        else
            _info "Not running '$requires_script'. Plugin might not work without it's dependencies"
        fi
      fi

      # lib contributions.
      # TODO: do we allow lib contributions to be active, even if the plugin is disabled? Other scripts might depend on it
      # we might also want to use some of it's libs without the plugin actually be active
      local lib_dir="$plugin_dir/lib-shared"
      if [[ -d "$lib_dir" ]]; then
        _debug "plugin has a '$lib_dir' dir"
        local yn=''
        if [[ "$auto_yes" == '1' ]]; then
          yn='y'
        fi

        echo "Plugin provides a 'lib-shared' directory, with libs:"
        _pushd "$lib_dir"
          find . -type f
        _popd
        if _confirm "Make this available to other plugins via '_include @${vendor}/<lib-name>.sh'?" yn; then
            _info "Linking '${TM_PLUGINS_LIB_DIR}/${vendor}' to '${lib_dir}'"
            mkdir -p "${TM_PLUGINS_LIB_DIR}"
            ln -sf "${lib_dir}" "${TM_PLUGINS_LIB_DIR}/${vendor}"
            _info "plugin libs available under '_include @${vendor}/<lib-name>.sh'"
          else
            _info "Not making '${lib_dir}' available to other plugins"
        fi
      fi

      # config file. User can find this and edit it manually
      mkdir -p "$(dirname "${plugin_cfg_sh}")"
      touch "${plugin_cfg_sh}"
      _info "plugin config '${plugin_cfg_sh}'"

      # enable script
      local enable_script="$plugin_dir/plugin-enable"
      if [[ -f "$enable_script" ]]; then
        _info "Running plugin enable script: '$enable_script'"
        chmod a+x "$enable_script" || true
        ("$enable_script") || ( _warn "Error running enable script: '$enable_script'" && rm -f "$enabled_dir" || true )
      fi

      _info "enabled plugin '${qname}' in '$plugin_dir'"

      _tm::plugin::load plugin_enable || _warn "Couldn't load plugin '${qname}' in '${plugin_dir}'"
    fi
  fi
}

#
#
# Disables a Tool Manager plugin by removing its symlink from the enabled directory.
# If a 'plugin-disable' script exists within the plugin, it will be executed before removal.
#
# Args:
#   $1 - plugin_arr: The name of an associative array containing plugin details.
#                    Expected keys: 'qname' (qualified name), 'prefix', 'install_dir', 'enabled_dir'.
#
# Behavior:
#   - Checks if the plugin is currently enabled (i.e., its symlink exists).
#   - If enabled, it attempts to run the plugin's 'plugin-disable' script (if present and executable).
#   - Removes the symlink from $TM_PLUGINS_ENABLED_DIR.
#   - Reloads all enabled plugins to reflect the change.
#   - Logs informational messages about the process.
#   - If the plugin is already disabled, it logs an informational message.
#
# Usage:
#   declare -A my_plugin
#   _tm::parse::plugin my_plugin "myvendor/myplugin"
#   _tm::plugin::disable my_plugin
#
_tm::plugin::disable() {
  local -n plugin_arr="$1"

  local qname="${plugin_arr[qname]}"
  local prefix="${plugin_arr[prefix]}"
  local plugin_dir="${plugin_arr[install_dir]}"
  local plugin_enabled_link="${plugin_arr[enabled_dir]}"
  
  _info "Disabling plugin '${qname}'"

  if [[ -L "$plugin_enabled_link" ]]; then
      local disable_script="$plugin_enabled_link/plugin-disable"
      if [[ -f "$disable_script" ]]; then
        _debug "running plugin disable script: '$disable_script'"
        chmod a+x "$disable_script" || true
        ("$disable_script") || _warn "Error running disable script: '$disable_script'"
      fi
      _debug "removing symlink '$plugin_enabled_link'"
      if rm -f "$plugin_enabled_link"; then
        _info "plugin is disabled"
      else
        _error "Failed to remove symlink '$plugin_enabled_link'."
        return $_false
      fi

      _tm::plugins::reload_all_enabled
  else
    _info "plugin is already disabled"
    _debug " - no symlink '$plugin_enabled_link' to plugin '$plugin_dir'"
    if [[ ! -d "$plugin_dir" ]]; then
      _warn " - also no plugin '$plugin_dir' exists"
    fi
  fi
}

#
# Regenerate the plugin wrapper scripts  

#
# $1 - plugin associative array
#
_tm::plugin::regenerate_wrapper_scripts(){
  local -n plugin_regen="$1"

  local qname="${plugin_regen[qname]}"
  local prefix="${plugin_regen[prefix]}"
  local enabled_dir="${plugin_regen[enabled_dir]}"
  local plugin_dir="${plugin_regen[install_dir]}"

  _trace "Regenerate plugin wrapper scripts for '${qname}' : plugin_dir='$plugin_dir' prefix='$prefix' plugin='$qname' enabled_dir='$enabled_dir'"
  #TODO: remove the old ones for this plugin
  _trace "TODO: remove old wrapper scripts for this plugin"

  _tm::plugin::__generate_wrapper_scripts plugin_regen
}


#
# Find the scripts for the given plugin and add wrapper invoke scripts. These scripts prepare the
# environment for the real plugin script to run. We want to do as much of the work here, rather than
# when we run the user script, as the user script might be called in tight loops
#
# $1 - plugin associative array
#
_tm::plugin::__generate_wrapper_scripts() {
  local -n plugin_generate="$1"

  if [[ ${plugin_generate[tm]} == true ]]; then
    _warn "Not generating wrapper scripts for the tool-manager scripts"
    return
  fi

  # prefixs allows us to have a single plugin install, but multiple representations of it with different config
  local prefix="${plugin_generate[prefix]}"
  local vendor="${plugin_generate[vendor]}"
  local plugin_name="${plugin_generate[name]}"
  local qname="${plugin_generate[qname]}"
  local qpath="${plugin_generate[qpath]}"
  local plugin_dir="${plugin_generate[install_dir]}"
  local plugin_id="${plugin_generate[id]}"

  local plugin_bin_dir="${plugin_dir}/bin"
  local plugin_cfg_dir="${TM_PLUGINS_CFG_DIR}/${qpath}"
  local plugin_state_dir="${TM_PLUGINS_STATE_DIR}/${qpath}"

  _debug "Generating wrapper invoke scripts for plugin '$qname', prefix '"$prefix"' in $TM_PLUGINS_BIN_DIR to ${plugin_bin_dir}"

  local script_prefix=""
  if [[ -n "$prefix" ]]; then
    script_prefix="${prefix}-"
    _debug "using script prefix '$script_prefix'"
  fi
  if [[ -n "$vendor" ]]; then
    _debug "using vendor '$vendor'"
  fi

  mkdir -p $TM_PLUGINS_BIN_DIR
  _debug "plugin '${qname}' contributes: "
  # now create wrapper scripts for all the plugin scripts
  local file
  local -a directives
  _tm::plugin::__find_scripts_in "$plugin_bin_dir" | while IFS= read -r file; do
    [[ -z "$file" ]] && continue # Skip empty lines if any

    # ignore non-executable files
    if [[ ! -x "$file" ]]; then
      _warn "Script '$file' is not executable. Skipping"
      continue
    fi

    local name_only="${script_prefix}$(basename "$file")"
    local wrapper_script="$TM_PLUGINS_BIN_DIR/${name_only%.*}"  # remove suffixes like '.sh' and '.py' etc
    _trace "script $wrapper_script invokes $file"
    _debug "   - $name_only"

    cat << EOF > "$wrapper_script"
#!/usr/bin/env bash
$TM_HOME/bin-internal/tm-run-script '$wrapper_script' '$plugin_id' '$plugin_dir' '$plugin_cfg_dir' '$plugin_state_dir' '$file' "\$@"
EOF
    chmod a+x "$wrapper_script"
  done
}
