
#
# INitialise the tool-manager (tm)
#

__tm_bashrc_init(){
    # Controls whether the Tool Manager and its plugins are loaded.
    # Set to "0" to disable tm loading. Defaults to "1" (enabled).
    export TM_ENABLED="${TM_ENABLED:-1}"
    if [[ "$TM_ENABLED" == "1" ]]; then
        source "$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)/bin/.tm.boot.sh"
        #_tm::boot::load
    fi
}

__tm_bashrc_init
