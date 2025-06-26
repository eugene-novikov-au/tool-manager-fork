if command -v _tm::log::name &>/dev/null; then
  return
fi

#
# helper scripts and bashrc scripts should source this for all the common setup and config
#
# Can be sourced multiple times, but will only execute its definitions once per session due to a sourcing guard.
#

__tm_log_starttime=${__tm_log_starttime:-$(date +%s%N)}

# ANSI Color Codes for logging
COLOR_BLACK='\033[0;0m'
COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_GREY='\033[0;37m'
COLOR_NONE='\033[0m' # No Color


TM_LOG_NAME="${TM_LOG_NAME:-$(basename ${BASH_SOURCE[${#BASH_SOURCE[@]}-1]})}"
if ([[ "$TM_LOG_NAME" == ".bashrc" ]] || [[ "$TM_LOG_NAME" == "bash" ]]); then
  TM_LOG_NAME="tool-manager"
fi

TM_LOG_CONSOLE="${TM_LOG_CONSOLE:-1}" # whether to log to console
TM_LOG_FILE="${TM_LOG_FILE:-}" # path to the file to log. Only log to file if set
TM_LOG="${TM_LOG:-info}" # all the various logging options

__tm_log="${__tm_log:-unset}" # to detect log name changes
__tm_log_names=()
__tm_log_filters=()

_tm::log::init(){
  if [[ "$TM_LOG" != "$__tm_log" ]]; then
    __tm_log="$TM_LOG"
    _tm::log::set_opts "$TM_LOG"
  fi
}

#
# Set the varipus logging options. 
# $1: csv string of options. Can contain any of the log levels, caller, timings. Case and space insensitive
#
_tm::log::set_opts(){
  local log_opts="$1"
  #>&2 echo "tm::log::set_opts log_opts=$log_opts"
  local opts
  local level

  local LEV_FINEST=0 LEV_TRACE=1 LEV_DEBUG=2 LEV_INFO=3 LEV_WARN=4 LEV_ERR=5
  local log_pid=0
  local log_timing=0
  local log_call_file=0 log_call_func=0
  local log_timestamp=0 log_datestamp=0 log_epoch=0
  local log_user=0
  local log_stack=0
  local -a loggers=()
  local help=0

  _tm::log::__stack(){
    :
  }

  IFS=',' read -ra opts <<< "$log_opts"
  for opt in "${opts[@]}"; do
    case "$opt" in
      w|warn|WARN)
        level=$LEV_WARN
        ;;
      i|info|INFO)
        level=$LEV_INFO
        ;;
      d|debug|DEBUG)
        level=$LEV_DEBUG
        ;;
      t|trace|TRACE)
        level=$LEV_TRACE
        ;;
      f|finest|FINEST)
        level=$LEV_FINEST
        ;;
      proc|pid)
        log_pid=true
        ;;
      timing)
        log_timing=true
        ;;
      ts|timestamp)
        log_timestamp=true
        ;;
      ds|datestamp)
        log_datestamp=true
        ;;
      epoch)
        log_epoch=true
        ;;
      cfunc|caller-func)
        log_call_func=true
        ;;
      cfile|caller-file)
        log_call_file=true
        ;;      
      call|caller)
        log_call_file=true
        log_call_func=true
        ;;  
      user)
        log_user=true
        ;;
      stack|stacktrace)
        _tm::log::__stack(){ _tm::log::stacktrace '...' ; }
        ;;
      -console)
        LOG_CONSOLE=0
        ;;
      console)
        LOG_CONSOLE=1
        ;;        
      -file)
        LOG_FILE=''
        ;;
      file)
        if [[ -z "${LOG_FILE:-}" ]]; then
          LOG_FILE="$(pwd)/tm.log"          
          >&2 echo "Logging to file '$LOG_FILE'"
        fi
        ;;
      help)
        help=1
        ;;  
      all)
        log_call_file=true
        log_call_func=true
        log_datestamp=true
        log_pid=true
        log_timing=true
        log_user=true
        ;;
      @*)
        logger="${opt:1}"
        __tm_log_filters+=("${logger}")
        ;;
      *)
        >&2 echo "WARN [_tm::log::opt_level] unknown log option '$opt', ignoring. Options are comma seperated. Include 'help' in the TM_LOG for all options. [finest,trace,debug,info,warn,help,all,caller,cfile,cfunc,datestamp,epoch,pid,timestamp,timing,user,stack]'"
        ;;
    esac
  done

  if [[ $help == 1 ]]; then
    >&2 cat << EOF
_tm::log::set_opts \$TM_LOG (provided: $TM_LOG)

Log options are comma seperated options. E.g. 'trace,all,stack,@foo*,@*bar*'

LEVEL OPTIONS:
 - finest|f
 - trace|t
 - debug|d
 - info|i   (default)
 - warn|w
 
INCLUDE OPTIONS:  (by default, all are off)
  - all          : shortcut for 'datestamp,pid,caller,user,timing'
  - cfile        : include the caller file
  - cfunc        : include the caller function
  - caller|call  : shortcut for 'cfile,cfunc'
  - proc|pid     : include the process id
  - timing       : include the length of timer since the logger was started
  - user         : include the current user

TIME STAMPS:
  - datestamp|ds : include the datestamp (implies timestamp)
  - epoch        : include the epoch
  - timestamp|ts : include the timestamp 

FILTERING OPTIONS:
  - @<logger-name> : the logger name to filter on. Can have multiple e.g. 
        @foobar* will only match any loggers starting with 'foobar'
        @*foobar* will only match any loggers containing 'foobar'
        
OTHER OPTIONS:  
  -stack : include the stacktrace to all the log calls
  -help  : print this help


This help was run as '\$TM_LOG'($TM_LOG) contained 'help'
EOF
  fi

  if [[ -z ${level:-} ]]; then
    level=$LEV_INFO
  fi

  local log_details=()
  if [[ $log_datestamp == true ]]; then
    log_details+=("\$(date +'%Y-%m-%d.%H:%M:%S.%3N')")
  elif [[ $log_timestamp == true ]]; then
    log_details+=("\$(date +'%H:%M:%S.%3N')")
  elif [[ $log_epoch == true ]]; then
    log_details+=("\${EPOCHREALTIME}")
  fi
  if [[ $log_timing == true ]]; then
    log_details+=("\$(_tm::log::__elapsed_time)")
  fi
  if [[ $log_call_file == true ]] && [[ $log_call_func == true ]]; then
    log_details+=("\$(_tm::log::__caller_file_func)")
  elif [[ $log_call_file == true ]]; then
    log_details+=("\$(_tm::log::__caller_file)")
  elif [[ $log_call_func == true ]]; then
    log_details+=("\$(_tm::log::__caller_func)")
  fi
  if [[ $log_user == true ]]; then
    log_details+=("\$USER")
  fi
  if [[ $log_pid == true ]]; then
    log_details+=("p\$BASHPID")
  fi
  
  if [[ "${#log_details[@]}" -ne 0 ]]; then
    local details="${log_details[@]}"
    local func_def="_tm::log::__details() {
        echo -n \"$details \" || true
    }"
    eval "$func_def"
  else # no-op
    _tm::log::__details(){ :; }
  fi
  
  if [[ $level -le $LEV_FINEST  ]] then
    _finest(){ _tm::log::finest "$@"; }
    _is_finest(){ return 1; }
  else
    _finest(){ :; }
    _is_finest(){ return 0; }
  fi
  if [[ $level -le $LEV_TRACE  ]] then
    _trace(){ _tm::log::trace "$@"; }
    _is_trace(){ return 1; }
  else
    _trace(){ :; }
    _is_trace(){ return 0; }
  fi
  if [[ $level -le $LEV_DEBUG  ]]; then
    _debug(){ _tm::log::debug "$@" ; }
    _is_debug(){ return 1; }
  else
    _debug(){ :; }
    _is_debug(){ return 0; }
  fi
  if [[ $level -le $LEV_INFO  ]]; then
    _info(){ _tm::log::info "$@"; }
  else
    _info(){ :; }
  fi
  if [[ $level -le $LEV_WARN  ]]; then
    _warn(){ _tm::log::warn "$@"; }
  else
    _warn(){ :; }
  fi

  if [[ ${#__tm_log_filters[@]} -ne 0 ]]; then
    # only include matching loggers
    _tm::log::__filter() {
        local log_name="$1"
        for logger in "${__tm_log_filters[@]}"; do
          if [[ "$log_name" == $logger ]]; then
              return 0
          fi
        done
        return 1
    }
  else # no-op
  _tm::log::__filter() {
    return 0
  }
  fi
}


#
# Print to console with no prefix. To stderr so it won't be used in function returns
#
_tm::log::println(){
  >&2 echo -e "$1"
}

_tm::log::print(){
  >&2 echo -n -e "$1"
}

_tm::log::__print(){
    >&2 echo -e "$1"
}

if [[ -n "$TM_LOG_FILE" ]]; then
  mkdir -p "$(dirname "$TM_LOG_FILE")"
  touch "$TM_LOG_FILE"

  _tm::log::__print(){
    echo -e "$1" >> "$TM_LOG_FILE"
    >&2 echo -e "$1"
  }
fi

########## Logging ###########

# Log an error message (red text)
#
# Args:
#   $@ - Error message to log
#
# Output:
#   Writes formatted error message to stderr
#
# Usage:
#   _err "Something went wrong"
#
_err() {
    _tm::log::__msg "ERR" "$COLOR_RED" $*
}

_error() {
    _tm::log::__msg "ERR" "$COLOR_RED" $*
}

# Log a warning message (red text)
#
# Args:
#   $@ - Warning message to log
#
# Output:
#   Writes formatted warning message to stderr
#
# Usage:
#   _warn "This might cause issues"
#
_tm::log::warn() {
  _tm::log::__msg "WRN" "$COLOR_RED" $*
}

_todo() {
  _tm::log::__msg "TODO" "$COLOR_RED" $*
}

# Log a standard message (green text)
#
# Args:
#   $1 - log level finest|trace|debug|info|warn|error/err
#   $2+ - Message to log
#
# Output:
#   Writes formatted message to stderr
#
# Usage:
#   _log "Processing complete"
#
_log() {
  case "${1:-}" in
    finest)
      shift
      _finest "$@"
      ;;
    trace)
      shift
      _trace "$@"
      ;;
    debug)
      shift
      _debug "$@"
      ;;
    info)
      shift
      _info "$@"
      ;;
    warn)
      shift
      _warn "$@"
      ;;
    error|err)
      shift
      _error "$@"
      ;;
    *)
      # assume user just wants to log to info
      _info "$@"
      ;;
  esac  
}

# Log an informational message (green text)
#
# Args:
#   $@ - Info message to log
#
# Output:
#   Writes formatted info message to stderr
#
# Usage:
#   _info "Operation completed successfully"
#
_tm::log::info() {
  _tm::log::__msg "INF" "$COLOR_GREEN" "$@"
}

# Log a debug message (grey text) if debug mode is enabled
#
# Args:
#   $@ - Debug message to log
#
# Output:
#   Writes formatted debug message to stderr if TM_LOG_DEBUG=1
#
# Usage:
#   _debug "Debug information"
#
_tm::log::debug() {
  _tm::log::__msg "DBG" "$COLOR_GREEN" "$@"
}

#
# if debug is enabled
#
# _is_debug(){
#   [[ $TM_LOG_LEVEL -le $LEV_DEBUG ]] && return 0 || return 1
# }

_tm::log::trace() {
  _tm::log::__msg "TRC" "$COLOR_GREY" "$@"
}

#
# if trace is enabled
#
# _is_trace(){
#   [[ $TM_LOG_LEVEL -le $LEV_TRACE ]] && return 0 || return 1
# }

_tm::log::finest() {
  _tm::log::__msg "FINEST" "$COLOR_GREY" "$@"
}

# _is_finest(){
#   [[ $TM_LOG_LEVEL -le $LEV_FINEST ]] && return 0 || return 1
# }

_tm::log::is_console(){
  [[ "$TM_LOG_CONSOLE" == '1' ]] && return 0 || return 1
}

# Log a message with color formatting
#
# Args:
#   $1 - Color code (e.g. $COLOR_RED, $COLOR_GREEN)
#   $@ - Message to log
#
# Output:
#   Writes formatted log message to stderr
#
# Usage:
#   _tm::log::__msg "$COLOR_RED" "Error message"
#
_tm::log::__msg() {
  # No need for the level check, as we replace the functions with no-op funcs in _tm::log::set_opts
  local level_name="$1"
  local color="$2"
  shift 2

  if ! _tm::log::__filter "$TM_LOG_NAME"; then
    return
  fi


  local logger_details="$(printf "%-12s" "$(_tm::log::__details)${TM_LOG_NAME}")"
  if [[ "${TM_LOG_CONSOLE:-}" == "1" ]]; then
    _tm::log::__to_console "$level_name" "$logger_details" "$color" "$@"
  fi
  if [[ "${TM_LOG_FILE:-}" == "1" ]]; then
    _tm::log::__to_file "$level_name" "$logger_details" "$@"
  fi
}

_tm::log::__to_console(){
  local level_name="$1"
  local logger_details="$2"
  local color="$3"
  shift 3

  >&2 echo -e "$(echo "${color}$@${COLOR_NONE}" | sed "s|^|${level_name} [${logger_details}] |" || true)"
  #>&2 echo -e "${color}${level_name} [${logger_details}]${COLOR_NONE} $@"
  _tm::log::__stack
}

_tm::log::__to_file(){
  local level_name="$1"
  local logger_details="$2"
  shift 2

  echo -e "$(echo "$@" | sed "s|^|$level_name [${logger_details}] |" || true)" >> "$TM_LOG_FILE" || true
  _tm::log::__stack >> "$TM_LOG_FILE" || true
}


# setup by _tm::log:set_opts
_tm::log::__stack(){
  :
}

# set by the the _tm::log::set_opts
_tm::log::__details(){
  :
}

# set by the the _tm::log::set_opts
_tm::log::__filter(){
  :
}

_tm::log::name(){
  if [[ "$1" != "$TM_LOG_NAME" ]]; then
    #_tm::log::finest "setting logname to '$1'"
    __tm_log_names+=("$TM_LOG_NAME")
    TM_LOG_NAME="$1"
  fi
}

_tm::log::child(){
  if [[ "$1" != "$TM_LOG_NAME" ]]; then
    local new_name="$TM_LOG_NAME/$1"
    __tm_log_names+=("$TM_LOG_NAME")
    TM_LOG_NAME="$new_name"
  fi
}

_tm::log::pop(){
  if [[ ${#__tm_log_names[@]} -gt 0 ]]; then

    TM_LOG_NAME="${__tm_log_names[-1]}"
    unset '__tm_log_names[-1]'
  fi
}

_tm::log::stacktrace(){
  local indent="${1:-}"
  >&2  echo "${indent}^^stacktrace^^:"
  local i=1 line file func
  # Loop through the call stack (excluding the stack_trace function itself)
  while IFS=' ' read -r line func file < <(caller $i); do
      # Print each frame of the stack: [frame_number] file:line function_name
    if [[ "$file" != *"/lib.log.sh" ]]; then # first non logger file
      >&2 echo "${indent}   [${i}]  ${file}:${line} ${func}()"
    fi
      ((i++))
  done
}

_tm::log::stacktrace::on_error(){
   trap _tm::log::stacktrace ERR
}


######## internal methods ##########

# Calculate elapsed time since script start
#
# Output:
#   Prints elapsed time
#
# Usage:
#   _tm::log::__elapsed_time
#
_tm::log::__elapsed_time() {
    echo "$(((`date +%s%N`-${__tm_log_starttime:-0})/1000000))ms"
}

_tm::log::__caller_file_func(){
  local i=0
  local line file func
  while IFS=' ' read -r line func file < <(caller $i); do         
    if [[ "$file" != *"/lib.log.sh" ]]; then # first non logger file
      echo -n "($(_tm::log::__safe_basename "${file}"):${line} ${func})"
      return
    fi    
    ((i++))
  done
}

_tm::log::__caller_file(){
  local i=0
  local line file func
  while IFS=' ' read -r line func file < <(caller $i); do         
    if [[ "$file" != *"/lib.log.sh" ]]; then # first non logger file
      echo -n "($(_tm::log::__safe_basename"${file}"):${line})"
      return
    fi
    ((i++))
  done
}

_tm::log::__caller_func(){
  local i=0
  local line file func
  while IFS=' ' read -r line func file < <(caller $i); do         
    if [[ "$file" != *"/lib.log.sh" ]]; then # first non logger file
      echo -n "(#${func})"
      return
    fi
    ((i++))
  done
}

_tm::log::__safe_basename(){
  local file="${1:-}"
  if [[ -z "${file}" ]]; then
    echo "?"
  else
    basename "${file}"
  fi
}


_tm::log::init

