#
# Library to handle tool-manager 'events'
#
#

if command -v _tm::event::fire &>/dev/null; then
  return
fi

#
# Ensure all variables are initialised
#
_tm::event::__init(){
    if [[ ! -v __tm_event_inited ]]; then
      __tm_event_inited=1

      # associative arrays are buggy. We need to declare them in a special way to ensure they work
      # see https://stackoverflow.com/questions/10806357/associative-arrays-are-local-by-default
      declare -gA __tm_events_listeners
      __tm_events_listeners=() # registered event listeners
   fi
}

#
# Fire a tool manage event
#
# Arguments:
# $1 - the event name
# $2.. - the event args
#
_tm::event::fire(){
    _tm::event::__init

    local event_name="$1"
    if [[ -z "${event_name}" ]]; then
        _warn "event with no name. Ignoring"
        return
    fi
    shift
    if [[ "${#__tm_events_listeners[@]}" == '0' ]]; then
        return
    fi

    local event_id="$(uuidgen)"
    local event_ts="${EPOCHREALTIME}"

    # Iterate through all registered event patterns and check for matches
    for regex_pattern in "${!__tm_events_listeners[@]}"; do
        if [[ "${event_name}" =~ ${regex_pattern} ]]; then
            local listeners="${__tm_events_listeners[${regex_pattern}]}"
            if [[ -n "${listeners}" ]]; then
                for listener in ${listeners}; do
                    # Execute in a subshell to isolate environment and continue on error
                    ( "$listener" "${event_name}" "${event_id}" "${event_ts}" "$@" )
                done
            fi
        fi
    done
}

#
# Register a listener that is only invoked once, then removed
#
#
_tm::event::on::once(){
    _tm::event::__init
    local event_name="$1"
    local callback_function="$2"
    
    local _once_wrapper_name="_tm_once_wrapper_$(uuidgen | tr -d '-')"
    
    # Define the wrapper function dynamically. After the call it will remove itself
    eval "
    ${_once_wrapper_name}() {
        local event_name_param=\"\$1\"
        local event_id_param=\"\$2\"
        local event_ts_param=\"\$3\"
        shift 3 # Remove event_name, event_id, event_ts
        \"${callback_function}\" \"\$event_name_param\" \"\$event_id_param\" \"\$event_ts_param\" \"\$@\"
        _tm::event::off \"\${event_name}\" \"\${_once_wrapper_name}\"
        unset -f \"\${_once_wrapper_name}\" # Unset the function after it has been called and removed
    }
    "
    _tm::event::on "${event_name}" "${_once_wrapper_name}"
}


#
# Register an event callback
#
# $1 - the event name or '*'
# $2 - the callback function. Args passed to it are <event_name> <event_id> <event_timestamp> <event_args...>
#
#
_tm::event::on(){
    _tm::event::__init
    local event_pattern="$1"
    local callback_function="$2"

    local regex_pattern=$(_tm::event::__convert_pattern_to_regex "${event_pattern}")
    echo "XXXXX regex_pattern=${regex_pattern}"
    local existing="${__tm_events_listeners["${regex_pattern}"]}"
    if [[ -z "${existing}" ]]; then
        __tm_events_listeners["${regex_pattern}"]="$callback_function"
    else
        __tm_events_listeners["${regex_pattern}"]+=" $callback_function"
    fi
}

#
# Deregister an event listener
#
# $1 - the event name or '*'
# $2 - the callback function to remove
#
_tm::event::off(){
    _tm::event::__init
    local event_pattern="$1"
    local callback_function="$2"

    local event_regex_pattern=$(_tm::event::__convert_pattern_to_regex "${event_pattern}")

    local existing="${__tm_events_listeners["${event_regex_pattern}"]}"
    if [[ -n "${existing}" ]]; then
        # Remove the specific callback function from the string of listeners
        local new_listeners=$(echo "${existing}" | sed -e "s/\b${callback_function}\b//g" -e "s/[[:space:]]\+/ /g" -e "s/^[[:space:]]*//g" -e "s/[[:space:]]*$//g")

        if [[ -z "${new_listeners}" ]]; then
            unset __tm_events_listeners["${event_name}"]
        else
            __tm_events_listeners["${event_name}"]="${new_listeners}"
        fi
    fi
}

#
# Converts an event pattern (e.g., "foo.bar.*", "**.start") into a bash extended regular expression.
# Rules:
#   '.' -> literal '.' (\.)
#   '*' -> any characters except '.' ([^.]*)
#   '**' -> any characters including '.' (.*)
# The resulting regex is anchored with '^' and '$' for full string match.
#
_tm::event::__convert_pattern_to_regex() {
    local pattern="$1"
    if [[ "${pattern}" == "**" ]]; then
        echo ".*"
        return
    fi
    local __TM_DOUBLE_STAR_PLACEHOLDER__="__TM_DOUBLE_STAR_PLACEHOLDER__"
    local __TM_SINGLE_STAR_PLACEHOLDER__="__TM_SINGLE_STAR_PLACEHOLDER__"
    # Replace '**' with a unique placeholder first to prevent '*' from matching part of '**'
    pattern="${pattern//\*\*/__TM_DOUBLE_STAR_PLACEHOLDER__}"
    # Replace '*' with another unique placeholder
    pattern="${pattern//\*/__TM_SINGLE_STAR_PLACEHOLDER__}"
    # Escape literal dots (now they are not part of '*' or '**' patterns)
    pattern="${pattern//\./\\.}"
    # Replace placeholders with actual regex components
    pattern="${pattern//__TM_DOUBLE_STAR_PLACEHOLDER__/.*}"
    pattern="${pattern//__TM_SINGLE_STAR_PLACEHOLDER__/[^.]*}"
    echo "^${pattern}$" # Anchor the regex to ensure a full string match
}