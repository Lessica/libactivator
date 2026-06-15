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

device_architecture() {
    ssh -p "${THEOS_DEVICE_PORT:-22}" "${THEOS_DEVICE_USER:-root}@${THEOS_DEVICE_IP}" \
        'dpkg --print-architecture 2>/dev/null || uname -m'
}

expected_device_architecture() {
    case "${THEOS_PACKAGE_SCHEME:-}" in
        rootless)
            echo "iphoneos-arm64"
            ;;
        roothide)
            echo "iphoneos-arm64e"
            ;;
        *)
            echo ""
            ;;
    esac
}

test_runner_path="${LA_TEST_RUNNER_PATH:-/usr/libexec/libactivator/libactivator-tests}"
if [ "${THEOS_PACKAGE_SCHEME:-}" = "rootless" ]; then
    test_runner_path="${LA_TEST_RUNNER_PATH:-/var/jb/usr/libexec/libactivator/libactivator-tests}"
fi

if [ -z "${THEOS_DEVICE_IP:-}" ]; then
    echo "[tests] THEOS_DEVICE_IP is not set; source the matching device environment first" >&2
    exit 2
fi

echo "[tests] Package scheme: ${THEOS_PACKAGE_SCHEME:-rootful}"
echo "[tests] Device target: ${THEOS_DEVICE_USER:-root}@${THEOS_DEVICE_IP}:${THEOS_DEVICE_PORT:-22}"
echo "[tests] Test runner path: ${test_runner_path}"

expected_architecture="$(expected_device_architecture)"
if [ -n "$expected_architecture" ]; then
    actual_architecture="$(device_architecture)"
    echo "[tests] Device architecture: ${actual_architecture}"
    if [ "$actual_architecture" != "$expected_architecture" ]; then
        echo "[tests] Device architecture ${actual_architecture} does not match ${THEOS_PACKAGE_SCHEME} package architecture ${expected_architecture}" >&2
        exit 2
    fi
fi

# shellcheck disable=SC1010
gmake clean do LIBACTIVATOR_TEST_SUPPORT=1

springboard_pid_before="$(wait_for_springboard_pid)"
echo "[tests] SpringBoard pid before runner: ${springboard_pid_before}"

echo "[tests] Running stable tests with ${test_runner_path} on ${THEOS_DEVICE_IP}"
set +e
ssh -p "${THEOS_DEVICE_PORT:-22}" "${THEOS_DEVICE_USER:-root}@${THEOS_DEVICE_IP}" \
    "${test_runner_path}"
runner_status="$?"
set -e

springboard_pid_after="$(wait_for_springboard_pid)"
echo "[tests] SpringBoard pid after runner: ${springboard_pid_after}"

if [ -n "$springboard_pid_before" ] && [ "$springboard_pid_before" != "$springboard_pid_after" ]; then
    echo "[tests] SpringBoard restarted during tests" >&2
    exit 3
fi

exit "$runner_status"
