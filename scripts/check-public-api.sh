#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${THEOS:-}" ]]; then
    echo "THEOS is required." >&2
    exit 1
fi

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
staging_dir="${THEOS_STAGING_DIR:-${project_root}/.theos/_}"
sdk="${THEOS}/sdks/iPhoneOS16.5.sdk"
clang="${CLANG:-$(xcrun -f clang)}"
nm_tool="${NM:-$(xcrun -f nm)}"

if [[ ! -d "${sdk}" ]]; then
    echo "SDK not found: ${sdk}" >&2
    exit 1
fi

if [[ ! -d "${staging_dir}" ]]; then
    echo "Staging directory not found: ${staging_dir}" >&2
    exit 1
fi

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/libactivator-public-api-check.XXXXXX")"
trap 'rm -rf "${tmp_dir}"' EXIT

common_flags=(
    -target arm64-apple-ios15.0
    -isysroot "${sdk}"
    -miphoneos-version-min=15.0
    -fobjc-arc
    -fmodules
    -fmodules-cache-path="${tmp_dir}/module-cache"
    -I "${staging_dir}/usr/include"
    -F "${staging_dir}/Library/Frameworks"
)

cat > "${tmp_dir}/flat-import.m" <<'EOF'
#import <libactivator.h>

void LAFlatImportCheck(void) {
    LAEvent *event = [LAEvent eventWithName:LAEventNameMenuPressSingle mode:LAEventModeSpringBoard];
    event.userInfo = @{ LAEventUserInfoDisplayIdentifier: @"com.apple.springboard" };
    (void)[[LAActivator sharedInstance] version];
}
EOF

cat > "${tmp_dir}/framework-import.m" <<'EOF'
#import <Activator/Activator.h>

void LAFrameworkImportCheck(void) {
    LAActivator *activator = [LAActivator sharedInstance];
    LAEvent *event = [[LAEvent alloc] initWithName:LAEventNameStatusBarTapSingle mode:LAEventModeApplication];
    [activator sendEvent:event toListenersWithNames:@[]];
    UIImageView *imageView = [UIImageView new];
    imageView.activatorListenerName = @"example.listener";
    imageView.activatorListenerImageIsThreaded = YES;
    (void)[LARootSettingsController controller];
    (void)LASharedActivator;
}
EOF

cat > "${tmp_dir}/module-import.m" <<'EOF'
@import Activator;

void LAModuleImportCheck(void) {
    LAActivator *activator = [LAActivator sharedInstance];
    if (activator.version != LAActivatorVersion_2_0) {
        __builtin_trap();
    }
    (void)LAActivatorAssignmentsChangedNotification;
}
EOF

"${clang}" "${common_flags[@]}" -fsyntax-only "${tmp_dir}/flat-import.m"
"${clang}" "${common_flags[@]}" -fsyntax-only "${tmp_dir}/framework-import.m"
"${clang}" "${common_flags[@]}" -fsyntax-only "${tmp_dir}/module-import.m"

"${clang}" "${common_flags[@]}" -c "${tmp_dir}/framework-import.m" -o "${tmp_dir}/framework-import.o"
"${clang}" \
    -target arm64-apple-ios15.0 \
    -isysroot "${sdk}" \
    -miphoneos-version-min=15.0 \
    -dynamiclib \
    "${tmp_dir}/framework-import.o" \
    -L "${staging_dir}/usr/lib" \
    -lactivator \
    -framework Foundation \
    -framework UIKit \
    -o "${tmp_dir}/libactivator-public-api-check.dylib"

"${nm_tool}" -gU "${staging_dir}/usr/lib/libactivator.dylib" > "${tmp_dir}/symbols.txt"

required_symbols=(
    "_LASharedActivator"
    "_LAEventNameMenuPressSingle"
    "_LAEventModeSpringBoard"
    "_LAActivatorAssignmentsChangedNotification"
    '_OBJC_CLASS_$_LAActivator'
    '_OBJC_CLASS_$_LAEvent'
    '_OBJC_CLASS_$_LASettingsViewController'
    '_OBJC_CLASS_$_LARootSettingsController'
    '_OBJC_CLASS_$_LAEventConfigurationViewController'
    '_OBJC_CLASS_$_LAListenerConfigurationViewController'
)

for symbol in "${required_symbols[@]}"; do
    if ! grep -Fq "${symbol}" "${tmp_dir}/symbols.txt"; then
        echo "Missing public symbol: ${symbol}" >&2
        exit 1
    fi
done

echo "Public API compile/link check passed."
