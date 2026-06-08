#!/usr/bin/env python3
from __future__ import annotations

import os
import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

try:
    import lief
except ImportError as exc:
    raise SystemExit(
        "Missing Python dependency: lief. "
        "Create a virtual environment and run: "
        "python -m pip install -r scripts/requirements.txt"
    ) from exc


@dataclass(frozen=True)
class MethodDecl:
    owner: str
    selector: str
    kind: str
    context_kind: str


@dataclass(frozen=True)
class PropertyDecl:
    owner: str
    name: str
    attributes: tuple[str, ...]
    context_kind: str
    category_name: str | None = None


@dataclass
class HeaderAPI:
    constants: set[str] = field(default_factory=set)
    globals: set[str] = field(default_factory=set)
    classes: set[str] = field(default_factory=set)
    categories: set[tuple[str, str]] = field(default_factory=set)
    protocols: set[str] = field(default_factory=set)
    methods: list[MethodDecl] = field(default_factory=list)
    properties: list[PropertyDecl] = field(default_factory=list)


FORBIDDEN_SELECTORS = {
    "requiresIconDataForListenerName:scale:",
    "requiresIconDataForListenerName:",
    "requiresIconForListenerName:scale:",
}


def log(message: str) -> None:
    print(f"[public-api] {message}")


def run(command: list[str], *, cwd: Path | None = None) -> str:
    try:
        result = subprocess.run(
            command,
            cwd=str(cwd) if cwd else None,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
    except subprocess.CalledProcessError as exc:
        sys.stderr.write(exc.stdout)
        sys.stderr.write(exc.stderr)
        raise SystemExit(exc.returncode) from exc
    return result.stdout


def developer_tool(name: str, env_name: str | None = None) -> str:
    if env_name and os.environ.get(env_name):
        return os.environ[env_name]
    return run(["xcrun", "-f", name]).strip()


def strip_line_comment(line: str) -> str:
    return line.split("//", 1)[0].strip()


def selector_from_method(line: str) -> str | None:
    line = strip_line_comment(line).rstrip(";").strip()
    match = re.match(r"^[+-]\s*\([^)]*\)\s*(.+)$", line)
    if not match:
        return None

    declaration = match.group(1).strip()
    labels = re.findall(r"([A-Za-z_][A-Za-z0-9_]*)\s*:", declaration)
    if labels:
        return "".join(f"{label}:" for label in labels)

    return declaration.split()[0] if declaration else None


def property_name(line: str) -> str | None:
    line = strip_line_comment(line).rstrip(";").strip()
    match = re.match(r"^@property\s*(?:\(([^)]*)\))?\s*(.+)$", line)
    if not match:
        return None
    declaration = match.group(2).strip()
    declaration = re.sub(r"\s+__attribute__\s*\(\(.*\)\)\s*$", "", declaration)
    declaration = declaration.replace("*", " ")
    parts = [part for part in declaration.split() if part]
    return parts[-1] if parts else None


def property_attributes(line: str) -> tuple[str, ...]:
    match = re.match(r"^@property\s*(?:\(([^)]*)\))?", strip_line_comment(line))
    if not match or not match.group(1):
        return ()
    return tuple(part.strip() for part in match.group(1).split(",") if part.strip())


def property_getter(name: str, attrs: tuple[str, ...]) -> str:
    for attr in attrs:
        if attr.startswith("getter="):
            return attr.split("=", 1)[1]
    return name


def property_setter(name: str, attrs: tuple[str, ...]) -> str | None:
    if "readonly" in attrs:
        return None
    for attr in attrs:
        if attr.startswith("setter="):
            return attr.split("=", 1)[1]
    return f"set{name[0].upper()}{name[1:]}:"


def logical_header_lines(header: Path) -> list[str]:
    lines: list[str] = []
    pending: str | None = None

    for raw_line in header.read_text(encoding="utf-8").splitlines():
        line = strip_line_comment(raw_line)
        if not line:
            continue

        if pending is not None:
            pending = f"{pending} {line}"
            if ";" in line:
                lines.append(pending)
                pending = None
            continue

        if line.startswith(("+", "-", "@property")) and ";" not in line:
            pending = line
            continue

        lines.append(line)

    if pending is not None:
        lines.append(pending)

    return lines


def parse_headers(include_dir: Path) -> HeaderAPI:
    api = HeaderAPI()
    context_kind: str | None = None
    context_owner: str | None = None
    category_name: str | None = None

    for header in sorted(include_dir.glob("*.h")):
        for line in logical_header_lines(header):
            constant_match = re.match(r"^extern\s+NSString\s*\*\s*const\s+([A-Za-z0-9_]+);$", line)
            if constant_match:
                api.constants.add(constant_match.group(1))
                continue

            if re.match(r"^extern\s+LAActivator\s*\*\s*LASharedActivator;$", line):
                api.globals.add("LASharedActivator")
                continue

            interface_match = re.match(r"^@interface\s+([A-Za-z_][A-Za-z0-9_]*)(?:\s*\(([^)]*)\))?", line)
            if interface_match:
                owner = interface_match.group(1)
                context_owner = owner
                category_name = interface_match.group(2)
                if category_name is not None:
                    context_kind = "category"
                    api.categories.add((owner, category_name))
                else:
                    context_kind = "class"
                    api.classes.add(owner)
                continue

            protocol_match = re.match(r"^@protocol\s+([A-Za-z_][A-Za-z0-9_]*)", line)
            if protocol_match:
                owner = protocol_match.group(1)
                context_kind = "protocol"
                context_owner = owner
                category_name = None
                api.protocols.add(owner)
                continue

            if line == "@end":
                context_kind = None
                context_owner = None
                category_name = None
                continue

            if not context_kind or not context_owner:
                continue

            if line.startswith(("+", "-")):
                selector = selector_from_method(line)
                if selector:
                    api.methods.append(
                        MethodDecl(
                            owner=context_owner,
                            selector=selector,
                            kind=line[0],
                            context_kind=context_kind,
                        )
                    )
                continue

            if line.startswith("@property"):
                name = property_name(line)
                attrs = property_attributes(line)
                if name:
                    api.properties.append(
                        PropertyDecl(
                            owner=context_owner,
                            name=name,
                            attributes=attrs,
                            context_kind=context_kind,
                            category_name=category_name,
                        )
                    )

                    api.methods.append(
                        MethodDecl(
                            owner=context_owner,
                            selector=property_getter(name, attrs),
                            kind="-",
                            context_kind=context_kind,
                        )
                    )

                    setter = property_setter(name, attrs)
                    if setter:
                        api.methods.append(
                            MethodDecl(
                                owner=context_owner,
                                selector=setter,
                                kind="-",
                                context_kind=context_kind,
                            )
                        )

    return api


def compile_import_checks(project_root: Path, staging_dir: Path, sdk: Path, tmp_dir: Path) -> None:
    clang = os.environ.get("CLANG") or developer_tool("clang")
    common_flags = [
        "-target",
        "arm64-apple-ios15.0",
        "-isysroot",
        str(sdk),
        "-miphoneos-version-min=15.0",
        "-fobjc-arc",
        "-fmodules",
        f"-fmodules-cache-path={tmp_dir / 'module-cache'}",
        "-I",
        str(staging_dir / "usr/include"),
        "-F",
        str(staging_dir / "Library/Frameworks"),
    ]

    flat_import = tmp_dir / "flat-import.m"
    flat_import.write_text(
        """
#import <libactivator.h>

void LAFlatImportCheck(void) {
    LAEvent *event = [LAEvent eventWithName:LAEventNameMenuPressSingle mode:LAEventModeSpringBoard];
    event.userInfo = @{ LAEventUserInfoDisplayIdentifier: @\"com.apple.springboard\" };
    (void)[[LAActivator sharedInstance] version];
    (void)LAActivatorVersion_1_9_13;
    (void)LAEventNameVolumeMuteOn;
    (void)LAEventNameVolumeDownPressWithMenu;
    (void)LAEventNameFingerprintSensorPressTwice;
}
""".lstrip(),
        encoding="utf-8",
    )

    framework_import = tmp_dir / "framework-import.m"
    framework_import.write_text(
        """
#import <Activator/Activator.h>
#import <objc/runtime.h>

void LAFrameworkImportCheck(void) {
    LAActivator *activator = [LAActivator sharedInstance];
    LAEvent *event = [[LAEvent alloc] initWithName:LAEventNameStatusBarTapSingle mode:LAEventModeApplication];
    [activator sendEvent:event toListenersWithNames:@[]];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    (void)activator.authorizationStatus;
    [activator requestAuthorization];
#pragma clang diagnostic pop
    (void)[activator assignmentWarningForEventWithName:LAEventNameVolumeMuteOn];
    UIImageView *imageView = [UIImageView new];
    imageView.activatorListenerName = @\"example.listener\";
    imageView.activatorListenerImageIsThreaded = YES;
    (void)[LARootSettingsController controller];
    (void)LASharedActivator;
    (void)@protocol(LAListener);
    (void)@protocol(LAEventDataSource);
}
""".lstrip(),
        encoding="utf-8",
    )

    module_import = tmp_dir / "module-import.m"
    module_import.write_text(
        """
@import Activator;

void LAModuleImportCheck(void) {
    LAActivator *activator = [LAActivator sharedInstance];
    if (activator.version != LAActivatorVersion_2_0) {
        __builtin_trap();
    }
    (void)LAActivatorAssignmentsChangedNotification;
    (void)LAActivatorEventModeChangedNotification;
    (void)LAActivatorAuthorizationChangedNotification;
    (void)@protocol(LAEventDataSource);
}
""".lstrip(),
        encoding="utf-8",
    )

    for source in (flat_import, framework_import, module_import):
        run([clang, *common_flags, "-fsyntax-only", str(source)], cwd=project_root)

    object_file = tmp_dir / "framework-import.o"
    run([clang, *common_flags, "-c", str(framework_import), "-o", str(object_file)], cwd=project_root)

    run(
        [
            clang,
            "-target",
            "arm64-apple-ios15.0",
            "-isysroot",
            str(sdk),
            "-miphoneos-version-min=15.0",
            "-dynamiclib",
            str(object_file),
            "-L",
            str(staging_dir / "usr/lib"),
            "-lactivator",
            "-framework",
            "Foundation",
            "-framework",
            "UIKit",
            "-o",
            str(tmp_dir / "libactivator-public-api-check.dylib"),
        ],
        cwd=project_root,
    )


def macho_binaries(path: Path):
    parsed = lief.parse(str(path))
    if parsed is None:
        raise SystemExit(f"Unable to parse Mach-O binary: {path}")
    if isinstance(parsed, lief.MachO.FatBinary):
        return list(parsed)
    return [parsed]


def normalize_symbol_name(name: Any) -> str | None:
    if isinstance(name, bytes):
        return name.decode("utf-8", errors="ignore") or None
    if isinstance(name, str):
        return name or None
    return None


def collect_symbols(path: Path) -> tuple[set[str], set[str]]:
    all_symbols: set[str] = set()
    exported_symbols: set[str] = set()
    for binary in macho_binaries(path):
        for symbol in binary.symbols:
            symbol_name = normalize_symbol_name(symbol.name)
            if symbol_name is not None:
                all_symbols.add(symbol_name)

        for symbol in getattr(binary, "exported_symbols", ()):
            symbol_name = normalize_symbol_name(getattr(symbol, "name", None))
            if symbol_name is not None:
                exported_symbols.add(symbol_name)
    return all_symbols, exported_symbols


def objc_metadata(path: Path) -> str:
    objdump = os.environ.get("OBJDUMP") or developer_tool("llvm-objdump")
    return run([objdump, "--macho", "--objc-meta-data", str(path)])


def property_lists(metadata: str) -> dict[str, dict[str, str]]:
    lists: dict[str, dict[str, str]] = {}
    current_list: str | None = None
    current_property: str | None = None

    for raw_line in metadata.splitlines():
        line = raw_line.strip()
        match = re.search(r"(?:baseProperties|instanceProperties)\s+0x[0-9a-f]+\s+(__OBJC_\$_PROP_LIST_[A-Za-z0-9_$]+)", line)
        if match:
            list_name = match.group(1)
            current_list = list_name
            current_property = None
            lists.setdefault(list_name, {})
            continue

        if current_list and (
            line.startswith("Meta Class")
            or line.startswith("Contents of")
            or re.match(r"^[0-9a-f]{8,}\s+", line)
        ):
            current_list = None
            current_property = None
            continue

        if not current_list:
            continue

        name_match = re.match(r"^name\s+0x[0-9a-f]+\s+(.+)$", line)
        if name_match:
            current_property = name_match.group(1).strip()
            continue

        attr_match = re.match(r"^attributes\s+0x[0-9a-f]+\s+(.+)$", line)
        if attr_match and current_property:
            lists[current_list][current_property] = attr_match.group(1).strip()
            current_property = None

    return lists


def category_symbol(cls: str, category: str) -> str:
    return f"__OBJC_$_CATEGORY_{cls}_$_{category}"


def property_list_symbol(prop: PropertyDecl, owned_classes: set[str]) -> str:
    if prop.context_kind == "category":
        if prop.owner in owned_classes:
            return f"__OBJC_$_PROP_LIST_{prop.owner}"
        if not prop.category_name:
            raise AssertionError("Category property missing category name")
        return f"__OBJC_$_PROP_LIST_{prop.owner}_$_{prop.category_name}"
    return f"__OBJC_$_PROP_LIST_{prop.owner}"


def required_property_flags(prop: PropertyDecl) -> list[str]:
    flags: list[str] = []
    if "readonly" in prop.attributes:
        flags.append("R")
    if "copy" in prop.attributes:
        flags.append("C")
    for attr in prop.attributes:
        if attr.startswith("getter="):
            flags.append(f"G{attr.split('=', 1)[1]}")
    return flags


def check(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def validate_api(api: HeaderAPI, dylib: Path) -> tuple[int, int, int]:
    all_symbols, exported_symbols = collect_symbols(dylib)
    metadata = objc_metadata(dylib)
    properties = property_lists(metadata)
    checked_symbols = 0
    checked_metadata = 0
    checked_properties = 0

    for global_name in sorted(api.globals):
        check(f"_{global_name}" in exported_symbols, f"Missing public global symbol: {global_name}")
        checked_symbols += 1

    for constant in sorted(api.constants):
        check(f"_{constant}" in exported_symbols, f"Missing public constant symbol from headers: {constant}")
        checked_symbols += 1

    for class_name in sorted(api.classes):
        check(f"_OBJC_CLASS_$_{class_name}" in exported_symbols, f"Missing public class symbol: {class_name}")
        checked_symbols += 1

    for cls, category in sorted(api.categories):
        if cls in api.classes:
            continue
        symbol = category_symbol(cls, category)
        check(symbol in all_symbols or symbol in metadata, f"Missing Objective-C category metadata: {cls}({category})")
        checked_metadata += 1

    for protocol in sorted(api.protocols):
        symbol = f"__OBJC_PROTOCOL_$_{protocol}"
        check(symbol in all_symbols or symbol in metadata, f"Missing Objective-C protocol metadata: {protocol}")
        checked_metadata += 1

    seen_methods: set[tuple[str, str, str, str]] = set()
    for method in api.methods:
        key = (method.context_kind, method.owner, method.kind, method.selector)
        if key in seen_methods:
            continue
        seen_methods.add(key)

        if method.context_kind == "protocol":
            check(method.selector in metadata, f"Missing Objective-C protocol selector metadata: {method.owner} {method.selector}")
            checked_metadata += 1
            continue

        if method.context_kind == "category" and method.owner not in api.classes:
            category = next((cat for owner, cat in api.categories if owner == method.owner), None)
            expected = f"{method.kind}[{method.owner}({category}) {method.selector}]"
        else:
            expected = f"{method.kind}[{method.owner} {method.selector}]"
        check(expected in metadata, f"Missing Objective-C method metadata: {expected}")
        checked_metadata += 1

    for prop in api.properties:
        list_name = property_list_symbol(prop, api.classes)
        actual_properties = properties.get(list_name)
        if actual_properties is None:
            raise SystemExit(f"Missing Objective-C property list metadata: {list_name}")

        actual_attrs = actual_properties.get(prop.name)
        if actual_attrs is None:
            raise SystemExit(f"Missing Objective-C property metadata: {list_name} {prop.name}")

        for flag in required_property_flags(prop):
            check(
                flag in actual_attrs.split(","),
                f"Missing Objective-C property attribute: {list_name} {prop.name} {flag}",
            )
        checked_properties += 1

    return checked_symbols, checked_metadata, checked_properties


def validate_forbidden_api(api: HeaderAPI, dylib: Path) -> None:
    metadata = objc_metadata(dylib)
    declared_selectors = {method.selector for method in api.methods}
    forbidden_declarations = sorted(FORBIDDEN_SELECTORS.intersection(declared_selectors))
    forbidden_metadata = sorted(selector for selector in FORBIDDEN_SELECTORS if selector in metadata)

    check(
        not forbidden_declarations,
        f"Forbidden legacy selector declared in public headers: {', '.join(forbidden_declarations)}",
    )
    check(
        not forbidden_metadata,
        f"Forbidden legacy selector present in Objective-C metadata: {', '.join(forbidden_metadata)}",
    )


def validate_resource_catalog(project_root: Path) -> None:
    import plistlib

    activator_dir = project_root / "layout/Library/Activator"
    events_path = activator_dir / "Events/bundled.plist"
    listeners_path = activator_dir / "Listeners/bundled.plist"
    check(events_path.is_file(), f"Missing event resource catalog: {events_path}")
    check(listeners_path.is_file(), f"Missing listener resource catalog: {listeners_path}")

    with events_path.open("rb") as file:
        events = plistlib.load(file)
    with listeners_path.open("rb") as file:
        listeners = plistlib.load(file)

    check(isinstance(events, dict), "Event resource catalog is not a dictionary")
    check(isinstance(listeners, dict), "Listener resource catalog is not a dictionary")
    check(len(events) == 121, f"Unexpected event resource count: {len(events)}")
    check(len(listeners) == 114, f"Unexpected listener resource count: {len(listeners)}")

    excluded_listeners = {
        "libactivator.twitter.compose-tweet",
        "libactivator.facebook.compose-post",
        "libactivator.weibo.compose-post",
    }
    present_excluded = sorted(excluded_listeners.intersection(listeners))
    check(not present_excluded, f"Excluded social listeners are staged: {', '.join(present_excluded)}")


def main() -> int:
    if not os.environ.get("THEOS"):
        raise SystemExit("THEOS is required.")

    project_root = Path(__file__).resolve().parent.parent
    staging_dir = Path(os.environ.get("THEOS_STAGING_DIR", project_root / ".theos/_"))
    sdk = Path(os.environ["THEOS"]) / "sdks/iPhoneOS16.5.sdk"
    dylib = staging_dir / "usr/lib/libactivator.dylib"

    check(sdk.is_dir(), f"SDK not found: {sdk}")
    check(staging_dir.is_dir(), f"Staging directory not found: {staging_dir}")
    check(dylib.is_file(), f"libactivator.dylib not found: {dylib}")

    api = parse_headers(project_root / "include/Activator")
    unique_methods = {
        (method.context_kind, method.owner, method.kind, method.selector)
        for method in api.methods
    }

    log(
        "Header inventory: "
        f"{len(api.constants)} constants, "
        f"{len(api.globals)} globals, "
        f"{len(api.classes)} classes, "
        f"{len(api.categories)} categories, "
        f"{len(api.protocols)} protocols, "
        f"{len(unique_methods)} selectors, "
        f"{len(api.properties)} properties"
    )

    with tempfile.TemporaryDirectory(prefix="libactivator-public-api-check.") as tmp:
        compile_import_checks(project_root, staging_dir, sdk, Path(tmp))
        checked_symbols, checked_metadata, checked_properties = validate_api(api, dylib)
    validate_forbidden_api(api, dylib)
    validate_resource_catalog(project_root)

    log(
        "Binary validation: "
        f"{checked_symbols} exported symbols, "
        f"{checked_metadata} Objective-C metadata entries, "
        f"{checked_properties} properties"
    )
    log("Resource catalog validation: 121 events, 114 listeners.")
    log("Metadata check passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
