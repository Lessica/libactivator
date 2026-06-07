#!/bin/sh

set -e

springboard_pid() {
    ssh -p "${THEOS_DEVICE_PORT:-22}" "${THEOS_DEVICE_USER:-root}@${THEOS_DEVICE_IP}" \
        'launchctl print system/com.apple.SpringBoard 2>/dev/null' | awk '/pid =/{print $3; exit}'
}

wait_for_springboard_pid() {
    count=0
    while [ "$count" -lt 10 ]; do
        pid="$(springboard_pid)"
        if [ -n "$pid" ]; then
            echo "$pid"
            return 0
        fi
        count=$((count + 1))
        sleep 1
    done
}

# shellcheck disable=SC1010
gmake clean do LA_TESTING=1

springboard_pid_before="$(wait_for_springboard_pid)"
echo "[tests] SpringBoard pid before runner: ${springboard_pid_before}"

echo "[tests] Running stable tests with ${LA_TEST_RUNNER_PATH:-/usr/libexec/libactivator/libactivator-tests} on ${THEOS_DEVICE_IP}"
set +e
ssh -p "${THEOS_DEVICE_PORT:-22}" "${THEOS_DEVICE_USER:-root}@${THEOS_DEVICE_IP}" \
    "${LA_TEST_RUNNER_PATH:-/usr/libexec/libactivator/libactivator-tests}"
runner_status="$?"
set -e

springboard_pid_after="$(wait_for_springboard_pid)"
echo "[tests] SpringBoard pid after runner: ${springboard_pid_after}"

if [ -n "$springboard_pid_before" ] && [ "$springboard_pid_before" != "$springboard_pid_after" ]; then
    echo "[tests] SpringBoard restarted during tests" >&2
    exit 3
fi

exit "$runner_status"
