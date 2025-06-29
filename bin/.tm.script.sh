#
# Scripts should generall source this script by default to include the common setup
#

# make the scripts fail fast
set -Eeuo pipefail

_tm::source::include_once @tm/lib.common.sh
_tm::source::once "$TM_BIN/.tm.common.sh"

#
# _trap_error
#
# Sets up a trap to catch the EXIT signal, ensuring that the _tm::error::trap_handler
# function is called when the script exits due to an error. This is crucial for
# proper error handling and cleanup in Tool Manager scripts.
#
# This function is typically sourced by all Tool Manager scripts via `bin/.tm.script.sh`.
#
# Usage:
#   _trap_error
#
# Dependencies:
#   - _tm::error::trap_handler (defined in lib/bash/tm/lib.error.sh)
#
_trap_error