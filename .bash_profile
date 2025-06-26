
#
# Tool Manager - Main .bashrc
#
# This script is sourced by the user's main ~/.bash_profile.
# It initializes the Tool Manager environment by:
# 1. Sourcing the core bootstrap script (bin/.tm.boot.sh).
# 2. Conditionally loading plugins and commands via _tm::boot::load
#    if TM_ENABLED is set to "1".
#

__tm_bash_profile_init(){
    # Controls whether the Tool Manager and its plugins are loaded.
    # Set to "0" to disable tm loading. Defaults to "1" (enabled).
    export TM_ENABLED="${TM_ENABLED:-1}"
    if [[ "$TM_ENABLED" == "1" ]]; then
        source "$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)/bin/.tm.boot.sh"
        _tm::boot::load
    fi
}

__tm_bash_profile_init
