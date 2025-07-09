#
# Library to provide support for reading .conf files. 
#
# These are shell scripts with some tool-manager restrictions so it can parse them without running it.
#
# Conf files support name=value assignments, comments, and functions
#
# These files must have all their code within functions. SIngle and multiline functions are supported,
# but multiline functions must end with  '}' on a line by itself
#

if command -v _tm::io::conf::read_file &>/dev/null; then # already loaded
  return
fi


_tm::source::include_once @tm/lib.util.sh 

# Reads an entire conf file and populates the specified associative array.
# Usage: _tm::io::conf::read_file <output_array_name> <conf_file> [append_keys_array_name]
#   <output_array_name>: The name of the associative array to populate.
#   <conf_file>: The path to the configuration file.
#   [append_keys_array_name]: Optional. The name of an array containing keys for which values should be appended (multi-line).
#
# Arguments
#  $1 - (required) the associative array to put the results into
#  $2 - (required) the conf file to read
#
_tm::io::conf::read_file(){
    local -n target_array_ref="$1"
    local file="$2"
    shift 2
    local append_keys_ref=("$@")
    # Clear the existing values only if this is the first file being processed
    # (assuming conf_files is just one file per call as per current usage)
    target_array_ref=()

    _debug "Reading conf file '$file' into array"
    
    if [[ ! -f "$file" ]] || [[ ! -r "$file" ]]; then
        _debug "no conf file '$file', or can't read, skipping"
        continue
    fi
    _debug "reading file '$file'"

    # State variables for multi-line function parsing, reset for each file
    local collecting_function_body=false # if true, we are still reading the function body
    local current_multi_line_function_key="" # the function name we are currently collecting the body for
    local line
    local key
    local value
    # Read the file line by line
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Remove leading/trailing whitespace
        line="$(echo -e "${line}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

        # Skip empty lines and comments
        if [[ -z "$line" || "$line" == \#* ]]; then
            continue
        fi

        # Remove inline comments (text after #)
        local uncommented_line="${line%%#*}"
        # Trim trailing whitespace again after removing comment
        uncommented_line="$(echo -e "${uncommented_line}" | sed -e 's/[[:space:]]*$//')"

        # Check if the line is empty after uncommenting and trimming
        if [[ -z "$uncommented_line" ]]; then
            continue
        fi

        # are we reading a function?
        if [[ "$uncommented_line" =~ ^(function[[:space:]]+)?([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\(\)[[:space:]]*\{?.*$ ]]; then
            key="${BASH_REMATCH[2]}()" # Function name is in the second capturing group
            value="${uncommented_line}" # The whole line is the "body" as per single-line parsing
            target_array_ref["${key}"]="$value" # Initialize with the first line
            # Check if this is a multi-line function declaration (doesn't end with '}')
            if [[ ! "$uncommented_line" =~ \}\s*$ ]]; then
                collecting_function_body=true
                current_multi_line_function_key="$key"
            else
                # Single-line function, no need to collect more lines
                collecting_function_body=false
                current_multi_line_function_key=""
                _is_trace && _trace "Set ['$key'] = '$value'" || true
            fi
        elif [[ "$collecting_function_body" == true ]]; then
            # If we are currently parsing a multi-line function, append the current line
            target_array_ref["${current_multi_line_function_key}"]+=$'\n'"${uncommented_line}"
            # Check if this line closes the function body
            if [[ "$uncommented_line" =~ \}\s*$ ]]; then
                _is_trace && _trace "Set ['$current_multi_line_function_key'] = '${target_array_ref["${current_multi_line_function_key}"]}'" || true
                collecting_function_body=false
                current_multi_line_function_key="" # Reset state
            fi
        elif [[ "$uncommented_line" == *"="* ]]; then # or ensure there's an '=' sign
            key="${uncommented_line%%=*}"
            value="${uncommented_line#*=}"

            # Remove potential quotes around value (optional, common in .env)
            # This handles "value", 'value', value
            value="${value%\"}"
            value="${value#\"}"
            value="${value%\'}"
            value="${value#\'}"

            if [[ -z "${target_array_ref["$key"]:-}" ]]; then
                target_array_ref["$key"]="$value"
            else
                # Check if this key should allow appending
                local should_append=false
                if [[ "${#append_keys_ref[@]}" -gt 0 ]]; then # Check if append_keys_ref is set
                    for k in "${append_keys_ref[@]}"; do
                        if [[ "$k" == "$key" ]]; then
                            should_append=true
                            break
                        fi
                    done
                fi

                if ${should_append}; then
                    target_array_ref["$key"]+=$'\n'"$value"
                else
                    target_array_ref["$key"]="$value"
                fi
            fi

            _is_trace && _trace "Set ['$key'] = '${target_array_ref["$key"]}'" || true
        else
            _finest "Skipping line '$uncommented_line'"
        fi
    done < "$file"
    
    _debug "Finished reading conf file '$file'."
    
    _is_finest && _tm::util::array::print target_array_ref || true
    return
}

