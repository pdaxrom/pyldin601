#!/bin/sh
# UniAS is the only assembler. Keep its output local (its pathname buffers are short).
set -eu
log=$1
assembler=$2
shift 2
if ! "$assembler" "$@" > "$log" 2>&1; then
    cat "$log" >&2
    exit 1
fi
if grep -E 'Error:|symbol table full' "$log" >/dev/null; then
    cat "$log" >&2
    exit 1
fi
