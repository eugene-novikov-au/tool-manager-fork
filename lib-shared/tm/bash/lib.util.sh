
## trap Ctrl+c to kill the sub processes. Ensures any background processes are killed
# Set up signal traps to clean up child processes
#
# Behavior:
#   - Traps SIGINT, SIGTERM and EXIT
#   - Kills all child processes when triggered
#
# Usage:
#   _trap_sigs
#
_trap_sigs() {
  trap "trap - SIGTERM && kill -- -$$ &>/dev/null" SIGINT SIGTERM EXIT
}

# Log an error message and exit with status 1
#
# Args:
#   $1 - Error message
#
# Behavior:
#   - Logs error message
#   - Exits script with status 1
#
# Usage:
#   _fail "Critical error occurred"
#
_fail() {
  # this function is early in the file, as the top most functions need access to it
  _err "ERROR! $*"
  _is_trace && _trace "$(_tm::log::stacktrace)"
  exit 1
}

# Log an error message and exit with status 1
#
# Args:
#   $@ - Error message
#
# Behavior:
#   - Logs error message
#   - Exits script with status 1
#
# Usage:
#   _die "Fatal error occurred"
#
_die() {
  _err "$@"
  _is_trace && _trace "$(_tm::log::stacktrace)"
  exit 1
}

# Prompt user for a yes or no (yY* or nN*), and keep prompting until they choose one or the other (or ctrl+c).
#
# The exist code determines whether it was successful
#
# Args:
#   $1 - Prompt text ( ' [yn]: ' will appended to it)
#   $2 - Default value (optional). Can be [yYtT1]* or [nN]* (e.g. y, yes, YES, Yes,Y, true, 1, t ... same goes for no)
#
# Usage:
#   if _read_is_confirm "Eat pie?" yn; then
#       echo "pies are great!"
#   fi
#   if _read_is_confirm "Eat pie?" yn "n"; then # with a  default value
#       echo "pies are great!"
#   fi
#
_read_is_confirm(){
    local prompt="${1}"
    local default_val="${2:-}"
    local yn=''
    case "${default_val}" in
      [yYtT]*|1)
        prompt+=" [Yn]"
        default_val='y'
      ;;
      [nNFf]*|0)
        prompt+=" [yN]"
        default_val='n'
      ;;
      *)
        prompt+=" [yn]"
        default_val=''
      ;;
    esac
    _read_yn "$prompt" yn "${default_val}"
    if [[ "${yn}" == 'y' ]]; then
      true
    else
      false
    fi
}
# Prompt user for a yes or no ([yYtT]*|1) or [nNfF]*|0, and keep prompting until they choose one or the other (or ctrl+c)
#
# It will set the value to either 'y' or 'n' (lowercase)
#
# Args:
#   $1 - Prompt text
#   $2 - Variable name to store result
#   $3 - Default value (optional)
#
# Usage:
#   _read_yn "Eat pie? [yn]: " yn
#   _read_yn "Eat pie? [yN]: " yn "n"
#
_read_yn(){
    local prompt="${1}"
    local -n yn_ref="${2}"
    local default_val="${3:-}"

    while true; do
      _read "$prompt: " yn_ref "$default_val"
      case "${yn_ref}" in
        [yYtT]*|1)
          yn_ref='y'
          break
          ;;
        [nNFf]*|0)
          yn_ref='n'
          break
          ;;
      esac
    done
}

# Prompt user for input with a default value, and keep prompting until a non empty value is provided (or ctrl+c)
#
# Args:
#   $1 - Prompt text
#   $2 - Variable name to store result
#   $3 - Default value (optional)
#
# Usage:
#   _read_not_empty "Food: " choice
#   _read_not_empty "Food: " choice "pie"

_read_not_empty(){
    local prompt="${1}"
    local -n value_not_empty_ref="${2}"
    local default_val="${3:-}"

    while [[ -z "${value_not_empty_ref}"  ]]; do
        _read "$prompt:" value_not_empty_ref "${default_val}"
    done
}
# Prompt user for input with a default value
#
# Args:
#   $1 - Prompt text
#   $2 - Variable name to store result
#   $3 - Default value (optional)
#
# Behavior:
#   - Forces tty input to avoid conflicts with nested reads
#   - Sets specified variable with user input
#
# Usage:
#   _read "Continue? [Y/n]" choice "Y"
#
_read() {
  #  
  # args:
  #    $1 = the text to show. E.g. 'Launch rocket?'
  #    $2 = the variable to assign. E.g. yn
  #    $3 (optional) = the default value. E.g. 'n'
  #
  # We force a tty so it down't affect other read calls when nested
  # 
  # Example:
  #    _read "Do something?: [Yn]" choice
  #    case $choice in
  #       [Yy]* | '')
  #         ...run some command
  #      ;;
  #      [Nn]*)
  #         ... run some other command
  #      ;;
  #    esac
  read -e -p "$1" -i "${3:-}" $2 </dev/tty
}

# a silent pushd that doesn't print the dir to stdout
# Silent pushd that suppresses directory output
#
# Args:
#   $@ - Directory path(s) to push
#
# Behavior:
#   - Changes directory without printing to stdout
#
# Usage:
#   _pushd /path/to/dir
#
_pushd() {
  pushd "$@" >/dev/null
}

# a silent popd that doesn't print the dir to stdout
# Silent popd that suppresses directory output
#
# Behavior:
#   - Returns to previous directory without printing to stdout
#
# Usage:
#   _popd
#
_popd() {
  popd >/dev/null
}

# a grep which doesn't return a non-zero exit status on match failure
# Safe grep that always returns success
#
# Args:
#   $@ - Standard grep arguments
#
# Behavior:
#   - Runs grep but returns 0 even if no matches found
#
# Usage:
#   _grep pattern file.txt
#
_grep() {
    grep "$@" || true
}

# Enhanced touch that creates parent directories
#
# Args:
#   $1 - File path to create
#
# Behavior:
#   - Creates parent directories if needed
#   - Creates empty file
#
# Usage:
#   _touch /path/to/new/file.txt
#
_touch() {
  # a better touch, also creates any parent dirs
  mkdir -p "$(dirname "$1")" && touch "$1"
}

_realpath() {
  # TODO: Cache the realpath check result?
  if command -v realpath &> /dev/null; then
    # Attempt to resolve the path, suppress stderr, and check exit code
    local resolved_path
    resolved_path=$(realpath "$@" 2>/dev/null)
    if [[ $? -eq 0 && -n "$resolved_path" ]]; then
      echo "$resolved_path"
    else
      # realpath failed or returned empty (e.g. path doesn't exist), return original path
      echo "$1" # Return the first argument (original path)
    fi
  else
    # _warn "realpath command not found, using fallback implementation"
    local path="$1"
    
    # On macOS, use python as fallback
    if [[ "$OSTYPE" == "darwin"* ]]; then
      _warn "For better performance on macOS, install realpath using: brew install coreutils"
      _python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$path"
    # On Linux/Unix, try readlink -f
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
      readlink -f "$path"
    # On Windows (Git Bash/Cygwin), use cygpath if available
    elif [[ "$OSTYPE" == "cygwin" || "$OSTYPE" == "msys" ]]; then
      if command -v cygpath &> /dev/null; then
        cygpath -w "$path"
      else
        _err "realpath not available. Please install it:"
        _err "  Linux: sudo apt-get install coreutils"
        _err "  macOS: brew install coreutils"
        _err "  Windows: Install Git for Windows or Cygwin"
        return 1
      fi
    else
      _err "Unsupported OS for realpath fallback"
      return 1
    fi
  fi
}

# Executes a python script, preferring python3 if available, otherwise python.
# Fails if neither is found.
# Args: $@ - Arguments to pass to the python interpreter.
_python(){
  if command -v python3 &> /dev/null; then
    python3 "$@"
  elif command -v python &> /dev/null; then
    python "$@"
  else
    _fail "python3/python is not installed"
  fi
}

# Executes a python script using python3.
# Fails if python3 is not found.
# Args: $@ - Arguments to pass to the python3 interpreter.
_python3(){
  if command -v python3 &> /dev/null; then
    python3 "$@"
  else
    _fail "python3 is not installed"
  fi
}

#
# Fails with an error message if the given command is not found
# 
# $1 - (required) the command to test for
# $2 - (optional) a help message appended to the end of the error message
#
_fail_if_not_installed(){
  local cmd="${1}"
  if [[ -n "$cmd" ]]; then
    if command -v $1 &> /dev/null; then
      return
    fi
  fi

  local help=""
  if [[ -n "${2:-}" ]]; then
    help=" $2."
  fi
  if _is_debug; then
    help+=" Looked in paths:$(echo $PATH)"
  fi
  _fail "Command '$1' not found.$help"      

}

# TODO:
#
# user facing function
#
# Ensures a specific plugin is loaded.
# Args:
#   $1 - The name of the plugin (expects it to be in $TM_PLUGINS_INSTALL_DIR).
_require_plugin() {
  _debug "require plugin:$1"
  local -A require_plugin
  _tm::util::parse:plugin require_plugin "$1"
  _tm::plugin::load require_plugin
}


# print normal or associative array
_tm::util::print_array(){
  local -n array="$1"

  #if declare -p "$1" 2>/dev/null | grep -q 'declare -A'; then
       # It is an associative array
      echo -n "$1( "
      for key in "${!array[@]}"; do
        echo -n "[$key]='${array[$key]}' "
      done
      echo ")"
    # else
    #     # normal array?
    #     echo -n "$1( "
    #     for key in "${array[@]}"; do
    #       echo -n "'$key' "
    #     done
    #     echo ")"
    # fi
}

#
# _tm::util::parse::plugin
#
# Parses a plugin identifier string (either a qualified name or a full ID) into an
# associative array containing its components (vendor, name, version, prefix, etc.).
# This function acts as a dispatcher, calling either `_tm::util::parse::plugin_id`
# or `_tm::util::parse::plugin_name` based on the format of the input string.
#
# Args:
#   $1 - result_array_name: The name of the associative array to populate with parsed plugin details.
#   $2 - plugin_identifier: The string to parse. This can be:
#                           - A full plugin ID (e.g., "tm:plugin:<vendor>:<name>:<version>:<prefix>")
#                           - A qualified plugin name (e.g., "prefix:bar", "vendor/bar@123", "prefix__bar")
#
# Populates the `result_array_name` with the following keys:
#   - `vendor`: The plugin's vendor.
#   - `name`: The plugin's base name.
#   - `version`: The plugin's version.
#   - `prefix`: The plugin's prefix.
#   - `qname`: The qualified name (e.g., "prefix:vendor/name@version").
#   - `qpath`: The qualified file system path segment (e.g., "vendor/name__prefix").
#   - `key`: A unique key for caching.
#   - `id`: The full plugin ID string.
#   - `install_dir`: The absolute path to the plugin's installation directory.
#   - `enabled_dir`: The absolute path to the plugin's enabled symlink directory.
#   - `cfg_spec`: Path to the plugin's configuration specification file.
#   - `cfg_dir`: Path to the plugin's configuration directory.
#   - `cfg_sh`: Path to the plugin's shell configuration file.
#   - `tm`: Boolean, true if this is the tool-manager plugin itself.
#
# Usage:
#   declare -A my_plugin_info
#   _tm::util::parse::plugin my_plugin_info "myvendor/myplugin@1.0.0__myprefix"
#   _tm::util::parse::plugin my_plugin_info "tm:plugin:myvendor:myplugin:1.0.0:myprefix"
#
_tm::util::parse::plugin(){
  _finest "_tm::util::parse::plugin : $2"
  if [[ "$2" == "tm:plugin:"* ]]; then
    _tm::util::parse::plugin_id "$@"
  else
    _tm::util::parse::plugin_name "$@"
  fi
}

#
# Parse a qualified plugin name into an associative array
#
# $1 - the name of the associative array to put the results in
# $2 - the plugin name
#
# Usage:
#  _tm::util::parse::plugin_name parts "prefix:bar"
#  _tm::util::parse::plugin_name parts "prefix:vendor/bar@123"
#  _tm::util::parse::plugin_name parts "prefix__bar"

#
_tm::util::parse::plugin_name(){
  local -n result_name="$1" # expect it to be an associative array
  result_name=()
  local parse_name="$2"
  _finest "_tm::util::parse::plugin_name : '$parse_name'"

  local prefix name version vendor
  prefix=''
  name=''
  version=''
  vendor=''
  # Determine the separator used in the plugin name to correctly parse it.
  # The order of checks is important: first check for the primary prefix-name separator,
  # then the directory-based separator.
  if [[ "$parse_name" == *"$__TM_SEP_PREFIX_NAME"* ]]; then
    IFS="$__TM_SEP_PREFIX_NAME" read -r prefix name <<< "$parse_name"
  elif [[ "$parse_name" == *"$__TM_SEP_PREFIX_DIR"* ]]; then
    IFS="$__TM_SEP_PREFIX_DIR" read -r prefix name <<< "$parse_name"
    # If the directory separator was used, and the name starts with an underscore,
    # remove that underscore. This handles a specific naming convention.
    if [[ "$name" == '_'* ]]; then
      name="${name##_}"
    fi
  else
    # If no prefix separator is found, the entire string is considered the name,
    # and there is no prefix.
    name="$parse_name"
    prefix=""
  fi

  # If after parsing, the 'name' is empty, it means the original 'prefix' was
  # actually the name, and there was no prefix.
  if [[ -z "$name" ]]; then
    name="$prefix"
    prefix=""
  fi

  # Check for vendor information (indicated by a slash '/').
  # If found, split into vendor and name.
  if [[ "$name" == *'/'* ]]; then
    IFS="/" read -r vendor name <<< "$name"
    # If 'name' is empty after splitting, it means the 'vendor' was the actual name.
    if [[ -z "$name" ]]; then
      name="$vendor"
      vendor=""
    fi
  fi

  # Check for version information (indicated by an '@' symbol).
  # If found, split into name and version.
  if [[ "$name" == *'@'* ]]; then
    IFS="@" read -r name version <<< "$name"
    # If 'name' is empty after splitting, it means the 'version' was the actual name.
    if [[ -z "$name" ]]; then
      name="$version"
      version="" # Reset version as it was actually the name
    fi
  fi

  if [[ -z "$name" ]]; then
    _fail "Invalid plugin name format.Is empty. From input '${parse_name}'"
  fi

  if [[ -n "$name" && ! "$name" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    _fail "Invalid plugin name format. Use lowercase letters, numbers, hyphens. Start with letter/number. Instead got '${name}' from input '${parse_name}'"
  fi

  if [[ -n "$vendor" && ! "$vendor" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    _fail "Invalid plugin vendor format. Use lowercase letters, numbers, hyphens. Start with letter/number. Instead got '${vendor}' from input '${parse_name}'"
  fi

  if [[ -n "$version" && ! "$version" =~ ^[a-z0-9][a-z0-9.-]*$ ]]; then
    _fail "Invalid plugin vendor format. Use lowercase letters, numbers, hypens, dots. Start with letter/number. Instead got '${version}' from input '${parse_name}'"
  fi

  result_name[vendor]="$vendor"
  result_name[name]="$name"
  result_name[version]="$version"
  result_name[prefix]="$prefix"

  _tm::util::parse::__set_plugin_derived_vars result_name

  if _is_finest; then
    _finest "parsed to: $(_tm::util::print_array result_name)"
  fi

  return 0
}


# Parses a plugin id string into an associative array
#
# $1 - the name of the associative array to put the results in
# $2 - the plugin id
#
# Behavior:
#   Parses a plugin id string into an associative array.
#
# Usage:
#  _tm::util::parse::plugin_id parts "tm:plugin:<space>:<vendor>:<name>:<version>:<prefix>"
#
_tm::util::parse::plugin_id(){
  local -n result_id="$1" # expect it to be an associative array
  result_id=()
  local parse_id="$2"
  _finest "_tm::util::parse::plugin_id : '$parse_id'"
  # Read the id into an array, respecting empty fields
  local -a id_parts=()
  IFS=':' read -r -a id_parts <<< "$parse_id"

  if [[ "${id_parts[0]:-}" != "tm" ]]; then
    _fail "Not a valid plugin id. expected 'tm:plugin:<space>:<vendor>:<name>:<version>:<prefix>', but got '$parse_id'"
  fi
  if [[ "${id_parts[1]:-}" != "plugin" ]]; then
    _fail "Not a valid plugin id. expected 'tm:plugin:<space>:<vendor>:<name>:<version>:<prefix>', but got '$parse_id'"
  fi
  local space="${id_parts[2]:-}"
  local vendor="${id_parts[3]:-}"
  local name="${id_parts[4]}"
  local version="${id_parts[5]:-}"
  local prefix="${id_parts[6]:-}"

  if [[ -z "$name" ]]; then
    _fail "Invalid plugin name format.Is empty. From id '${parse_id}'"
  fi

  if [[ -n "$name" && ! "$name" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    _fail "Invalid plugin name format. Use lowercase letters, numbers, hyphens. Start with letter/number. Instead got '${name}' from id '${parse_id}'"
  fi

  if [[ -n "$vendor" && ! "$vendor" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    _fail "Invalid plugin vendor format. Use lowercase letters, numbers, hyphens. Start with letter/number. Instead got '${vendor}' from id '${parse_id}'"
  fi

  if [[ -n "$version" && ! "$version" =~ ^[a-z0-9][a-z0-9.-]*$ ]]; then
    _fail "Invalid plugin vendor format. Use lowercase letters, numbers, hypens, dots. Start with letter/number. Instead got '${version}' from id '${parse_id}'"
  fi


  result_id[vendor]="$vendor"
  result_id[name]="$name"
  result_id[version]="$version"
  result_id[prefix]="$prefix"

  _tm::util::parse::__set_plugin_derived_vars result_id

  if _is_finest; then
    _finest "$(_tm::util::print_array result_id)"
  fi
}


#
# Parse the qpath into a plugin associative array
#
# $1 - the plugin associative array
# $2 - the qpath (qualified path)
#
_tm::util::parse::plugin_enabled_dir(){
  local -n result="$1" # expect it to be an associative array
  result=()

  local dir_name="$2"
  # IFD can't do multiple chars, so convert '__' to newlines and then parse
  # the format is vendor__name__prefix, where prefix is optional
   IFS=$'\n' read -d '' -r vendor name prefix <<< "${dir_name//__/$'\n'}" || true

  local version="${id_parts[4]:-}"

  result[vendor]="$vendor"
  result[name]="$name"
  result[version]=""
  result[prefix]="$prefix"

  _tm::util::parse::__set_plugin_derived_vars result

  if _is_finest; then
    _finest "$(_tm::util::print_array result)"
  fi

}

#
# Set the calculated derived array variables
#
# $1 - the plugin associative array
#
_tm::util::parse::__set_plugin_derived_vars(){
  local -n result_derived="$1" # expect it to be an associative array

  local name="${result_derived[name]}"
  local prefix="${result_derived[prefix]}"
  local vendor="${result_derived[vendor]}"
  local space="${result_derived[space]:-}"

    # qname (qualified name)
  local qname=""
  if [[ -n "$prefix" ]]; then
    qname+="${prefix}:"
  fi
  if [[ -n "$vendor" ]]; then
    qname+="${vendor}/"
  fi
  qname+="${name}"
  if [[ -n "$version" ]]; then
    qname+="@${version}"
  fi
  result_derived[qname]="$qname"

  # qpath (qualified file system path)
  local qpath
  if [[ "${name}" == "$__TM_NAME" ]] && [[ -z "${vendor:-}" ]]; then
    result_derived[tm]=true
    result_derived[qname]="$__TM_NAME"
    result_derived[key]="$__TM_NAME"
    result_derived[enabled_dir]="$TM_HOME"
    result_derived[install_dir]="$TM_HOME"  
    qpath="$__TM_NAME"
  else
    result_derived[tm]=false
    qpath="${vendor:-${__TM_NO_VENDOR}}/${name}"
    if [[ -n "${prefix}" ]]; then
      qpath+="__${prefix}"
    fi
    local qpath_flat="${vendor:-${__TM_NO_VENDOR}}__${name}"
    if [[ -n "${prefix}" ]]; then
      qpath_flat+="__${prefix}"
    fi    
    result_derived[enabled_dir]="$TM_PLUGINS_ENABLED_DIR/${qpath_flat}"
    result_derived[install_dir]="$TM_PLUGINS_INSTALL_DIR/${vendor:-${__TM_NO_VENDOR}}/${name}"
  fi
  result_derived[qpath]="$qpath"

    # a key which can be used for caching things
  local key=""
  if [[ -n "$vendor" ]]; then
    key+="${vendor}__"
  else
    key+="${__TM_NO_VENDOR}__"
  fi
  key+="${name}"
  if [[ -n ${version} ]]; then
    key+="__v${version}"
  else
    key+="__vmain"
  fi
  if [[ -n "$prefix" ]]; then
    key+="__${prefix}"
  fi
  result_derived[key]="$key"
  result_derived[id]="tm:plugin:$space:$vendor:$name:$version:$prefix"
  result_derived[cfg_spec]="${result_derived[install_dir]}/plugin.cfg.yaml"
  result_derived[cfg_dir]="$TM_PLUGINS_CFG_DIR/${qpath}"
  result_derived[cfg_sh]="$TM_PLUGINS_CFG_DIR/${qpath}/cfg.sh"
}

#
# Add the passed in path to the PATH if it's not already added
#
# $@.. - [PATH]s to add
#
_tm::util::add_to_path() {  
  if [[ -z "${1:-}" ]]; then
    # no paths to add, skip all
    return
  fi
  _debug "adding paths $*"
  # TODO: handle different separator in different OS's?
  IFS=':' read -ra current_paths <<< "$PATH"
  local path_exists
  for new_path in "$@"; do
    path_exists=false
    local path
    for path in "${current_paths[@]}"; do
      if [[ "$path" == "$new_path" ]]; then
        path_exists=true
        break
      fi
    done
    if [[ "$path_exists" == false ]]; then
      PATH="$new_path:$PATH"
    fi
  done
  export PATH
}