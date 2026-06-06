#!/bin/sh
set -eu

activator_headers="${THEOS_STAGING_DIR}/Library/Frameworks/Activator.framework/Headers"
settings_headers="${THEOS_STAGING_DIR}/Library/Frameworks/ActivatorSettings.framework/Headers"

mkdir -p "${activator_headers}"
mkdir -p "${settings_headers}"

rm -f "${activator_headers}/.gitkeep"
rm -f "${settings_headers}/.gitkeep"

cp -R include/Activator/. "${activator_headers}/"
cp -R include/ActivatorSettings/. "${settings_headers}/"
