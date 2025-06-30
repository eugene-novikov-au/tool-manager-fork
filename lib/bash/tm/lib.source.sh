# end early if already setup
if command -v _tm::source &>/dev/null; then
  return
fi

#
# For users
#
_source() { 
  _tm::source "$@"
}

_source_once() { 
  _tm::source::once "$@"
}

_include() {
  _tm::source::__include "${BASH_SOURCE[1]}" "$@"
}

_include_once() {
  _tm::source::__include_once "${BASH_SOURCE[1]}" "$@"
}

#
# Called internall by all the functions, to ensure the arrays are setup. These functions could be called
# by user scripts, in which case the entry point is the functiion, not the 'source path/to/this/script'
# and hence we need to check the init was carried out
#
_tm::source::__init(){
    if [[ ! -v __tm_source_inited ]]; then
      # associative array are buggy. We need to declare them in a spcial way to ensure they work
      # see https://stackoverflow.com/questions/10806357/associative-arrays-are-local-by-default
      
      __tm_source_inited=1

      declare -gA __tm_source_to_dir
      declare -gA __tm_sourced

      __tm_source_to_dir=()
      __tm_sourced=()
      if [[ ! $(type -t _trace) == function ]]; then
        __tm_sourced+=( "$TM_LIB_BASH/tm/lib.source.sh" "$TM_LIB_BASH/tm/lib.log.sh" )
      fi
   fi
   # ensure the logging functions are loaded
   if ! command -v _tm::log::name &>/dev/null; then
      source "$TM_LIB_BASH/tm/lib.log.sh"
   fi
}

_tm::source::include_once(){
  _tm::source::__include_once "${BASH_SOURCE[1]}" "$@"
}

_tm::source::include(){
  _tm::source::__include "${BASH_SOURCE[1]}" "$@"
}

_tm::source::__include_once(){
  _tm::source::__init
  local calling_script="$1"
  shift
  local script_dir=''
  local base_dir=''
  for file in "$@"; do
    if _is_finest; then
      _finest "include once '$file' (from $calling_script)" 
    fi
    if [[ "$file" == "tm/"* ]]; then
      base_dir="$TM_LIB_BASH"
    elif [[ "$file" == "@tm/"* ]]; then
      base_dir="$TM_LIB_BASH"
      file="${file:1}"
      if [[ "$file" != *".sh" ]]; then
        file+=".sh"
      fi
    elif [[ "$file" == "lib."* ]]; then # deprecated!
      _warn "deprecated import '$file', use 'tm/$file' instead"
      base_dir="$TM_LIB_BASH/tm"
    else
      if [[ -z "${script_dir}" ]]; then # lazy calc once for this include
        # get the cached script dir
        script_dir="${__tm_source_to_dir["$calling_script"]:-}"
        if [[ -z "$script_dir" ]]; then # calc and cache the scripts dir
          script_dir="$( cd "$( dirname "$calling_script" )" &> /dev/null && pwd )"
          __tm_source_to_dir["$script_dir"]="$script_dir"
        fi
      fi
      base_dir="${script_dir}"
    fi
    _tm::source::once "$base_dir/$file"
  done
}

_tm::source::__include(){
  _tm::source::__init
  local calling_script="$1"
  shift
  local script_dir=''
  local base_dir=''
  for file in "$@"; do
    _finest "include '$file' (from $calling_script)" 
  
    if [[ "$file" == "tm/"* ]]; then
      base_dir="$TM_LIB_BASH"
    elif [[ "$file" == "@tm/"* ]]; then
      base_dir="$TM_LIB_BASH"
      file="${file:1}"
      if [[ "$file" != *".sh" ]]; then
        file+=".sh"
      fi
    elif [[ "$file" == "lib."* ]]; then # deprecated!
      _warn "deprecated import '$file', use 'tm/$file' instead"
      base_dir="$TM_LIB_BASH/tm"
    else
      if [[ -z "${script_dir}" ]]; then # lazy calc once for this include
        # get the cached script dir
        script_dir="${__tm_source_to_dir["$calling_script"]:-}"
        if [[ -z "$script_dir" ]]; then # calc and cache the scripts dir
          script_dir="$( cd "$( dirname "$calling_script" )" &> /dev/null && pwd )"
          __tm_source_to_dir["$script_dir"]="$script_dir"
        fi
      fi
      base_dir="${script_dir}"
    fi
    _tm::source "$base_dir/$file"
  done
}

# Sources a given Bash script file only if it has not already been sourced
# in the current shell session. This prevents redundant loading and potential errors.
#
# Args:
#   $1 - file: The full path to the script file to be sourced.
#
_tm::source::once(){
  _tm::source::__init
  for file in "$@"; do
    if [[ -n "${__tm_sourced["$file"]:-}" ]]; then
      _finest "already sourced: '$file'"
    else
      _finest "source once '$file'"
      _tm::source "$file"
    fi
  done
}

_tm::source(){
  _tm::source::__init
  local file="$1"
  _trace "source '$file'"
  __tm_sourced["$file"]='1' # flag as sourced
  if [[  -f "$file" ]]; then
    builtin source "$file" 
  else
    # find the caller of the source
    local msg="Can't source '$file'"
    local i=1
    local calls_func=''
    local add_location=0
    while read -r line func func_file < <(caller $i); do         
        if [[ "$func_file" != *"/lib.source.sh" ]]; then # first non lib source stack (ignore all the the _tm::source and _tm::include etc)
          msg+=" at ${func_file}:${line}#${calls_func}()"
          add_location=1
        fi
        if [[ $add_location == 1 ]] && [[ "$func_file" != *"/lib." ]]; then # first non lib stack (so user call)
          break
        fi        
        calls_func="$func"
        ((i++))
    done

    _fail "$msg"
  fi
}

_tm::source::__init