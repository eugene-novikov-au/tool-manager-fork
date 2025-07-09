
#
# Library to provides a set of functions for reading and parsing
# INI-style configuration files. It is used by the Tool Manager to
# process plugin definitions from files like 'plugins.conf'.
# Functions support reading entire INI files, specific sections,
# listing section names, and checking for section existence.
#

if command -v _tm::file::ini::read &>/dev/null; then
  return
fi

# Ensure common utilities like _error are available
_tm::source::include_once @tm/lib.log.sh @tm/lib.util.sh

# --- Function 1: _tm::file::ini::read ---
# Reads an entire INI file and populates the specified associative array.
# Usage: _tm::file::ini::read <output_array_name> <config_file> [prefix] 
_tm::file::ini::read() {
    if [[ "$#" -lt 2 || "$#" -gt 3 ]]; then
        _error "$FUNCNAME: Incorrect number of arguments. Usage: $FUNCNAME: <config_file> [prefix] <output_array_name>"
        return 1
    fi

    local -n target_array_ref="$1"
    local ini_file="$2"
    local prefix="${3:-}"
    local output_array_name_ref
    
    if [[ ! -f "$ini_file" || ! -r "$ini_file" ]]; then
        _error "$FUNCNAME: ini file '$ini_file' not found or not readable."
        return 1
    fi

    if ! declare -p "$target_array_ref" &>/dev/null; then # no instance, create a new one
        declare -A target_array_ref
    fi
    target_array_ref=() # Clear the array

    local current_section=""
    local line
    local key
    local value
    local output_key

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="$(_tm::file::ini::__trim_string "$line")"

        if [[ -z "$line" || "$line" =~ ^[#\;] ]]; then # Skip empty lines and comments
            continue
        fi

        if [[ "$line" =~ ^\[(.*)\]$ ]]; then # Section header
            current_section="$(_tm::file::ini::__trim_string "${BASH_REMATCH[1]}")"
            continue
        fi

        if [[ -n "$current_section" && "$line" =~ ^([^=]+)=(.*)$ ]]; then # Key-value pair
            key="$(_tm::file::ini::__trim_string "${BASH_REMATCH[1]}")"
            value="$(_tm::file::ini::__trim_string "${BASH_REMATCH[2]}")" # Value can be empty

            if [[ -n "$prefix" ]]; then
                output_key="${prefix}_${current_section}_${key}"
            else
                output_key="${current_section}_${key}"
            fi
            target_array_ref["$output_key"]="$value"
        fi
    done < "$ini_file"
    return 0
}

# --- Function 2: _tm::file::ini::read_sections ---
# Reads an INI file and populates the specified indexed array with unique section names.
# Usage: _tm::file::ini::read_sections <output_array_name> <ini_file> 
_tm::file::ini::read_sections() {
    if [[ "$#" -ne 2 ]]; then
        _error "$FUNCNAME: Incorrect number of arguments. Usage: $FUNCNAME  <output_array_name> <ini_file>"
        return 1
    fi
    local -n target_array_ref="$1"
    local ini_file="$2"

    if [[ ! -f "$ini_file" || ! -r "$ini_file" ]]; then
        _error "$FUNCNAME: ini file '$ini_file' not found or not readable."
        return 1
    fi

    target_array_ref=() # Clear the array

    local line
    local section_name
    local -A seen_sections # To store unique sections

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="$(_tm::file::ini::__trim_string "$line")"
        if [[ "$line" =~ ^\[(.*)\]$ ]]; then
            section_name="$(_tm::file::ini::__trim_string "${BASH_REMATCH[1]}")"
            if [[ -n "$section_name" && -z "${seen_sections[$section_name]:-}" ]]; then
                target_array_ref+=("$section_name")
                seen_sections["$section_name"]=1
            fi
        fi
    done < "$ini_file"
    return 0
}

# --- Function 3: _tm::file::ini::read_section ---
# Reads a specific section from an INI file and populates the specified associative array.
# Usage: _tm::file::ini::read_section <output_array_name> <config_file> <section_name> 
#
# Arguments:
# $1 - (required) the associative array to store the results in
# $2 - (required) the file to read
# $3 - (required) the name of the section to read
# $4 - (optional) options. Currently support only 'multiline' (or empty)
#           if 'multiline' is enabled, duplicate keys results in values being added using a newline
#
_tm::file::ini::read_section() {
    if [[ "$#" -lt 3 ]]; then
        _error "$FUNCNAME: Incorrect number of arguments. Usage: $FUNCNAME: <output_array_name> <config_ini_file> <section_name> <options>"
        return 1
    fi

    local -n section_array_ref="$1"
    local ini_file="$2"
    local target_section_name="$3"
    local options="${4:-}"

    _is_trace && _trace "Looking for section '${target_section_name}' in file '${ini_file}' " || true

    local opt_multi_line=0
    case "${options}" in
        multiline)
            opt_multi_line=1
            ;;
        '')
            : # nothing
            ;;
        *)
            _warn "option '${options}' is not supported. Ignoring"
            ;;   
    esac

    if [[ ! -f "$ini_file" || ! -r "$ini_file" ]]; then
        _error "$FUNCNAME: ini file '$ini_file' not found or not readable."
        return 1
    fi

    section_array_ref=() # Clear the array

    local current_section=""
    local in_target_section=0
    local line
    local key
    local value

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="$(_tm::file::ini::__trim_string "$line")"

        if [[ -z "$line" || "$line" =~ ^[#\;] ]]; then # Skip empty lines and comments
            continue
        fi

        if [[ "$line" =~ ^\[(.*)\]$ ]]; then # Section header
            current_section="$(_tm::file::ini::__trim_string "${BASH_REMATCH[1]}")"
            if [[ "$current_section" == "$target_section_name" ]]; then
                in_target_section=1
                _finest "matched section '${target_section_name}' in file '${ini_file}'"
            elif [[ "$in_target_section" -eq 1 ]]; then
                # We've passed the target section
                break 
            fi
            continue
        fi

        if [[ "$in_target_section" -eq 1 && "$line" =~ ^([^=]+)=(.*)$ ]]; then # Key-value pair
            key="$(_tm::file::ini::__trim_string "${BASH_REMATCH[1]}")"
            value="$(_tm::file::ini::__trim_string "${BASH_REMATCH[2]}")"
            if [[ "${opt_multi_line}" == '0' ]] || [[ -z "${section_array_ref["$key"]:-}" ]]; then # new value
                section_array_ref["$key"]="$value"
            else # append to existing value. Allows for multi line support (just put multiple values with the same key on new lines)
                section_array_ref["$key"]+="\n$value"
            fi
        fi
    done < "$ini_file"
    return 0
}

# --- Function 4: _tm::file::ini::has_section ---
# Checks if a given section exists in the INI file.
# Usage: _tm::file::ini::has_section <config_file> <section_name>
# Returns 0 (true) if found, 1 (false) otherwise.
_tm::file::ini::has_section() {
    if [[ "$#" -ne 2 ]]; then
        _error "$FUNCNAME: Incorrect number of arguments. Usage: $FUNCNAME: <config_ini_file> <section_name>"
        return 1 # Or a different error code for bad usage vs. not found
    fi

    local ini_config_file="$1"
    local target_section_name="$2"

    if [[ ! -f "$ini_config_file" || ! -r "$ini_config_file" ]]; then
        # _error "_tm::file::ini::has_section: Config file '$ini_config_file' not found or not readable." # Optional: can be noisy if used purely as a check
        return 1 # Section not found if file not readable
    fi

    local line
    local current_section_name
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="$(_tm::file::ini::__trim_string "$line")"
        if [[ "$line" =~ ^\[(.*)\]$ ]]; then
            current_section_name="$(_tm::file::ini::__trim_string "${BASH_REMATCH[1]}")"
            if [[ "$current_section_name" == "$target_section_name" ]]; then
                return 0 # Found
            fi
        fi
    done < "$ini_config_file"

    return 1 # Not found
}

# --- Helper function to trim whitespace ---
# Removes leading and trailing whitespace from the input string.
# Usage: _tm::file::ini::__trim_string "  string   "
_tm::file::ini::__trim_string() {
    local var="$1" # Operate on the first argument
    # remove leading whitespace characters
    var="${var#"${var%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}