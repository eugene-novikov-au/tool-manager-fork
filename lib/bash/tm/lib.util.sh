
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
  _err "ERROR! $@"
  if _is_trace; then
    _trace "$(_tm::log::stacktrace)"
  fi
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
  if _is_trace; then
    _trace "$(_tm::log::stacktrace)"
  fi
  exit 1
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
    grep $@ || true
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
    local relative_to="${2:-}"
    
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
# Parse a plugin name or id
#
# $1 - the name of the associative array to put the results in
# $2 - the plugin name or id
#
# Usage:
#   local -A plugin
#  _tm::util::parse::plugin plugin "tm::plugin:<vendor>:<name>:<version>:<prefix>"
#  _tm::util::parse::plugin plugin "prefix:bar"
#  _tm::util::parse::plugin plugin "prefix:vendor/bar@123"
#  _tm::util::parse::plugin plugin "prefix__bar"
# TODO:
#  _tm::util::parse::plugin plugin "vendor/name"
#  _tm::util::parse::plugin plugin "vendor/name@version"
#  _tm::util::parse::plugin plugin "vendor/name__prefix"
#  _tm::util::parse::plugin plugin "vendor/name@version__prefix"
#
# Where 'plugin' is the associative array
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

  if [[ "$parse_name" == *"$__TM_SEP_PREFIX_NAME"*  ]]; then
    IFS="$__TM_SEP_PREFIX_NAME" read -r prefix name <<< "$parse_name"
  else
    IFS="$__TM_SEP_PREFIX_DIR" read -r prefix name <<< "$parse_name"
    # HACK: it seems if using a '__' delim, the plugin name is prefixed with '_'
    if [[ "$name" == '_'* ]]; then
      name="${name##_}"
    fi
  fi

  if [[ -z "$name" ]]; then #only one value provided, no prefix
    name="$prefix"
    prefix=""
  fi

  if [[ "$name" == *'/'*  ]]; then #vendor provided (slash)
      IFS="/" read -r vendor name <<< "$name"
    if [[ -z "$name" ]]; then #only one value provided, no prefix
      name="$vendor"
      vendor=""
    fi
  fi

  if [[ "$name" == *'@'*  ]]; then #vendor provided
      IFS="@" read -r name version <<< "$name"
      if [[ -z "$name" ]]; then #only one value provided, no prefix
        name="$version"
        vendor=""
      fi
  fi

  result_name[vendor]="$vendor"
  result_name[name]="$name"
  result_name[version]="$version"
  result_name[prefix]="$prefix"

  _tm::utill::parse::__set_plugin_derived_vars result_name

  if _is_finest; then
    _finest "parsed to: $(_tm::util::print_array result_name)"
  fi

  return 0
}

#
# Parse a plugin id string into an associative array
#
# $1 - the name of the associative array to put the results in
# $2 - the plugin id
#
# Usage:
#  _tm::util::parse::plugin_id parts "tm:plugin:<vendor>:<name>:<version>:<prefix>"
#
_tm::util::parse::plugin_id(){
  local -n result_id="$1" # expect it to be an associative array
  result_id=()
  local id="$2"
  _finest "_tm::util::parse::plugin_id : '$id'"
  # Read the id into an array, respecting empty fields
  local -a id_parts=()
  IFS=':' read -r -a id_parts <<< "$id"

  if [[ "${id_parts[0]:-}" != "tm" ]]; then
    _fail "Not a valid plugin id. expected 'tm:plugin:<vendor>:<name>:<version>:<prefix>', but got '$id'"
  fi
  if [[ "${id_parts[1]:-}" != "plugin" ]]; then
    _fail "Not a valid plugin id. expected 'tm:plugin:<vendor>:<name>:<version>:<prefix>', but got '$id'"
  fi
  local vendor="${id_parts[2]:-}"
  local name="${id_parts[3]}"
  local version="${id_parts[4]:-}"
  local prefix="${id_parts[5]:-}"

  result_id[vendor]="$vendor"
  result_id[name]="$name"
  result_id[version]="$version"
  result_id[prefix]="$prefix"

  _tm::utill::parse::__set_plugin_derived_vars result_id

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
   IFS=$'\n' read -d '' -r vendor name prefix <<< "${dir_name//__/$'\n'}" || true

  local version="${id_parts[4]:-}"

  result[vendor]="$vendor"
  result[name]="$name"
  result[version]=""
  result[prefix]="$prefix"

  _tm::utill::parse::__set_plugin_derived_vars result

  if _is_finest; then
    _finest "$(_tm::util::print_array result)"
  fi

}

#
# Set the calculated derived array variables
#
# $1 - the plugin associative array
#
_tm::utill::parse::__set_plugin_derived_vars(){
  local -n result_derived="$1" # expect it to be an associative array

  local name="${result_derived[name]}"
  local prefix="${result_derived[prefix]}"
  local vendor="${result_derived[vendor]}"

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
  
  if [[ "${name}" == "$__TM_NAME" ]] && [[ -z "${vendor:-}" ]]; then
    result_derived[tm]=true
    result_derived[qname]="$__TM_NAME"
    result_derived[qpath]="$__TM_NAME"
    result_derived[key]="$__TM_NAME"
    result_derived[enabled_dir]="$TM_HOME"
    result_derived[install_dir]="$TM_HOME"     
  else
    result_derived[tm]=false
    local qpath="${vendor:-${__TM_NO_VENDOR}}/${name}"
    if [[ -n "${prefix}" ]]; then
      qpath+="__${prefix}"
    fi
    local qpath_flat="${vendor:-${__TM_NO_VENDOR}}__${name}"
    if [[ -n "${prefix}" ]]; then
      qpath_flat+="__${prefix}"
    fi
    result_derived[qpath]="$qpath"
    result_derived[enabled_dir]="$TM_PLUGINS_ENABLED_DIR/${qpath_flat}"
    result_derived[install_dir]="$TM_PLUGINS_INSTALL_DIR/${vendor:-${__TM_NO_VENDOR}}/${name}"
  fi

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
  result_derived[id]="tm:plugin:$vendor:$name:$version:$prefix"

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
  _debug "adding paths $@"
  # TODO: handle differnt seperator in different OS's?
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