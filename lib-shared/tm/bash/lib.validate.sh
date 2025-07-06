
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

      local regexp=""
      local description=""
      IFS='|' read -r regexp description <<< "${validator_string}"

      case "${validator}" in
        nowhitespace)
          [[ $match == 1 && "$value" =~ ${regexp} ]] && _fail "arg '${key}' with value '${value}' cannot ${description} (${validator})" || true
          [[ $match == 0 && ! "$value" =~ ${regexp} ]] && _fail "arg '${key}' with value '${value}' must ${description} (-${validator})" || true
          ;;
        noslashes)
          # Specific logic for slashes, as the regex in __tm_validators_by_name is not directly usable with =~
          [[ $match == 1 ]] && { [[ "$value" =~ "/" ]] || [[ "$value" =~ "\\" ]]  }  && _fail "arg '${key}' with value '${value}' cannot ${description} (${validator})" || true
          [[ $match == 0 ]] && ! { [[ "$value" =~ "/" ]] || [[ "$value" =~ "\\" ]]  }  && _fail "arg '${key}' with value '${value}' must ${description} (-${validator})" || true
          ;;
        plugin-name)
#              [[ $match == 1 && ! "$value" =~ ^(?:([a-zA-Z0-9-]+):)?(?:([a-zA-Z0-9-]+)\/)?([a-zA-Z0-9-]+)(?:@([a-zA-Z0-9-.]+))?$ ]] && _fail "arg '${key}' with value '${value}' must be a valid plugin name: 'name', 'prefix:name' 'prefix:vendor/name', where these can only contains 'a-zA-Z0-9' and '-'. Name may have a '@version' added (plugin-name)" || true
#              [[ $match == 0 && "$value" =~ ^(?:([a-zA-Z0-9-]+):)?(?:([a-zA-Z0-9-]+)\/)?([a-zA-Z0-9-]+)(?:@([a-zA-Z0-9-.]+))?$ ]] && _fail "arg '${key}' with value '${value}' must not be a valid plugin name: 'name', 'prefix:name' 'prefix:vendor/name', where these can only contains 'a-zA-Z0-9' and '-'. Name may have a '@version' added (-plugin-name)" || true
          ;;
        re:*)
          local custom_regexp="^${validator#re:}+$"
          _finest "using re:${custom_regexp}"
          [[ $match == 1 && ! "$value" =~ ${custom_regexp} ]] && _fail "arg '${key}' with value '${value}' does not match pattern '${custom_regexp}' (re)" || true
          [[ $match == 0 && "$value" =~ ${custom_regexp} ]] && _fail "arg '${key}' with value '${value}' must not match pattern '${custom_regexp}' (re)" || true
          ;;
        *)
          # Generic regex validation for alphanumeric, letters, numbers, plugin-vendor, plugin-prefix, space-key, name
          # Using the extracted 'regexp' and 'description' from __tm_validators_by_name for these
          [[ $match == 1 && ! "$value" =~ ${regexp} ]] && _fail "arg '${key}' with value '${value}' must ${description} (${validator})" || true
          [[ $match == 0 && "$value" =~ ${regexp} ]] && _fail "arg '${key}' with value '${value}' must not ${description} (-${validator})" || true
          ;;
      esac

    done
  fi
}
