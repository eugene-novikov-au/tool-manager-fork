
#
# Parse github url. Support urls of the form 'git@github.com...' and 'http[s]://github.com....' The version can be set
# via appending an '#<version>' to the end, e.g. '#main'
#
# Arguments
#  $1 - associative array to put the results in
#  $2 - the github url
#
# Populates the associative with the following keys:
#   - `url`: The cleaned 'git@github.com....' url.
#   - `web_url`: The cleaned 'https://github.com....' url.
#   - `owner`: The repo owner.
#   - `name`: The repo name.
#   - `version`: The version to checkout. Blank if not set or to use the default.
#
_tm::parse::github_url(){
  local -n github_ref="$1"
  local github_url="$2"
  github_ref=() #clear the data


  local path="$(echo "$github_url" | sed -E 's|.*github.com[:/]?||' | sed 's|.git||')"
  local repo_name prefix owner version
  IFS="/" read -r owner repo_name <<< "$path"
  IFS="#" read -r repo_name version <<< "$repo_name" # maybe ends with a some_repo.git#<version>
  if [[ -z "$version" ]]; then # maybe it ended with a 'some_repo.git#<version>'
    IFS="#" read -r repo_name version <<< "$repo_name"
  fi

  github_ref[url]="git@github.com:${owner}/${repo_name}.git"
  github_ref[web_url]="https://github.com/${owner}/${repo_name}"
  github_ref[owner]="${owner}"
  github_ref[repo]="${repo_name}.git"
  github_ref[name]="${repo_name}"
  github_ref[version]="${version}"
}


#
# _tm::parse::plugin
#
# Parses a plugin identifier string (either a qualified name or a full ID) into an
# associative array containing its components (vendor, name, version, prefix, etc.).
# This function acts as a dispatcher, calling either `_tm::parse::plugin_id`
# or `_tm::parse::plugin_name` based on the format of the input string.
#
# Arguments:
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
#   - `cfg_sh`: Path to the plugin's merged shell configuration file (to apply all the config)
#   - `state_dir`: Path to the plugin's state dir (where it can save persistent state)
#   - `cache_dir`: Path to the plugin's cache dir (where it can save cached data)
#   - `tm`: Boolean, true if this is the tool-manager plugin itself.
#
# Usage:
#   declare -A my_plugin_info
#   _tm::parse::plugin my_plugin_info "myvendor/myplugin@1.0.0__myprefix"
#   _tm::parse::plugin my_plugin_info "tm:plugin:myvendor:myplugin:1.0.0:myprefix"
#
_tm::parse::plugin(){
  _finest "_tm::parse::plugin: '$2'"
  if [[ "$2" == "tm:plugin:"* ]]; then
    _tm::parse::plugin_id "$@"
  else
    _tm::parse::plugin_name "$@"
  fi
}

#
# Parse a qualified plugin name into an associative array
#
# Arguments:
# $1 - the name of the associative array to put the results in
# $2 - the plugin name
#
# Usage:
#  _tm::parse::plugin_name parts "prefix:bar"
#  _tm::parse::plugin_name parts "prefix:vendor/bar@123"
#  _tm::parse::plugin_name parts "prefix__bar"

#
_tm::parse::plugin_name(){
  local -n result_ref="$1" # expect it to be an associative array
  result_ref=()
  local parse_name="$2"
  _finest "_tm::parse::plugin_name: '$parse_name'"

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

  result_ref[vendor]="$vendor"
  result_ref[name]="$name"
  result_ref[version]="$version"
  result_ref[prefix]="$prefix"

  _tm::parse::__set_plugin_derived_vars result_ref

  _is_finest && _finest "parsed to: $(_tm::util::print_array result_ref)" || true

  return 0
}


# Parses a plugin id string into an associative array
#
# Arguments:
# $1 - the name of the associative array to put the results in
# $2 - the plugin id
#
# Behavior:
#   Parses a plugin id string into an associative array.
#
# Usage:
#  _tm::parse::plugin_id parts "tm:plugin:<space>:<vendor>:<name>:<version>:<prefix>"
#
_tm::parse::plugin_id(){
  local -n result_ref="$1" # expect it to be an associative array
  result_ref=()
  local parse_id="$2"
  _finest "_tm::parse::plugin_id: '$parse_id'"
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

  result_ref[vendor]="$vendor"
  result_ref[name]="$name"
  result_ref[version]="$version"
  result_ref[prefix]="$prefix"

  _tm::parse::__set_plugin_derived_vars result_ref

  _is_finest && _finest "$(_tm::util::print_array result_ref)" || true
}


#
# Parse the qpath into a plugin associative array
#
# Arguments:
# $1 - the plugin associative array
# $2 - the qpath (qualified path)
#
_tm::parse::plugin_enabled_dir(){
  local -n result_ref="$1" # expect it to be an associative array
  result_ref=()

  local dir_name="$2"
  # IFD can't do multiple chars, so convert '__' to newlines and then parse
  # the format is vendor__name__prefix, where prefix is optional
   IFS=$'\n' read -d '' -r vendor name prefix <<< "${dir_name//__/$'\n'}" || true

  local version="${id_parts[4]:-}"

  result_ref[vendor]="$vendor"
  result_ref[name]="$name"
  result_ref[version]=""
  result_ref[prefix]="$prefix"

  _tm::parse::__set_plugin_derived_vars result_ref

  _is_finest && _finest "$(_tm::util::print_array result_ref)" || true
}

#
# Set the calculated derived array variables
#
# Arguments:
# $1 - the plugin associative array
#
_tm::parse::__set_plugin_derived_vars(){
  local -n result_ref_derived="$1" # expect it to be an associative array

  local name="${result_ref_derived[name]}"
  local prefix="${result_ref_derived[prefix]}"
  local vendor="${result_ref_derived[vendor]}"
  local space="${result_ref_derived[space]:-}"

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
  result_ref_derived[qname]="$qname"

  # qpath (qualified file system path)
  local qpath
  if [[ "${name}" == "$__TM_NAME" ]] && [[ -z "${vendor:-}" ]]; then
    result_ref_derived[tm]=true
    result_ref_derived[qname]="$__TM_NAME"
    result_ref_derived[key]="$__TM_NAME"
    result_ref_derived[enabled_dir]="$TM_HOME"
    result_ref_derived[install_dir]="$TM_HOME"
    qpath="$__TM_NAME"
  else
    result_ref_derived[tm]=false
    qpath="${vendor:-${__TM_NO_VENDOR}}/${name}"
    if [[ -n "${prefix}" ]]; then
      qpath+="__${prefix}"
    fi
    local qpath_flat="${vendor:-${__TM_NO_VENDOR}}__${name}"
    if [[ -n "${prefix}" ]]; then
      qpath_flat+="__${prefix}"
    fi
    result_ref_derived[enabled_dir]="$TM_PLUGINS_ENABLED_DIR/${qpath_flat}"
    result_ref_derived[install_dir]="$TM_PLUGINS_INSTALL_DIR/${vendor:-${__TM_NO_VENDOR}}/${name}"
  fi
  result_ref_derived[qpath]="$qpath"

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
  result_ref_derived[key]="$key"
  result_ref_derived[id]="tm:plugin:$space:$vendor:$name:$version:$prefix"
  result_ref_derived[cfg_spec]="${result_ref_derived[install_dir]}/plugin.cfg.yaml"
  result_ref_derived[cfg_dir]="$TM_PLUGINS_CFG_DIR/${qpath}"
  result_ref_derived[cfg_sh]="$TM_PLUGINS_CFG_DIR/${qpath}/config.sh"
  result_ref_derived[state_dir]="$TM_PLUGINS_STATE_DIR/${qpath}"
  result_ref_derived[cache_dir]="$TM_PLUGINS_CACHE_DIR/${qpath}"
}
