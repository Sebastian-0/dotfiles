nanos_to_str() {
    local time_ns=$1
    shift

    local time_us=$((time_ns / 1000))
    local us=$((time_us % 1000))
    local ms=$(((time_us / 1000) % 1000))
    local s=$(((time_us / 1000000) % 60))
    local m=$(((time_us / 60000000) % 60))
    local h=$((time_us / 3600000000))
    # Goal: always show around 3 digits of accuracy
    if ((h > 0)); then
        text=${h}h${m}m
    elif ((m > 0)); then
        text=${m}m${s}s
    elif ((s >= 10)); then
        text=${s}.$((ms / 100))s
    elif ((s > 0)); then
        text=${s}.$(printf %03d $ms)s
    elif ((ms >= 100)); then
        text=${ms}ms
    elif ((ms > 0)); then
        text=${ms}.$((us / 100))ms
    else
        text=${us}µs
    fi
    echo "$text"
}
