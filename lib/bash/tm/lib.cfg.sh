
if command -v _tm::cfg::get &>/dev/null; then
  return
fi

# This script provides functions for getting and setting global/tm/user/plugin-specific
# configuration values. Configuration is typically stored in per-plugin
# '.env' files within the $TM_PLUGINS_CFG_DIR.
# Functions support reading, writing, and interactively prompting for
# configuration keys.
#

_tm::source::include @tm/lib.util.sh @tm/lib.file.env.sh

_cfg_get() {
    _tm::cfg::get "$@"
}

_cfg_load() {
    _tm::cfg::load "$@"
}

_tm::cfg::get() {
  _tm::cfg::__process 1 "$@"
}

_tm::cfg::load() {
  _tm::cfg::__process 0 "$@"
}

_tm::cfg::__process() {
    local is_get=$1
    shift
    local plugin_id="${TM_PLUGIN_ID:-$__TM_PLUGIN_ID}"
    _tm::cfg::__load_cfg_once "$plugin_id"
    if [[ $# == 0 ]]; then 
        if [[ $is_get == 1 ]]; then
          _fail "No config keys provided"
        fi
        return # skip if no options supplied, we're just loading
    fi
    declare -A args
    # Using --opts-* to capture the command and its arguments after '--'
    _tm::args::parse \
        --opt-this      "|       |flag|group=plugin    |default=1|desc=When set, auto detect plugin name from 'TM_PLUGIN_NAME' env variable. This is set via the plugin wrapper scripts" \
        --opt-tm        "|       |flag|group=plugin    |desc=When set, use tool manager cfg" \
        --opt-plugin    "|short=p|    |group=plugin    |value=QUAILIFIED-PLUGIN-NAME|desc=The plugin to get the config for|example='my-ns:some-plugin','tm-install'" \
        --opt-prompt    "|       |flag|group=behaviour |desc=Whether to show the prompt if the value does not exist|" \
        --opt-no-prompt "|short=n|flag|group=behaviour |desc=(todo)If set, and the value is not set, silently ignore it, and don't show the config editor" \
        --opt-required  "|short=r|flag|group=behaviour |desc=Whether the value is required. If no value, and required, then will prompt for it, or if in silent mode, fail. Default is off" \
        --opt-allowed   "|       |    |group=validation|desc=Allowed values|multi" \
        --opt-default   "|short=d|    |value=DEFAULT-VALUE|desc=The default value if not set" \
        --opt-keys      "|short=k|remainder|long=key|value=KEY|desc=The key of the value to get|multi" \
        --opt-all       "|       |flag|desc=Get all the keys and values|" \
        --result args \
        -- "$@"

    if [[ -n "${args[all]:-}" ]]; then
      _todo "print all the variables for this plugin"
      echo "$(_tm::cfg::__load_cfg "$plugin_id";printenv)"

      return 0
    fi

    local prompt=1
    if [[ "${args[prompt]}" == "1" ]]; then
         prompt=1
    fi
    if [[ "${args['no-prompt']}" == "1" ]]; then
        prompt=0
    fi
    local missing_keys=()
    local value
    local default_value="${args[default]}"

    IFS=' ' read -ra keys <<< "${args[keys]}"
    _trace "checking keys: '${keys[@]}'"
    for key in "${keys[@]}"; do
        _trace "checking key '$key'"
        value="${!key:-}"
        if [[ "${value:-}" == "" ]]; then
            # key missing, load cfg
            # find env files
            missing_keys+=("$key")
            _trace "missing key:$key"
        else
          if [[ $is_get == 1 ]]; then
            echo "$value"
          fi
        fi
    done

    if [[ ${#missing_keys[@]} == 0 ]]; then # no missing keys
        return
    fi

    declare -A plugin=()
    _tm::util::parse::plugin_id plugin "$plugin_id"

    local plugin_custom_cfg_file="$TM_PLUGINS_CFG_DIR/${plugin[qpath]}/cfg.sh"
    for key in "${missing_keys[@]}"; do
        if [[ "$prompt" == '0' ]] ; then
            if [[ -n "$default_value" ]]; then # just use the default
                eval "export $key=\"$default_value\""
                if [[ $is_get == 1 ]]; then
                  echo "$default_value"
                fi
                continue
            else
              _fail "No cfg with key '$key' set for plugin '${plugin[qpath]}', no default supplied, and the '--no-prompt' option is set"
            fi
        fi
        
        if tty -s; then
            #in interactive mode
            :
        else
            _fail "No cfg with key '$key' set for plugin '${plugin[name]}', and no default supplied. Not in interactive shell so can't prompt"
        fi
        _tm::cfg::__prompt_for_key "${plugin[name]}" "${plugin[qpath]}" "$plugin_custom_cfg_file" "$key" "$default_value" 
        # ensure the new key is rad by the caller
       
        if [[ $is_get == 1 ]]; then
          echo "${!key:-}"
        fi
    done
    _tm::cfg::__load_cfg "$plugin_id"
}


_tm::cfg::__prompt_for_key() {
    local plugin_name="$1"
    local qpath="$2"
    local cfg_file="$3"
    local cfg_key="$4"
    local default_value="$5"
    
    # Prompt to stderr to avoid contaminating stdout [8]
    _tm::log::println "Environment variable '$cfg_key' not set for plugin '$plugin_name'" 
    _tm::log::println "  Setting value in '$cfg_file' (qpath '$qpath')"

    #_info "env=$(env | sort)"
    local key_value=""
    while [[ -z "$key_value" ]]; do
        >&2 echo -n "  Value for $cfg_key: "
        # We force a tty so it down't affect other read calls when nested
        if [[ -z "$default_value" ]]; then
            read -e -r key_value </dev/tty
        else
            read -e -r -i "$default_value" key_value </dev/tty
        fi
    done

    # write the config to disk
    _tm::cfg::__set_key_value_in_file "$cfg_file" "$cfg_key" "$key_value"

    _debug "updated: $cfg_file"
}

#
# List the plugin config files, in order, with last winning
#
_tm::cfg::get_config_files() {
    local qualified_name="$1"

    if [[ -z "$qualified_name" ]]; then
        _fail "No plugin name supplied."
    fi

    local -A parts=()
    _tm::util::parse::plugin_name parts "$qualified_name"
    
    local files=()
    _tm::cfg::__add_config_files files "${parts[name]}" "${parts[qpath]}"
    echo "${files[@]}"
}

_tm::cfg::__add_config_files() {
    local -n array_config_files="$1"
    local plugin_name="$2"
    local qpath="$3"

    array_config_files+=("$TM_PLUGINS_INSTALL_DIR/${plugin_name}/.env") # plugin provided
    array_config_files+=("$TM_PLUGINS_INSTALL_DIR/${plugin_name}/.bashrc") # plugin provided .bashrc
    array_config_files+=("$TM_PLUGINS_CFG_DIR/.env") # shared between all the plugins
    array_config_files+=("$TM_PLUGINS_CFG_DIR/cfg.sh") # shared between all the plugins
    array_config_files+=("$TM_PLUGINS_CFG_DIR/${qpath}/.env") # config for this plugin instance
    array_config_files+=("$TM_PLUGINS_CFG_DIR/${qpath}/cfg.sh") # config for this plugin instance    
}

# --- Set a configuration value for a plugin ---
# Usage: _tm::cfg::set_value <qualified_name> <cfg_key> [key_value]
#
# Arguments:
#   $1 (qualified_name): The qualified name of the plugin.
#   $2 (cfg_key): The configuration key to set (case-insensitive, will be uppercased).
#   $3 (key_value, optional): The value to set. If not provided and in an interactive TTY,
#        prompts the user for the value, suggesting the current value if available.
#
# Behavior:
#   - Parses plugin name and prefix.
#   - Checks if the plugin is installed (unless it's the core __TM_NAME).
#   - If key_value is not provided and in a TTY, prompts for it.
#   - Writes the cfg_key="key_value" to the plugin's custom config file,
#     updating if the key exists or appending if new.
#   - Fails if required arguments are missing, plugin not installed, or not in TTY
#     when prompting is needed but no value is supplied.
#
# Example:
#   _tm::cfg::set_value "myplugin" "MY_PLUGIN_API_KEY" "new_api_key_value"
#   _tm::cfg::set_value "myplugin" "MY_PLUGIN_OTHER_SETTING" # Will prompt
#
_tm::cfg::set_value(){
    local qualified_name="${1:-}"
    local cfg_key="${2:-}"
    local key_value="${3:-}"

    if [[ -z "$qualified_name" ]]; then
        _fail "No plugin name supplied"
    fi
    if [[ -z "$cfg_key" ]]; then
        _fail "No cfg key supplied"
    fi

    local -A parts=()
    _tm::util::parse::plugin_name parts "$qualified_name"
    local plugin_name="${parts[name]}"
    local prefix="${parts[prefix]}"
    local qpath="${parts[qpath]}"
    
    local plugin_dir="$TM_PLUGINS_INSTALL_DIR/$plugin_name"
    if [[ ! "$plugin_name" == "$__TM_NAME" ]] && [[ ! -d "$plugin_dir" ]]; then
        _fail "No plugin '$plugin_name' installed. Expected dir '$plugin_dir'"
    fi
    
    cfg_key="${cfg_key^^}" # uppercase config keys
    
    local plugin_custom_cfg_file="$TM_PLUGINS_CFG_DIR/${qpath}/.env"
    _info "  Setting value in '$plugin_custom_cfg_file'"
    local current_value="${!cfg_key:-}"
    if [[ -f "$plugin_custom_cfg_file" ]]; then
        source "$plugin_custom_cfg_file"
        current_value="${!cfg_key:-}"
    fi

    if tty -s; then
        #in interactive mode
        :
    else
        _fail "No value provided for cfg '$cfg_key' for plugin '$plugin_name'. Not in interactive shell so can't prompt"
    fi

    while [[ -z "$key_value" ]]; do
         >&2 echo -n "  Value for $cfg_key:"
        # We force a tty so it down't affect other read calls when nested
        if [[ -z "$current_value" ]]; then
            read -e -r key_value </dev/tty
        else
            read -e -r -i "$current_value" key_value </dev/tty
        fi
    done
    
    # write the config to disk
    _tm::cfg::__set_key_value_in_file "$plugin_custom_cfg_file" "$cfg_key" "$key_value"
    _info "  updated: $plugin_custom_cfg_file"
}

# --- Helper function to set a key-value pair in a specific config file ---
# Usage: _tm::cfg::__set_key_value_in_file <file_path> <cfg_key> <value>
#
# Arguments:
#   $1 (file_path): The full path to the configuration file.
#   $2 (cfg_key): The configuration key (expected to be already uppercased).
#   $3 (value): The value to set for the key.
#
# Behavior:
#   - If the file exists and contains the key, updates the line using sed.
#   - If the file exists but does not contain the key, appends 'key="value"' to the file.
#   - If the file does not exist, creates the directory path if needed, touches the file,
#     and then appends 'key="value"'.
#
# Note:
#   - This function directly modifies the specified file.
#   - `sed -i` is used for in-place editing. Error output from sed is suppressed.
#

_tm::cfg::__set_key_value_in_file(){
    local file="$1"
    local cfg_key="$2"
    local value="$3"

    if [[ -f "$file" ]]; then # Check against the passed-in file argument
        if grep -q "^${cfg_key}=" "$file"; then # Ensure key is anchored and properly quoted in grep
            # existing key, replace value
            # Using a temporary variable for the replacement string to handle potential special characters in value
            local replacement
            printf -v replacement '%s="%s"' "$cfg_key" "$value"
            sed -i "/^${cfg_key}=/c ${replacement}" "$file" 2>/dev/null
        else
            # no existing key, append the new assignment at the end
            printf '%s="%s"\n' "$cfg_key" "$value" >> "$file"
        fi
    else
        # file does not exist, create it and append
        mkdir -p "$(dirname "$file")" # Ensure directory exists
        # touch "$file" # Not strictly necessary as echo >> will create it
        printf '%s="%s"\n' "$cfg_key" "$value" >> "$file"
    fi
}

_tm::cfg::__load_cfg_once(){
    local plugin_id="$1"
    if [[ -z "${__TM_SCRIPT_CFG_LOADED:-}" ]]; then # only load once on demand
        __TM_SCRIPT_CFG_LOADED=1
        _tm::cfg::__load_cfg "$plugin_id"
    fi
}

_tm::cfg::__load_cfg(){
    local plugin_id="$1"
    local -A plugin=()
    _tm::util::parse::plugin_id plugin "$plugin_id"
    # bashrc to load
    #local cfg_bashrc="$TM_CACHE_DIR/merged-config/${plugin[qpath]}.env"
    local env_files=() # config files bashrc is generated from
    _tm::cfg::__add_config_files env_files "${plugin[name]}" "${plugin[qpath]}"
    #_debug "loading $cfg_bashrc from ${env_files[@]}"
    _tm::cfg::__source_cfg "${plugin[key]}" "${env_files[@]}"
}

#
# This function reads/generates the output bashrc file and then sources it.
# It determines whether a regeneration is needed based on changes in input .env files.
#
# Usage: _tm::cfg::__source_cfg <output_bashrc_file> <env_file1> [<env_file2> ...]
# Example: _tm::cfg::__source_cfg my_app_env.sh .env.defaults .env.common .env.local
_tm::cfg::__source_cfg() {
  # Check if at least two arguments (output_bashrc_file + at least one env file) are provided
  if (( $# < 2 )); then
    _fail "Usage: _tm::cfg::__source_cfg plugin_key <env_file1> [<env_file2> ...]"
  fi
  local qpath="$1"

  #local output_bashrc_file="$1"
  shift # Remove the output_bashrc_file from the arguments list
  local env_files=("$@") # All remaining arguments are the .env files

  # Calculate a combined checksum of all input .env files
  local current_checksum=""
  for f in "${env_files[@]}"; do
    if [[ -f "$f" ]]; then
      current_checksum+=$(stat -c %Y "$f") # Using modification time for quick check
    else
      current_checksum+="NF" # Mark as Not Found if file is missing
    fi
  done
  current_checksum=$(echo "$current_checksum" | md5sum | awk '{print $1}') # Hash concatenated mtimes
  # make the checksum part of the generated path
  local base_config_dir="$TM_CACHE_DIR/merged-config"
  local output_bashrc_file="$base_config_dir/${qpath}.cfg.sh.${current_checksum}"
  _debug "using merged config '$output_bashrc_file'"
  if [[  -f "$output_bashrc_file" ]]; then
    _debug "sourcing '$output_bashrc_file' into current shell"
    source "$output_bashrc_file"
    return
  fi
  # we needs generation
  local -a previous_bashrcs=() # collect old config
  mapfile -t previous_bashrcs < <(find "$base_config_dir" -type f \( -name "${qpath}.cfg.sh.*" -prune -o -print \))

  _tm::cfg::env::__generate_cfg_bashrc "$output_bashrc_file" "${env_files[@]}"
  source "$output_bashrc_file"

  # remove the old merged config files
  for file in "${previous_bashrcs[@]}"; do
  _trace "removing previous merged config:'$file'"
    rm -f "$file" || _warn "Couldn't delete old merged config '$file', ignoring"
  done
}

#
# This function encapsulates the logic for parsing .env files and generating
# the output bashrc file. It does *not* perform checksum checks itself.
# It expects the output file path as $1 and the list of env files as "$@" (shifted).
#
# Usage: _cfg::env::generate_core <output_file> <env_file1> [<env_file2> ...]
_tm::cfg::env::__generate_cfg_bashrc() {
  local output_file="$1"
  shift # Remove output_file from arguments
  local env_files=("$@") # Remaining arguments are the .env files
  _debug "generating '$output_file' from ${env_files[*]}"

  mkdir -p "$(dirname "$output_file")"
  # Start a subshell for isolation during generation.
  # All `export` commands and variable processing happen here,
  # preventing them from affecting the main shell's environment.
  (
    # write header
    for env_file in "${env_files[@]}"; do
        echo "# include file $env_file"
    done
    # Loop through each .env file in the specified order
    local -A map=() # key/values found
    local -a keys=() # order keys found
    local key
    local value
    for env_file in "${env_files[@]}"; do
      if [[ -f "$env_file" ]]; then
        _debug "reading: $env_file"
        if [[ "$env_file" == *".bashrc" ]]; then
            # then just source it
            echo "source '$env_file'"
        else
            # Read the file line by line, filtering out comments and empty lines efficiently
            while IFS= read -r line; do
              # Skip lines that are empty or comments
              [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

              # Split the line at the first '=' into key and value
              key="${line%%=*}"
              value="${line#*=}"

              # remove the 'EXPORT' statement if any
              key="${key##EXPORT*}"

              # Trim leading/trailing whitespace from the key using Bash parameter expansion
              key="${key##*( )}"
              key="${key%%*( )}"

              # Remove outer quotes (single or double) from the value using sed
              value=$(echo "$value" | sed -E "s/^(['\"])(.*)\1$/\2/")

              # # Perform variable expansion (e.g., $HOME, ${VAR_FROM_PREVIOUS_FILE}) using envsubst.
              # local expanded_value
              # expanded_value=$(envsubst <<< "$value")


              # Store the key in our associative array to track which variables we set.
              if [[ -z "${map[$key]:-}" ]]; then
                  # Key is not yet in the associative array, so add it and the key to the ordered list
                  map[$key]="$value"
                  keys+=("$key")
              else
                  # Key already exists, update the value if needed (or handle as desired)
                  map[$key]="$value"
              fi
            done < <(grep -vE '^\s*#|^\s*$' "$env_file")
        fi
      else
        _debug "config file not found: $env_file (skipping)"
      fi
    done

    # Print all declared variables in a format suitable for 'export'
    # 'printf %q' properly quotes variable names and values for re-evaluation by Bash.
    for key in "${keys[@]}"; do
      value="${map[$key]}"
      _finest "export ${key}=\"${value}"
      printf "export %q=\"%q\"\n" "$key" "${value}"
    done

  ) > "$output_file" # Redirect all stdout from the subshell to the bashrc file
  
  _debug "successfully generated '$output_file'"
  return 0
}
