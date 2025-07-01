source "$TM_LIB_BASH/lib.log.sh"

_tm::venv::provision(){
  local script_file="${1:-}"
  #local plugin_id="$2"

  if [[ -z "${script_file}" ]]; then
    _fail "pass a script file to provision"
  fi

  local directive_file="${script_file}.${__TM_VENV_REQUIRES_SUFFIX}"
  if [[ ! -f "$directive_file" ]]; then
    return 0 # nothing to do
  fi


}