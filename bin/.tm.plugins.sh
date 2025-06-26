#
# bin/.tm.plugins.sh
#
# This script provides functions for managing collections of Tool Manager plugins.
# Responsibilities include:
#   - Loading all enabled plugins (_tm::plugins::load_all_enabled).
#   - Reloading plugin configurations (_tm::plugins::reload_all_enabled).
#   - Finding all enabled or installed plugins.
#   - Installing new plugins from INI file definitions (_tm::plugins::install).
#   - Iterating over available plugins defined in INI files (_tm::plugins::__available_foreach_call).
# It depends on .tm.util.sh for INI parsing and .tm.plugin.sh for individual plugin operations.
#

_tm::source::include @tm/lib.file.ini.sh
_tm::source::once "$TM_BIN/.tm.plugin.sh"

#
# Regenerate all the plugin scripts
#
#
_tm::plugins::regenerate_all_wrapper_scripts(){
  _info "Regenerating plugin wrapper scripts..."
  _tm::plugins::remove_all_wrappers

  local -a plugin_ids  
  mapfile -t plugin_ids < <(_tm::plugins::find_all_enabled_plugin_ids)
  local -A parsed_plugin
  for plugin_id in "${plugin_ids[@]}"; do
    #_info "plugin_id=$plugin_id"
    _tm::util::parse::plugin_id parsed_plugin "$plugin_id"
    _tm::plugin::regenerate_wrapper_scripts parsed_plugin
  done

  _info "...wrapper scripts regenerated"

}

# Reloads all enabled plugins by resetting the loaded flag,
# removing all plugin command wrappers, and then loading them again.
_tm::plugins::reload_all_enabled() {
  __TM_PLUGINS_LOADED=0
  _tm::plugins::remove_all_wrappers
  _tm::plugins::load_all_enabled
}

# Loads all enabled plugins.
# Ensures the main tool-manager plugin ($TM_HOME) is loaded first.
# Uses __TM_PLUGINS_LOADED flag to ensure plugins are loaded only once per session/reload.
_tm::plugins::load_all_enabled() {

  # # the tools plugin must always be the first to load, as other plugins might depend on it
  # # It should only be loaded once, so trying again later results in a no-op
  # _tm::plugin::load "$TM_HOME"

  local -a plugins_enabled_dirs  
  mapfile -t plugins_enabled_dirs < <(_tm::plugins::find_all_enabled_dirs)

  local enabled_dir
  local -A enabled_plugin
  for enabled_dir in "${plugins_enabled_dirs[@]}"; do
    _trace "loading from enabled dir: '${enabled_dir}'"
    _tm::util::parse::plugin_enabled_dir enabled_plugin "$(basename "$enabled_dir")"
    _tm::plugin::load enabled_plugin || _warn "Couldn't load plugin '${enabled_plugin[qname]}'"
  done
  export PATH
  _trace "PATH=$PATH"
}

# Removes the entire directory containing plugin command wrapper scripts ($TM_PLUGINS_BIN_DIR).
# This is typically done before regenerating them during a reload.
_tm::plugins::remove_all_wrappers() {
  # TODO: check not root or home dir or something
  if [[ -d "$TM_PLUGINS_BIN_DIR" ]]; then
    rm -rf "$TM_PLUGINS_BIN_DIR" 
  fi
}

# Recursively find all executable scripts in a directory that match an optional filter
#
# This will ignore any 'hidden' dir starting with '.', though the passed in dir can be a hidden one
#
# Arguments:
#   $1 - Optional command name filter (prefix)
#
# Usage:
#   _tm::plugins::find_all_scripts "prefix_filter"
#
# Output:
#   List of matching script files, one per line
_tm::plugins::find_all_scripts() {
  local plugin_dirs
  plugin_dirs="$(_tm::plugins::find_all_enabled_dirs)"
  
  local scripts
  local file
  local plugin_dir

  scripts="$(_tm::plugin::__find_scripts_in "$TM_HOME/bin")"
  for file in $scripts; do
    echo "$file"
  done

  for plugin_dir in $plugin_dirs; do
    _debug "finding scripts in $plugin_dir"
    scripts="$(_tm::plugin::__find_scripts_in "$plugin_dir/bin")"
    for file in $scripts; do
      echo "$file"
    done
  done
}


_tm::plugins::find_all_disabled_plugin_ids() {
  local -a ids 
  _tm::plugins::find_all_installed_plugin_ids ids

  local -a enabled_ids 
  _tm::plugins::find_all_enabled_plugin_ids enabled_ids

  # remove the enabled ones
  for id in "${ids[@]}"; do
    unset ids[id]
  done
  for id in "${ids[@]}"; do
    echo "$id"
  done
}
#
# Return all the enabled plugin ids
#
_tm::plugins::find_all_enabled_plugin_ids() {
  local -a plugins_enabled_dirs  
  mapfile -t plugins_enabled_dirs < <(_tm::plugins::find_all_enabled_dirs | sort)
  #_trace "plugins_enabled_dirs=${plugins_enabled_dirs[@]}"
  local enabled_dir
  local -A plugin_details
  for enabled_dir in "${plugins_enabled_dirs[@]}"; do
    _tm::util::parse::plugin_enabled_dir plugin_details "$(basename "$enabled_dir")"
    echo "${plugin_details[id]}"
  done
}

#
# Return all the plugin dirs that are enabled
#
_tm::plugins::find_all_enabled_dirs() {
  _debug "Looking for plugins in: '$TM_PLUGINS_ENABLED_DIR'"
  find "$TM_PLUGINS_ENABLED_DIR" -maxdepth 1 -mindepth 1 -type l \( -name ".*" -prune -o -print \) | sort 
}

_tm::plugins::find_all_installed_plugin_ids() {
  local -a dirs=() 
  mapfile -t dirs < <(_tm::plugins::find_all_installed_dirs)
  #_trace "plugins_enabled_dirs=${plugins_enabled_dirs[@]}"
  local installed_dir vendor name
  local -a parts=()
  local -A plugin_details
  for dir in "${dirs[@]}"; do
    IFS="/" read -r -a parts <<< "$(echo "$dir")"
    vendor="${parts[-2]}"
    name="${parts[-1]}"
    _tm::util::parse::plugin_name plugin_details "${vendor}/${name}"
    echo "${plugin_details[id]}"
  done
}

#
# Return all the installed plugin dirs
#
_tm::plugins::find_all_installed_dirs() {
  # TODO: convert to plugin ids
  find "$TM_PLUGINS_INSTALL_DIR" -maxdepth 2 -mindepth 2 -type d \( -name ".*" -prune -o -print \) | sort
}

#
# List all the available plugin ids
#
_tm::plugins::find_all_available_plugin_ids() {
  # TODO: scan the plugin files
  _todo "find available plugin ids"
  local -a plugin_ini_files=()
  _tm::plugins::__ini_files_to_array plugin_ini_files

  if [[ ${#plugin_ini_files[@]} -eq 0 ]]; then
      _warn "No plugin install files found"
      return 1
  fi

  local ini_file
  declare -A plugin_details # plugin dtails from the ini file
  declare -A plugin # plugin details from the parsed name

  for ini_file in "${plugin_ini_files[@]}"; do
      if [[ ! -f "$ini_file" || ! -r "$ini_file" ]]; then
          _warn "INI file not found or not readable: '$ini_file'. Skipping"
          continue
      fi

      local section_names_in_file=()
      _tm::file::ini::read_sections section_names_in_file "$ini_file"

      for vendor_slash_name in "${section_names_in_file[@]}"; do
          plugin_details=() # Clear for each section
          _tm::file::ini::read_section plugin_details "$ini_file" "$vendor_slash_name"
          if [[ -n "${plugin_details[repo]}" ]]; then
              _tm::util::parse::plugin_name plugin "$vendor_slash_name"
              echo "${plugin[id]}"
          else
              _warn "Plugin '$vendor_slash_name' in '$ini_file' is missing the 'repo' attribute. Skipping"
          fi
      done
  done
}

# --- Get all unique plugin 'dir' values from all INI files ---
# This function reads all configured plugin INI files, extracts the 'dir'
# attribute from every plugin section, and outputs a unique, sorted list
# of these directory names. These names are relative to $TM_PLUGINS_INSTALL_DIR.
#
# Output:
#   A newline-separated list of unique plugin directory names.
#
# Example usage in another script:
#   local available_dirs
#   mapfile -t available_dirs < <(_tm::plugins::__get_all_available_dirs)
#   for dir_name in "${available_dirs[@]}"; do
#     echo "Available plugin dir: $TM_PLUGINS_INSTALL_DIR/$dir_name"
#   done
#
_tm::plugins::__get_all_available_dirs() {
    local plugin_files_array=()
    _tm::plugins::__ini_files_to_array "plugin_files_array"

    if [[ ${#plugin_files_array[@]} -eq 0 ]]; then
        _warn "Cannot find available plugin dirs."
        return 1
    fi

    local all_dirs=()
    local ini_file
    local plugin_name
    declare -A plugin_details

    for ini_file in "${plugin_files_array[@]}"; do
        if [[ ! -f "$ini_file" || ! -r "$ini_file" ]]; then
            _warn "INI file not found or not readable: '$ini_file'. Skipping for available dirs."
            continue
        fi

        local section_names_in_file=()
        _tm::file::ini::read_sections section_names_in_file "$ini_file" 

        for vendor_slash_name in "${section_names_in_file[@]}"; do
            plugin_details=() # Clear for each section
            _tm::file::ini::read_section plugin_details "$ini_file" "$vendor_slash_name"
            if [[ -n "${plugin_details[repo]}" ]]; then
                all_dirs+=("${TM_PLUGINS_INSTALL_DIR}/${vendor_slash_name}")
            else
                _warn "Plugin '$vendor_slash_name' in '$ini_file' is missing the 'repo' attribute.."
            fi
        done
    done

    # Output unique, sorted directory names
    if [[ ${#all_dirs[@]} -gt 0 ]]; then
        printf '%s\n' "${all_dirs[@]}" | sort -u
    fi
    return 0
}

# --- Reads the plugin files in TM_PLUGINS_REGISTRY_DIR  TM_PLUGINS_REGISTRY_DIR string into a specified array ---
# Arguments:
#   $1: Name of the array to populate (passed by reference)
#
_tm::plugins::__ini_files_to_array() {
    if [[ -z "$1" ]]; then
        _error "Usage: $FUNCNAME <array_name_ref>"
        return 1
    fi
    local -n _target_plugins_array="$1" # Use nameref for the output array
    # Use space and newline as delimiters
    # shellcheck disable=SC2226 # We want word splitting here for read -a
    readarray -d '' _target_plugins_array < <(_tm::plugins::find_ini_files)

    if _is_trace; then
      _trace "plugin ini files: [${_target_plugins_array[@]}]'"
    fi
}

_tm::plugins::find_ini_files() {
    # user provided one stakes precedence
    if [[ -n "$TM_PLUGINS_REGISTRY_DIR" ]] && [[ -d "$TM_PLUGINS_REGISTRY_DIR" ]]; then
      find "$TM_PLUGINS_REGISTRY_DIR" -type f -name '*.ini' -print0 | sort -z
    fi
    if [[ -n "$TM_PLUGINS_DEFAULT_REGISTRY_DIR" ]] && [[ -d "$TM_PLUGINS_DEFAULT_REGISTRY_DIR" ]]; then
      find "$TM_PLUGINS_DEFAULT_REGISTRY_DIR" -type f -name '*.ini' -print0 | sort -z
    fi
}

_tm::plugins::uninstall() {
  local plugin="$1"

  _info "Uninstalling plugin '$plugin'"
  local -A plugin_to_disable
  _tm::util::parse::plugin plugin_to_disable "$plugin"

  local qname="${plugin_to_disable[qname]}"
  local plugin_dir="${plugin_to_disable[install_dir]}"

  local yn=''
  while [[ -z "$yn" ]]; do
    _read "Really disable plugin ${qname} in ${plugin_dir}? [yn]" yn
    case "$yn" in 
      y|Y|yes)
        _tm::plugin::disable plugin_to_disable
        rm -fR "$plugin_dir"
        return
        ;;
      n|N|no)
        _info "not removing"
        return 1
        ;;
    esac
  done
}

# Installs a plugin based on its definition in the INI files.
# Args:
#   $1 - qualified_name: The full plugin identifier, which can include
#        a prefix and/or a version separated by '@'.
#        e.g., "myplugin", "myns:myplugin", "myplugin@v1.2", "myns:myplugin@v1.2"
# Behavior:
#   - Parses prefix from qualified_name.
#   - Parses core plugin name and version from the remainder of qualified_name.
#   - Searches for the plugin_name in INI files.
#   - Clones the plugin if not already installed, using the specified version
#     (or INI 'commit', or repo default if 'commit' is also empty).
#   - If installed, checks if it's enabled as per qualified_name
#     (currently uses `tm-plugin-enable` which handles "already enabled" state;
#      a dedicated `tm-plugin-is-enabled` would be cleaner for the check if available).
#   - Attempts to enable the plugin using the original qualified_name.
_tm::plugins::install() {
  local plugin="$1"
  _info "Installing '$plugin'"
  if [[ "$plugin" == "git@"* ]] || [[ "$plugin" == "https://github.com/"* ]] || [[ "$plugin" == "http://github.com/"* ]] || [[ "$plugin" == "github.com/"*  ]]; then
    _tm::plugins::install_from_git "$plugin"
  else
    _tm::plugins::install_from_registry "$plugin"
  fi
}

_tm::plugins::install_from_git() {
  local git_repo="$1" 
  # extract out the vendor path and use the paclage name as the plugin name
  _trace "Installing from raw repo '$git_repo'"
  local path="$(echo "$git_repo" | sed -E 's|.*github.com[:/]?||' | sed 's|.git||')"
  local plugin_name prefix vendor version
  IFS="/" read -r vendor plugin_name <<< "$path"
  IFS="@" read -r plugin_name version <<< "$plugin_name" # maybe ends with a some_repo.git@<version>
  if [[ -z "$version" ]]; then # maybe it ended with a 'some_repo.git#<version>'
    IFS="#" read -r plugin_name version <<< "$plugin_name"
  fi
  _debug "extracted plugin details: vendor '$vendor' plugin_name '$plugin_name' version '$version'"

  local -A plugin_details
  _tm::util::parse::plugin_name plugin_details "$vendor/$plugin_name"

  local qname="${plugin_details[qname]}"
  local install_dir="${plugin_details[install_dir]}"

  local yn=''
  while [[ -z "$yn" ]]; do
    _read "really install '${qname}' into '${install_dir}' from '${git_repo}'? [yn]" yn
    case "$yn" in 
      y|Y|yes)
        if _tm::plugins::__clone_and_install plugin_details "${git_repo}" "${version}"; then
          _info "sucessfully installed"
          return
        else
          _fail "error installing plugin"
        fi
        ;;
      n|N|no)
        _info "skipping install"
        return 1
        ;;
    esac
  done
}

#
# Install a plugin from the plugin registry
#
# $1 - the plugin name or id
#
_tm::plugins::install_from_registry(){
  local qualified_name="$1"

  if [[ -z "$qualified_name" ]]; then
    _error "Plugin name is required. Input: '$qualified_name'"
    return 1
  fi

  local -A plugin=()
  _tm::util::parse::plugin plugin "$qualified_name"
  local plugin_name="${plugin[name]}"
  local prefix="${plugin[prefix]}"
  local vendor="${plugin[vendor]}"
  local version="${plugin[version]:-main}"
  local qname="${plugin[qname]}"
  local plugin_dir="${plugin[install_dir]}"
  # what section we are looking for
  local vendor_and_name="${vendor}/${plugin_name}"

  _info "Attempting to install plugin: vendor="${vendor}", name='${plugin_name}', version='${version}', prefix='${prefix:-none}' (from input '$qualified_name')"

  local -a plugin_files=()
  _tm::plugins::__ini_files_to_array "plugin_files"

  local plugin_ini_file 
  # TODO: read the registry files and cache the processed output
  # find the first matching plugin definition
  for plugin_ini_file in "${plugin_files[@]}"; do
    # Check if the INI file exists
    if [[ ! -f "$plugin_ini_file" ]]; then
      _warn "Plugin configuration file '$plugin_ini_file' not found."
      continue # read next file
    fi

    # Check if the plugin section exists in the INI file
    if ! _tm::file::ini::has_section "$plugin_ini_file" "$vendor_and_name"; then
      _debug "Plugin section '$plugin_name' not found in '$plugin_ini_file'."
      continue # next file
    fi
    
    _debug "Plugin section '$vendor_and_name' found in '$plugin_ini_file'."
    
    # Read plugin details from the INI file
    declare -A plugin_details
    if _tm::file::ini::read_section plugin_details "$plugin_ini_file" "$vendor_and_name"; then
      local plugin_cfg_repo="${plugin_details[repo]:-}"
      local plugin_cfg_commit="${plugin_details[commit]:-}" # Commit from INI is default
    else
      fail "could not find plugin details in '$plugin_ini_file'"
    fi
      
    # If a version was specified in the input, it overrides the commit from INI
    if [[ -n "$version" ]]; then
      _debug "Using specified version '$version' to override INI commit ('${plugin_cfg_commit:-none}')."
      plugin_cfg_commit="$version"
    elif [[ -z "$plugin_cfg_commit" ]]; then # If no version in input AND no commit in INI
        _warn "No commit/branch/tag specified in INI for '$vendor_and_name' and no version in input. Defaulting to 'main' or 'master' if common, but git clone might fail or pick default."
    fi
    # local plugin_cfg_desc="${plugin_details[desc]}" # desc is available if needed
    if _tm::plugins::__clone_and_install plugin "${plugin_cfg_repo}" "${plugin_cfg_commit}"; then
      return
    fi
  done
  _fail "Could not install plugin '$plugin_name' (from input '$qualified_name'). Searched in: '$TM_PLUGINS_INI_FILES'"
}

#
# $1 - plugin array
# $2 - repo
# $3 - commit

_tm::plugins::__clone_and_install(){
  local -n plugin="$1"
  local repo="$2"
  local commit="${3:-main}"

  local plugin_name="${plugin[name]}"
  local prefix="${plugin[prefix]}"
  local vendor="${plugin[vendor]}"
  local version="${plugin[version]:-main}"
  local qname="${plugin[qname]}"
  local plugin_dir="${plugin[install_dir]}"
  local vendor_and_name="${vendor}/${plugin_name}"

  if [[ -d "$plugin_dir" ]]; then
    _info "plugin '$qname' is already installed in '$plugin_dir'"
    _info "ensuring it is enabled as '${qname}'..."
    if ! tm-plugin-enable --plugin "${qname}"; then
        _warn "Failed to ensure already installed plugin '$vendor_and_name' is enabled as '${qname}'."
    else
        _info "Plugin '${qname}' is installed and enabled."
    fi
    return 0 # Successfully handled (already installed)
  else
    _info "Installing plugin '$vendor_and_name' from '$repo' (commit/branch: '${commit}') to '$plugin_dir'"
    local clone_cmd="git clone"
    if [[ -n "$commit" ]]; then
      clone_cmd="$clone_cmd --branch \"$commit\""
    fi
    # Using eval for clone_cmd to correctly handle quoted branch name if it contains spaces (unlikely but possible)
    # However, direct expansion is safer if branch names are simple.
    # For simplicity and common case, direct expansion:
    if [[ -n "$commit" ]]; then
      git clone --branch "$commit" "$repo" "$plugin_dir"
    else
      git clone "$repo" "$plugin_dir" # Let Git use default branch
    fi

    if [[ $? -eq 0 ]]; then
      _info "Plugin '$plugin_name' installed successfully into '$plugin_dir'."
      # Attempt to enable the plugin after successful installation using the original qualified name
      if tm-plugin-enable "${qname}"; then # Use original full name for enabling
        _info "Plugin '${qname}' enabled successfully."
      else
        _warn "Plugin '${qname}' installed but failed to enable."
      fi
      return 0 # Successful installation and attempted enable
    else
      _error "Failed to clone plugin '$plugin_name' from '$repo' (commit/branch: '${commit}')."
      return 1
    fi
  fi
}

# Arguments:
#   $1: Name of the callback function to execute for each available plugin.
#       callback <plugin assoc array>
#
_tm::plugins::foreach_available_callback() {

    # --- Argument Parsing ---
  local -A args
  _parse_args \
      --help                    "$FUNCNAME: For each avaliable plugin, invoke the given function with the plugin associative array"\
      --opt-match               "|short=m|desc=the plugin name match" \
      --opt-default-commit     "|short=c|default=main|desc=the default commit/branch to use if none provided" \
      --opt-function            "|short=f|required|remainder|desc=the callback function" \
      --result args \
      -- "$@"

    local callback_func="${args[function]}"
    shift # next args are filter options

    local match_name="${args[match]:-}"
    local default_commit="${args[default-commit]}"

    local -a plugin_files=()
    _tm::plugins::__ini_files_to_array plugin_files

    if [[ ${#plugin_files[@]} -eq 0 ]]; then
        _warn "No installable plugin files found"
        return 1
    fi

    _trace "Reading available plugins config..."
    _trace "Callback Function: $callback_func"
    _trace "Plugin registry files ${plugin_files[@]}"

    [[ -n "$match_name" ]] && _debug "Matching Plugin Name: '$match_name' (first occurrence)"
    _debug "Default branch/commit (if not specified in INI): $default_commit"

    declare -A plugin_section_details # Reusable associative array for plugin data
    declare -A plugin_details # Reusable associative array for plugin data


    local __process_plugin_from_file
    __process_plugin_from_file() {
        local current_ini_file="$1"
        local current_plugin_name="$2"

        _tm::util::parse::plugin_name plugin_details "$current_plugin_name"
        _tm::file::ini::read_section plugin_section_details "$current_ini_file" "$current_plugin_name" 

        local ini_repo="${plugin_section_details[repo]}"
        local ini_commit="${plugin_section_details[commit]}"
        local plugin_desc="${plugin_section_details[desc]}"
        local run_mode="${plugin_section_details[run-mode]:-direct}"

        if [[ -z "$ini_commit" ]]; then
            ini_commit="$default_commit"
        fi
        
        if [[ -z "$ini_repo" ]]; then
            _warn "Plugin '$current_plugin_name' from '$current_ini_file' has incomplete configuration (repo). Skipping."
            return
        fi

        # make the details from the config file available
        plugin_details[repo]="$ini_repo"
        plugin_details[commit]="$ini_commit"
        plugin_details[branch]="$ini_commit"
        plugin_details[desc]="$plugin_desc"
        plugin_details[run_mode]="$run_mode"
        
        _trace "Calling callback '$callback_func' for: '${plugin_details[qname]}' (dir: '${plugin_details[install_dir]}', repo: $ini_repo, commit: $ini_commit, desc: $plugin_desc)"
        "$callback_func" plugin_details
    }

    local found_match=0
    for ini_file in "${plugin_files[@]}"; do
        _debug "Processing INI file: $ini_file"
        if [[ ! -f "$ini_file" || ! -r "$ini_file" ]]; then
            _warn "INI file not found or not readable: '$ini_file'. Skipping."
            continue
        fi

        if [[ -n "$match_name" ]]; then
            if _tm::file::ini::has_section "$ini_file" "$match_name"; then
                _debug "Found matched plugin '$match_name' in '$ini_file'."
                __process_plugin_from_file "$ini_file" "$match_name" 
                found_match=1
                break # Stop after first match
            else
                _debug "No match for '$match_name' in '$ini_file'."
            fi
        else
            # No match name, process all plugins in this file
            declare -a all_plugin_names_in_file
            _tm::file::ini::read_sections all_plugin_names_in_file "$ini_file" 
            _debug "Found ${#all_plugin_names_in_file[@]} plugins in '$ini_file'."
            for name_in_file in "${all_plugin_names_in_file[@]}"; do
                __process_plugin_from_file "$ini_file" "$name_in_file"
            done
        fi
    done
    
    if [[ -n "$match_name" && "$found_match" -eq 0 ]]; then
         _warn "Matched plugin '$match_name' not found in any of the specified configuration files."
    fi

    _debug "...finished reading plugins."
    return 0
}
