#!/bin/sh
set -eu

if [ "$#" -ne 0 ]; then
    echo "usage: scripts/stage-public-headers.sh" >&2
    exit 64
fi

if [ -z "${THEOS_STAGING_DIR:-}" ]; then
    echo "missing THEOS_STAGING_DIR" >&2
    exit 64
fi

if [ ! -d "include/Activator" ]; then
    echo "missing include/Activator" >&2
    exit 66
fi

if [ ! -d "include/ActivatorSettings" ]; then
    echo "missing include/ActivatorSettings" >&2
    exit 66
fi

activator_headers="${THEOS_STAGING_DIR}/Library/Frameworks/Activator.framework/Headers"
settings_headers="${THEOS_STAGING_DIR}/Library/Frameworks/ActivatorSettings.framework/Headers"

mkdir -p "${activator_headers}"
mkdir -p "${settings_headers}"

rm -f "${activator_headers}/.gitkeep"
rm -f "${settings_headers}/.gitkeep"

cp -R include/Activator/. "${activator_headers}/"
cp -R include/ActivatorSettings/. "${settings_headers}/"
