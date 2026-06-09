#!/bin/sh

# Usage:
#   . scripts/roothide.sh
#   scripts/watch-runtime-state.sh
#   . scripts/rootless.sh
#   scripts/watch-runtime-state.sh
#
# Environment:
#   THEOS_DEVICE_IP and THEOS_DEVICE_PORT are expected to be provided by the
#   active Theos environment script.
#   THEOS_DEVICE_USER may override the SSH user; root is used by default.
#   LA_TEST_RUNNER_PATH may override the on-device test runner path.

set -e

test_runner_path="${LA_TEST_RUNNER_PATH:-/usr/libexec/libactivator/libactivator-tests}"
if [ "${THEOS_PACKAGE_SCHEME:-}" = "rootless" ]; then
    test_runner_path="${LA_TEST_RUNNER_PATH:-/var/jb/usr/libexec/libactivator/libactivator-tests}"
fi

ssh -p "${THEOS_DEVICE_PORT:-22}" "${THEOS_DEVICE_USER:-root}@${THEOS_DEVICE_IP}" \
    "${test_runner_path} watch-runtime"
