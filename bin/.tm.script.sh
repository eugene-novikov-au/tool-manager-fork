#
# Scripts should generall source this script by default to include the common setup
#

# make the scripts fail fast
set -Eeuo pipefail

_tm::source::include_once @tm/lib.common.sh
_tm::source::once "$TM_BIN/.tm.common.sh"

_trap_error