#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python="${PYTHON:-${project_root}/.venv/bin/python}"

if [[ ! -x "${python}" ]]; then
    python="${PYTHON:-python3}"
fi

exec "${python}" "${project_root}/scripts/check-public-api.py" "$@"
