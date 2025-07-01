
# This script provides a set of Bash functions for reading and parsing
# .env files
#

# Ensure common utilities like _error are available
#_tm::source::include_once @tm/lib.log.sh
_tm::source::include_once @tm/lib.util.sh @tm/lib.args.sh

# --- Function 1: _tm::file::ini::read ---
# Reads an entire env file and populates the specified associative array.
# Usage: _tm::file::env::read <output_array_name> [source_prefix] [target_prefix]  <env_file> <env_file> <env_file>..
_tm::file::env::read() {
    #echo "_tm::file::env::read $@"
    local -n target_array_ref="$1"
    local source_prefix="$2"
    local target_prefix="$3"
    shift
    shift
    shift
    local env_files="$@"
    

    _debug "Reading env files '$env_files' into array"
    _trace "Source prefix: '${source_prefix:-none}', Target prefix: '${target_prefix:-none}'"

    local line
    local key
    local value
    local effective_key

    # Read the file line by line
    for file in $env_files; do
        if [[ ! -f "$file" ]] || [[ ! -r "$file" ]]; then
            continue
        fi
        while IFS= read -r line || [[ -n "$line" ]]; do
            _trace "Processing line: '$line'"

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
    
            # Ensure there's an '=' sign
            if [[ "$uncommented_line" != *"="* ]]; then
                _trace "Skipping line without '=': '$uncommented_line'"
                continue
            fi
            
            key="${uncommented_line%%=*}"
            value="${uncommented_line#*=}"

            # Remove potential quotes around value (optional, common in .env)
            # This handles "value", 'value', value
            value="${value%\"}"
            value="${value#\"}"
            value="${value%\'}"
            value="${value#\'}"
            
            _trace "Parsed raw key: '$key', value: '$value'"

            # Handle source_prefix
            if [[ -n "$source_prefix" ]]; then
                if [[ "$key" == "$source_prefix"* ]]; then
                    key="${key#"$source_prefix"}" # Remove prefix
                    _trace "Applied source_prefix. New key: '$key'"
                else
                    _trace "Key '$key' does not match source_prefix '$source_prefix'. Skipping."
                    continue # Skip if key doesn't match source_prefix
                fi
            fi

            effective_key="$key"
            # Handle target_prefix
            if [[ -n "$target_prefix" ]]; then
                effective_key="${target_prefix}${key}"
                _trace "Applied target_prefix. Effective key: '$effective_key'"
            fi
            
            target_array_ref["$effective_key"]="$value"
            _debug "Set ${output_array_name}['$effective_key'] = '$value'"
        done < "$file"
    done
    _debug "Finished reading env file(s) '$env_files'."
    return
}

# --- Function _tm::file::env::set ---
# Adds or replaces a key-value pair in an environment file.
# Creates the file and parent directories if they don't exist.
# Ensures that existing variables in comments are not replaced.
# Appends to the end if the key does not exist.
# Allows adding/replacing a comment for the specified key.
#
# Usage: _tm::file::env::set <env_file> <key> <value> [comment]
#   env_file: Path to the .env file.
#   key: The key to set (should not contain '=', '#', or spaces).
#   value: The value for the key (can be an empty string).
#   comment: (Optional) A comment to associate with this key-value pair.
#            If provided, it will be added as " # comment" after the value.
#            If the key exists and a new comment is provided, it replaces the old comment for that key.
#            If the key exists and no new comment is provided, an existing comment on that line is preserved.
_tm::file::env::set() {
    local env_file="$1"
    local key_to_set="$2"
    local value_to_set="$3" # Can be empty
    local comment_text="${4:-}" # Optional

    _debug "Setting env: File='$env_file', Key='$key_to_set', Value='$value_to_set', Comment='${comment_text:-none}'"

    # Validate the key
    if [[ "$key_to_set" == *"="* || "$key_to_set" == *"#"* || "$key_to_set" == *" "* ]]; then
        _fail "Key '$key_to_set' contains invalid characters (=, #, or space). Aborting."
        return 1
    fi

    local env_dir
    env_dir="$(dirname "$env_file")"

    # Create parent directory if it doesn't exist
    if [[ ! -d "$env_dir" ]]; then
        _trace "Parent directory '$env_dir' does not exist. Creating."
        if ! mkdir -p "$env_dir"; then
            _fail "Failed to create parent directory '$env_dir'. Aborting."
            return 1
        fi
    fi

    local temp_file
    temp_file="$(mktemp -d)" # Pass a template for clarity if mktemp supports it
    if [[ -z "$temp_file" ]]; then
        _fail "Failed to create a temporary file. Aborting."
    fi
    # Ensure temp file is cleaned up on exit or error, if not successfully moved
    trap '_tm::util::save_rm_file "$temp_file"' EXIT INT TERM

    local key_found=false
    local line_written_to_temp=false # To track if anything was written to temp_file

    if [[ -f "$env_file" ]]; then
        _trace "File '$env_file' exists. Processing line by line to '$temp_file'."
        local original_line
        local processed_line_for_parsing # Line after stripping leading/trailing whitespace for parsing
        local current_key_in_file
        local existing_comment_segment # Segment like " # old comment"

        while IFS= read -r original_line || [[ -n "$original_line" ]]; do # Process last line if no newline
            _trace "Read line: '$original_line'"
            
            # For parsing, remove leading/trailing whitespace from the line.
            # Using pure bash for trimming:
            processed_line_for_parsing="${original_line#"${original_line%%[![:space:]]*}"}" # remove leading
            processed_line_for_parsing="${processed_line_for_parsing%"${processed_line_for_parsing##*[![:space:]]}"}" # remove trailing

            # Skip full comment lines and empty lines, writing them as-is
            if [[ -z "$processed_line_for_parsing" || "${processed_line_for_parsing:0:1}" == "#" ]]; then
                _trace "Line is empty or a full comment. Writing as is."
                echo "$original_line" >> "$temp_file"
                line_written_to_temp=true
                continue
            fi
            
            # Ensure there's an '=' sign for it to be a variable assignment
            if [[ "$processed_line_for_parsing" != *"="* ]]; then
                _trace "Line does not contain '='. Writing as is (could be malformed or just text)."
                echo "$original_line" >> "$temp_file"
                line_written_to_temp=true
                continue
            fi

            current_key_in_file="${processed_line_for_parsing%%=*}"
            # Trim trailing whitespace from extracted key, e.g. "KEY =value" -> "KEY"
            current_key_in_file="${current_key_in_file%"${current_key_in_file##*[![:space:]]}"}"

            if [[ "$current_key_in_file" == "$key_to_set" ]]; then
                _debug "Key '$key_to_set' found. Replacing line."
                key_found=true
                local new_line_content="${key_to_set}=${value_to_set}"

                if [[ -n "$comment_text" ]]; then
                    # New comment provided, use it
                    new_line_content+=" # ${comment_text}"
                else
                    # No new comment, try to preserve existing comment from this line
                    # Look for " # " in the original processed line (after the value part)
                    local value_and_comment_part="${processed_line_for_parsing#*=}"
                    local key_part_len=${#current_key_in_file}
                    local assignment_part="${processed_line_for_parsing%%#*}" # KEY = VALUE part, trimmed
                    assignment_part="${assignment_part%"${assignment_part##*[![:space:]]}"}" 

                    if [[ "$processed_line_for_parsing" == *"#"* && "${#processed_line_for_parsing}" -gt "${#assignment_part}" ]]; then
                        existing_comment_segment="${processed_line_for_parsing#"$assignment_part"}" # Should be " # comment" or similar
                        # Ensure it starts with a hash, possibly spaced
                        if [[ "${existing_comment_segment#"${existing_comment_segment%%[![:space:]]*}"}" == "#"* ]]; then
                           new_line_content+="${existing_comment_segment}" # Append the whole " # comment" part
                        fi
                    fi
                fi
                _trace "New line content: '$new_line_content'"
                echo "$new_line_content" >> "$temp_file"
                line_written_to_temp=true
            else
                _trace "Key '$current_key_in_file' does not match '$key_to_set'. Writing original line."
                echo "$original_line" >> "$temp_file"
                line_written_to_temp=true
            fi
        done < "$env_file"
    else
        _trace "File '$env_file' does not exist. Will create it with the new entry."
        # File will be created when we write the new entry to temp_file and then mv
    fi

    if ! "$key_found"; then
        _debug "Key '$key_to_set' not found in file (or file was new). Appending."
        local new_entry="${key_to_set}=${value_to_set}"
        if [[ -n "$comment_text" ]]; then
            new_entry+=" # ${comment_text}"
        fi
        
        # If the temp file has content and doesn't end with a newline,
        # adding one before the new entry might be desired.
        # However, `echo` appends a newline by default, which is usually fine.
        # If line_written_to_temp is true, means temp_file might have content.
        # A simple `echo` is generally robust.
        _trace "Appending new entry: '$new_entry'"
        echo "$new_entry" >> "$temp_file"
        # line_written_to_temp is implicitly true now if it wasn't already
    fi

    _trace "Moving temp file '$temp_file' to '$env_file'"
    if ! mv "$temp_file" "$env_file"; then
        _fail "Failed to move temp file '$temp_file' to '$env_file'. Changes might be in temp file."
        # Trap will attempt to clean up $temp_file on exit.
        return 1
    fi
    
    # Temp file successfully moved. Clear the trap for this specific file
    # as it no longer needs to be cleaned up by the trap (it's now the target file).
    trap - EXIT INT TERM 
    # Optionally, attempt a cleanup in case mv left the source under a different name (highly unlikely for standard mv)
    # _tm::util::save_rm_file "$temp_file"

    _debug "Successfully set key '$key_to_set' in '$env_file'."
    return 0
}

# --- Function _tm::file::env::get_key ---
# Reads a single key from a given .env file and echoes its value.
# Does not populate an array; directly outputs the value.
#
# Usage: _tm::file::env::get_key <env_file> <key_to_get>
#   env_file: Path to the .env file.
#   key_to_get: The specific key whose value is to be retrieved.
#
# Output:
#   Echoes the value of the key if found.
#   Echoes nothing if the key is not found or file is not readable.
#
# Returns:
#   0 if the key is found and value is echoed.
#   1 if the file is not found or not readable.
#   2 if the key is not found in the file.
#   3 if incorrect arguments are provided.
_tm::file::env::get_key() {
    local env_file="$1"
    local key_to_get="$2"
    
    if [[ -z "$env_file" || -z "$key_to_get" ]]; then
        _error "Usage: _tm::file::env::get_key <env_file> <key_to_get>"
        return 3 # Incorrect arguments
    fi

    _trace "Attempting to get key '$key_to_get' from file '$env_file'"

    if [[ ! -f "$env_file" ]]; then
        _debug "File not found: $env_file"
        return 1 # File not found
    fi

    if [[ ! -r "$env_file" ]]; then
        _debug "File not readable: $env_file"
        return 1 # File not readable
    fi

    local line
    local current_key
    local value

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Minimal processing for speed
        # Trim leading whitespace (important for matching key at start of line)
        line="${line#"${line%%[![:space:]]*}"}"

        # Skip empty lines and full comments quickly
        if [[ -z "$line" || "${line:0:1}" == "#" ]]; then
            continue
        fi

        # Check if the line starts with the key followed by '='
        # This is a more direct check than full parsing if we only need one key.
        # Format: KEY=VALUE or KEY = VALUE etc.
        # We need to be careful with keys that are substrings of other keys.
        # So, check for KEY= or KEY =
        if [[ "$line" == "${key_to_get}="* || "$line" == "${key_to_get} "* ]]; then
            # Potential match, now properly extract key and value
            local uncommented_line="${line%%#*}" # Remove inline comment
            
            # Trim trailing whitespace from uncommented part
            uncommented_line="${uncommented_line%"${uncommented_line##*[![:space:]]}"}" 

            current_key="${uncommented_line%%=*}"
            # Trim trailing whitespace from extracted key
            current_key="${current_key%"${current_key##*[![:space:]]}"}"

            if [[ "$current_key" == "$key_to_get" ]]; then
                value="${uncommented_line#*=}"
                # Remove potential quotes around value
                value="${value%\"}"
                value="${value#\"}"
                value="${value%\'}"
                value="${value#\'}"
                
                echo "$value"
                _trace "Key '$key_to_get' found. Value: '$value'"
                return 0 # Key found
            fi
        fi
    done < "$env_file"

    _trace "Key '$key_to_get' not found in '$env_file'."
    return 2 # Key not found
}
