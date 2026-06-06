#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export THEOS_STAGING_DIR="${THEOS_STAGING_DIR:-${PROJECT_ROOT}/.theos/_}"

exec "${PYTHON:-${PROJECT_ROOT}/.venv/bin/python}" "${PROJECT_ROOT}/scripts/_check-public-api.py" "$@"
