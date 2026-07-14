#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_STAGING_DIR="${PROJECT_ROOT}/.theos/_"
if [[ "${THEOS_PACKAGE_SCHEME:-}" == "rootless" && -f "${PROJECT_ROOT}/.theos/_/var/jb/usr/lib/libactivator.dylib" ]]; then
    DEFAULT_STAGING_DIR="${PROJECT_ROOT}/.theos/_/var/jb"
fi
export THEOS_STAGING_DIR="${THEOS_STAGING_DIR:-${DEFAULT_STAGING_DIR}}"

exec "${PYTHON:-${PROJECT_ROOT}/.venv/bin/python}" "${PROJECT_ROOT}/scripts/_check-public-api.py" "$@"
