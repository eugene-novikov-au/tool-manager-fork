
#
# Validate a given key/value pair
#
# Arguments
#
# $1 - the key. Used for error messages
# $2 - the value. The value to validate.
# $3 - the validators to use, comma separated
declare -A __tm_validators_by_name=(
  [nowhitespace]=" |whitespace"
  [noslashes]="/ |contain forward or back slashes"
  [alphanumeric]="^[a-zA-Z0-9]+$|be alphanumeric"
  [letters]="^[a-zA-Z]+$|contain only letters"
  [numbers]="^[0-9]+$|only numbers"
  [plugin-vendor]="^[a-zA-Z0-9][\.a-zA-Z0-9\-]*[a-zA-Z0-9]$|"
  [plugin-name]=""
  [plugin-prefix]="^[a-zA-Z0-9-]+$|alphanumeric or dashes"
  [space-key]="^[a-zA-Z0-9][\.a-zA-Z0-9-]+[a-zA-Z0-9]$|alphanumeric, dashes, or dots. Must start with a alphanumeric"
  [name]="^[\.a-zA-Z0-9-]+$|alphanumeric, dashes, or dots"
)

_tm::validate::key_value(){
  local key="$1"
  local value="$2"
  local validators_csv="$3"
  # run any provided validators
  if [[ -n "$value" ]] && [[ -n "${validators_csv}" ]]; then
    _is_finest && _finest "validating key '${key}' and value '${value}' with validators '${validators_csv}'"
    local -a validators
    IFS=',' read -ra validators <<< "$validators_csv"
    for validator in "${validators[@]}"; do
      local match=1
      case "${validator}" in
        +*)
          validator=${validator:1}
          ;;
        -*)
          validator=${validator:1}
          match=0
          ;;
      esac

      local validator_string="${__tm_validators_by_name["${validator}"]:-}"
      if [[ -z "${validator_string}" ]]; then
        _warn "Unknown validator '${validator}', skipping"
        continue
      fi

      # parse the 'validator_string' and extract the regxp (anything before the last '|'), and the validator desc (anything after the the last '|') ai!
      

      case "${validator}" in
        nowhitespace)
          [[ $match == 1 && "$value" =~ " " ]] && _fail "arg '${key}' with value '${value}' cannot contain whitespace (nowhitespace)" || true
          [[ $match == 0 && ! "$value" =~ " " ]] && _fail "arg '${key}' with value '${value}' must contain whitespace (-nowhitespace)" || true
          ;;
        noslashes)
          [[ $match == 1 ]] && { [[ "$value" =~ "/" ]] || [[ "$value" =~ "\\" ]]  }  && _fail "arg '${key}' with value '${value}' cannot contain forward or back slashes (noslashes)" || true
          [[ $match == 0 ]] && ! { [[ "$value" =~ "/" ]] || [[ "$value" =~ "\\" ]]  }  && _fail "arg '${key}' with value '${value}' must contain forward or back slashes (-noslashes)" || true
          ;;
        alphanumeric)
          [[ $match == 1 && ! "$value" =~ ^[a-zA-Z0-9]+$ ]] && _fail "arg '${key}' with value '${value}' must be alphanumeric (alphanumeric)" || true
          [[ $match == 0 && "$value" =~ ^[a-zA-Z0-9]+$ ]] && _fail "arg '${key}' with value '${value}' must not be alphanumeric (-alphanumeric)" || true
          ;;
        letters)
          [[ $match == 1 && ! "$value" =~ ^[a-zA-Z]+$ ]] && _fail "arg '${key}' with value '${value}' must contain only letters (letters)" || true
          [[ $match == 0 && "$value" =~ ^[a-zA-Z]+$ ]] && _fail "arg '${key}' with value '${value}' must not contain only letters (-letters)" || true
          ;;
        numbers)
          [[ $match == 1 && ! "$value" =~ ^[0-9]+$ ]] && _fail "arg '${key}' with value '${value}' must contain only numbers (numbers)" || true
          [[ $match == 0 && "$value" =~ ^[0-9]+$ ]] && _fail "arg '${key}' with value '${value}' must not contain only numbers (-numbers)" || true
          ;;
        plugin-vendor)
          [[ $match == 1 && ! "$value" =~ ^[a-zA-Z0-9][\.a-zA-Z0-9\-]*[a-zA-Z0-9]$ ]] && _fail "arg '${key}' with value '${value}' must contain only alphanumeric, dashes or dots (plugin-vendor)" || true
          [[ $match == 0 && "$value" =~ ^[a-zA-Z0-9][\.a-zA-Z0-9-]*[a-zA-Z0-9]$ ]] && _fail "arg '${key}' with value '${value}' must not contain  alphanumeric, dashes or dots (-plugin-vendor)" || true
          ;;
        plugin-name)
#              [[ $match == 1 && ! "$value" =~ ^(?:([a-zA-Z0-9-]+):)?(?:([a-zA-Z0-9-]+)\/)?([a-zA-Z0-9-]+)(?:@([a-zA-Z0-9-.]+))?$ ]] && _fail "arg '${key}' with value '${value}' must be a valid plugin name: 'name', 'prefix:name' 'prefix:vendor/name', where these can only contains 'a-zA-Z0-9' and '-'. Name may have a '@version' added (plugin-name)" || true
#              [[ $match == 0 && "$value" =~ ^(?:([a-zA-Z0-9-]+):)?(?:([a-zA-Z0-9-]+)\/)?([a-zA-Z0-9-]+)(?:@([a-zA-Z0-9-.]+))?$ ]] && _fail "arg '${key}' with value '${value}' must not be a valid plugin name: 'name', 'prefix:name' 'prefix:vendor/name', where these can only contains 'a-zA-Z0-9' and '-'. Name may have a '@version' added (-plugin-name)" || true
          ;;
        plugin-prefix)
          [[ $match == 1 && ! "$value" =~ ^[a-zA-Z0-9-]+$ ]] && _fail "arg '${key}' with value '${value}' must contain only alphanumeric or dashes (plugin-prefix)" || true
          [[ $match == 0 && "$value" =~ ^[a-zA-Z0-9-]+$ ]] && _fail "arg '${key}' with value '${value}' must not contain only alphanumeric or dashes (-plugin-prefix)" || true
          ;;
        space-key)
          [[ $match == 1 && ! "$value" =~ ^[a-zA-Z0-9][\.a-zA-Z0-9-]+[a-zA-Z0-9]$ ]] && _fail "arg '${key}' with value '${value}' must contain only alphanumeric, dashes, or dots. Mut start with a alphanumeric (space-key)" || true
          [[ $match == 0 && "$value" =~ ^[a-zA-Z0-9][\.a-zA-Z0-9-].+[a-zA-Z0-9]$ ]] && _fail "arg '${key}' with value '${value}' must not contain alphanumeric, dashes, or dots (-space-key)" || true
          ;;
        name) # generic name field
          [[ $match == 1 && ! "$value" =~ ^[\.a-zA-Z0-9-]+$ ]] && _fail "arg '${key}' with value '${value}' must contain only alphanumeric, dashes, or dots (name)" || true
          [[ $match == 0 && "$value" =~ ^[\.a-zA-Z0-9-].+$ ]] && _fail "arg '${key}' with value '${value}' must not contain alphanumeric, dashes, or dots (-name)" || true
          ;;
        re:*)
          local regexp="^${validator#re:}+$"
          _finest "using re:${regexp}"
          [[ $match == 1 && ! "$value" =~ ${regexp} ]] && _fail "arg '${key}' with value '${value}' does not match pattern '${regexp}' (re)" || true
          [[ $match == 0 && "$value" =~ ${regexp} ]] && _fail "arg '${key}' with value '${value}' must not match pattern '${regexp}' (re)" || true
          ;;
        *)
          _warn "Unknown validator '${validator}', skipping"
      esac

    done
  fi
}