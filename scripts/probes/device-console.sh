#!/bin/sh

set -e

mode="${1:-stream}"
processes="${LA_CONSOLE_PROCESSES:-SpringBoard|backboardd|libactivator-tests}"

case "$mode" in
    stream)
        idevicesyslog --no-colors -p "$processes"
        ;;
    *)
        echo "Usage: scripts/device-console.sh [stream]" >&2
        exit 2
        ;;
esac
