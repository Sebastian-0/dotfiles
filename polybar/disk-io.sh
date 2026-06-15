#!/bin/bash

# Disk I/O utilization (%util, like the column reported by iostat): the
# percentage of wall-clock time the device spent servicing read/write requests.
# Derived from the io_ticks counter in /proc/diskstats (field 13, the number of
# milliseconds the device has been busy) divided by the elapsed wall time since
# the previous sample. State is kept in a temp file so each polybar tick simply
# diffs against the last one instead of blocking on a sleep.

# Copied from polybar config, currently not possible to pass here without an
# ugly solution: https://github.com/polybar/polybar/issues/585
COLOR_PRIMARY="#7AA2F7"
ICON="󰠳"

render() {
    printf '%%{F%s}%s%%{F-} %s\n' "$COLOR_PRIMARY" "$ICON" "$1"
}

# Resolve the whole disk backing the root filesystem (e.g. nvme0n1, sda).
SRC="$(findmnt -no SOURCE / 2> /dev/null)"
DEV="$(lsblk -no PKNAME "$SRC" 2> /dev/null | head -1)"
if [ -z "$DEV" ]; then
    # Fall back to the device itself when it has no parent (e.g. a raw disk).
    DEV="$(lsblk -no KNAME "$SRC" 2> /dev/null | head -1)"
fi
if [ -z "$DEV" ]; then
    render "--%"
    exit 0
fi

STATE="/tmp/polybar_disk_io_$DEV"

# Current busy-time counter (ms) and a nanosecond timestamp to measure against.
CUR_TICKS="$(awk -v d="$DEV" '$3 == d { print $13; exit }' /proc/diskstats)"
CUR_TIME="$(date +%s%N)"

if [ -z "$CUR_TICKS" ]; then
    render "--%"
    exit 0
fi

UTIL="--"
if [ -f "$STATE" ]; then
    read -r PREV_TICKS PREV_TIME < "$STATE"
    UTIL="$(awk -v ct="$CUR_TICKS" -v pt="$PREV_TICKS" -v cn="$CUR_TIME" -v pn="$PREV_TIME" 'BEGIN {
        elapsed_ms = (cn - pn) / 1000000.0
        if (elapsed_ms <= 0) { print "--"; exit }
        u = (ct - pt) * 100.0 / elapsed_ms
        if (u < 0) u = 0
        if (u > 100) u = 100
        printf "%.0f", u
    }')"
fi

# Persist this sample for the next tick to diff against.
printf '%s %s\n' "$CUR_TICKS" "$CUR_TIME" > "$STATE"

render "$UTIL%"
