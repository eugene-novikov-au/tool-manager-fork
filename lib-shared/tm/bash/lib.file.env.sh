
# This script provides a set of Bash functions for reading and writing to .env files
#

# Ensure common utilities  are available
_tm::source::include_once @tm/lib.util.sh

# Reads an entire env file and populates the specified associative array.
# Usage: _tm::file::env::read <output_array_name> <env_file1> <env_file2> <env_file3>..
_tm::file::env::read() {
    local -n target_array_ref="$1"
    shift
    local env_files="$@"
    
    target_array_ref=() # clear the existing values
    
    _debug "Reading env files '$env_files' into array"

    local line
    local key
    local value

    # Read the file line by line
    for file in $env_files; do
        if [[ ! -f "$file" ]] || [[ ! -r "$file" ]]; then
            _debug "no env file '$file', or can't read, skipping"
            continue
        fi
        _debug "reading file '$file'"
        while IFS= read -r line || [[ -n "$line" ]]; do
            #_finest "Processing line: '$line'"

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
            
            #_finest "Parsed key: '$key', value: '$value'"

            target_array_ref["$key"]="$value"
            _is_trace && _trace "Set ['$key'] = '$value'" || true
        done < "$file"
    done
    _debug "Finished reading env file(s) '$env_files'."
    _is_finest && _tm::util::array::print target_array_ref || true
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
