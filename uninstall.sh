#!/usr/bin/env bash
#
# uninstall.sh - remove Tool Manager and all plugins
#
# This script deletes the ~/.tool-manager directory and
# removes any sourcing lines from ~/.bashrc and ~/.profile
# that were added by the installer.

set -e

log_prefix="[tool-manager uninstall]"

# Determine installation directory
TM_HOME="${TM_HOME:-$HOME/.tool-manager}"
HOME_BASHRC="$HOME/.bashrc"
HOME_PROFILE="$HOME/.profile"

_remove_tm_lines() {
    local file="$1"
    if [[ -f "$file" ]]; then
        # Remove block added by the installer
        sed -i '' '/# Added by Tool Manager install script/,/fi$/d' "$file"
        # Remove any remaining references to the tm bashrc
        sed -i '' '/\.tool-manager\/\.bashrc/d' "$file"
    fi
}

if [[ -d "$TM_HOME" ]]; then
    echo "${log_prefix} Removing '$TM_HOME'"
    rm -rf "$TM_HOME"
    echo "${log_prefix} Directory removed"
else
    echo "${log_prefix} No install directory found at '$TM_HOME'"
fi

_remove_tm_lines "$HOME_BASHRC"
_remove_tm_lines "$HOME_PROFILE"

# Unset all environment variables that start with TM_
for var in $(env | grep ^TM_ | cut -d= -f1); do
    echo "${log_prefix} Unsetting $var"
    unset "$var"
done

echo "${log_prefix} Uninstall complete"
