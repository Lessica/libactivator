#!/bin/sh

set -e

action="${1:-pull}"
local_dir="${LA_CRASHLOG_DIR:-logs/device-crashlogs}"

case "$action" in
    list)
        mkdir -p "$local_dir"
        idevicecrashreport -k -f SpringBoard "$local_dir"
        find "$local_dir" -maxdepth 1 -name 'SpringBoard*' -type f -print | sort
        ;;
    clean)
        mkdir -p "$local_dir/cleared"
        idevicecrashreport -f SpringBoard "$local_dir/cleared"
        ;;
    pull)
        mkdir -p "$local_dir"
        idevicecrashreport -k -f SpringBoard "$local_dir"
        ;;
    *)
        echo "Usage: scripts/device-crashlogs.sh [list|clean|pull]" >&2
        exit 2
        ;;
esac
