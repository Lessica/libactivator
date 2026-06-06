# libactivator Rewrite Conventions

This document is the working agreement for the libactivator rewrite. It is
intentionally compact at first; decisions should move here once we agree they
are stable enough to guide implementation.

## Reference Baseline

- Public API baseline: `references/headers`, from `origin/headers`
  (`bfac8ee70e8ad6560305dc7f0fa586c1b5696ef1`, Public Release 1.9.0).
- Legacy implementation reference: `references/master`, from `origin/master`
  (`b245f923bb683a902e932c9307286bcaa9a26cd3`, Public Release 1.6.2-1).
- The legacy implementation is behavior reference only. Do not copy old
  implementation patterns unless we explicitly re-approve them for iOS 15+.
- Assume every iOS SPI used by the legacy implementation is no longer valid.
- Assume every iOS public API used by the legacy implementation must be mapped
  to its modern iOS 16.5 SDK usage before adoption.
- Do not use deprecated APIs.
- If an SPI is invalid and there is no reliable modern iOS reverse-engineering
  reference, do not invent an implementation or search the web for a guess.
  Leave a placeholder and ask the project owner immediately.

## Project Goals

- Treat this rewrite as the continuation of the project under new maintenance.
  Assume the original author will not return to maintain the legacy project.
- Version the new project as 2.x.
- Preserve, remain source-compatible with, and extend the final public API.
- Target iOS 15.0 and newer.
- Support rootful, rootless, and roothide jailbreak layouts.
- Build with Theos, using `$THEOS` and its iOS 16.5 SDK.
- Build for `arm64` and `arm64e`.

## Compatibility Rules

- Public class names, protocol names, selectors, constants, and expected
  semantics from `references/headers` are compatibility contracts.
- The final 1.9 public API design is authoritative. The legacy `master`
  implementation is only a light reference and must not override the public API
  contract.
- API extensions must be additive unless we intentionally create a documented
  compatibility break.
- Keep legacy-compatible models where they still make sense. When a legacy
  behavior is a bug, unsafe design, or obsolete burden, document it and mark the
  compatibility surface as deprecated instead of preserving the old behavior
  blindly.
- New behavior should prefer graceful no-op or explicit error reporting over
  crashes when a listener, event, private API, or SpringBoard feature is absent.
- Keep legacy event and listener names stable, even when the implementation is
  completely new.

## Architecture Rules

- Keep the public client library small and stable.
- Keep SpringBoard-specific private API usage behind a SpringBoard runtime
  layer.
- The rewritten libactivator must not inject into user apps.
- Injection into Apple apps is allowed only when the bundle identifier is
  explicitly known and starts with `com.apple.`.
- Do not use a `com.apple.UIKit` injection filter, because it injects into all
  apps and creates broad compatibility risk.
- Apple app injection must use explicit per-bundle filters and must be justified
  by the feature that needs it. Do not add wildcard Apple app injection.
- In-app status bar touch support is expected to be possible on modern iOS
  without app injection; investigate the concrete implementation when that
  feature is built.
- If a future feature truly requires user app injection, implement it as a
  separate optional component outside libactivator itself.
- Separate these responsibilities:
  - Public API facade.
  - IPC client and server protocol.
  - Event registry and metadata.
  - Listener registry and metadata.
  - Assignment, profile, and blacklist storage.
  - SpringBoard event acquisition adapters.
  - Built-in action/listener implementations.
  - Settings UI.
  - Jailbreak path/layout abstraction.
- Event semantics and event acquisition must not be the same module. A gesture
  name is stable; the hook or recognizer that detects it may change by iOS
  version or environment.
- Design the core first and keep it solid. Built-in events, listeners, and
  actions should then be implemented incrementally one by one.
- Modern foreground-application lookup, lock-screen state, and home-screen state
  have known project-owner references. Ask for those references when
  implementing that runtime layer.
- The SpringBoard runtime is the authoritative owner for activator runtime
  state. Event registries, listener registries, assignments, profiles,
  blacklist state, metadata dispatch, and event delivery must converge there
  once IPC is implemented.
- Non-SpringBoard clients should treat `LAActivator` as a public API facade.
  Runtime-backed calls must either route to SpringBoard through IPC or use an
  explicit non-crashing fallback.
- In-process model behavior inside `libactivator.dylib` is acceptable during
  the core model phase for pure logic validation. Do not treat per-process
  local registries in clients as the final runtime design.
- APIs that register Objective-C objects, such as listener and event data-source
  registration, are SpringBoard-runtime concepts. Non-SpringBoard behavior must
  be explicit and must not silently create an isolated client-only runtime.

## Development Phases

These phases describe engineering dependency order, not heavyweight milestones.

- Establish the modern Theos foundation: targets, install paths, public header
  staging, jailbreak path abstraction, formatting, and empty build validation.
- Implement the public API and core model: 1.9-compatible classes, constants,
  facade behavior, event model, listener model, assignments, profiles, and
  blacklist logic.
- Implement storage and metadata: validated schemas, atomic persistence,
  recovery behavior, localization, icons, configuration hooks, removal hooks,
  event metadata, and listener metadata.
- Implement IPC with `CPDistributedMessagingCenter` request/response handling,
  error handling, notifications, and payload validation.
- Implement the SpringBoard runtime: server bootstrap, runtime state,
  foreground app state, lock/home state, listener registration, event delivery,
  diagnostics, and Frida-assisted validation workflows.
- Implement event acquisition incrementally by event family. Each event must
  have a modern iOS capability assessment before registration.
- Implement built-in listeners/actions incrementally. Each listener/action must
  have a modern iOS capability assessment before registration.
- Implement the Settings UI library and hosts: `libactivatorsettings.dylib`, the
  PreferenceBundle host, the Activator.app host, and third-party host loading.
- Harden integration and packaging: on-device verification checklists, debug
  traces, rootful/rootless/roothide package checks, recovery paths, and release
  documentation.

## Build Rules

- Use modern Theos project structure, not the historical `framework` submodule.
- Use concise component names for new code: `LAApp` for the standalone
  Activator app, `LAS` or `LASettings` for Settings UI code, `LAP` or
  `LAPreferences` for the Settings preference panel, `ActivatorTweak` only for
  the primary tweak target and main entry file, and `LAT` or `LATweak` for
  additional tweak-local classes, files, and private types.
- Set deployment target to iOS 15.0.
- Build all production binaries for `arm64 arm64e`.
- Expose public headers with a flat compatibility entry point and a
  framework-style canonical path, matching Theos conventions such as
  `substrate.h`: `/usr/include/libactivator.h` should include
  `<Activator/Activator.h>`, while canonical public headers live under
  `/usr/include/Activator/` and `Activator.framework/Headers/`.
- Do not install public headers under `/usr/include/libactivator/`.
- Keep package metadata in root `layout/` at its final package path.
- Keep each tweak filter plist in that tweak's subproject root so Theos can
  stage it through the normal `tweak.mk` flow. Do not place tweak filter plists
  in the repository root.
- Do not use Logos syntax in this project. Tweak targets should use normal
  Objective-C or Objective-C++ source files and should not use `.x` or `.xm`
  source extensions.
- Use a root aggregate Makefile to orchestrate binary subprojects. Do not mix
  unrelated target ownership into the root package/staging layer.
- Do not define `$THEOS` in project Makefiles. Callers must provide it through
  the environment or command line.
- Do not override Theos internal path variables or compiler cache paths in
  project Makefiles, including `THEOS_LIBRARY_PATH`, `THEOS_PACKAGE_DIR`, and
  `CLANG_MODULE_CACHE_PATH`.
- Keep target-owned source files inside their owning subproject. Shared
  implementation files may live under `subprojects/common`.
- Avoid implicit SDK-version assumptions in source. Gate private symbols and
  optional runtime features dynamically.
- Do not introduce generated build artifacts into source control.

## Jailbreak Layout Rules

- Do not scatter absolute paths such as `/Library`, `/usr/lib`, or
  `/var/mobile` through feature code.
- Route install paths and runtime lookup paths through one path abstraction.
- Path decisions must account for rootful, rootless, and roothide separately.
- Theos and theos-roothide handle most package layout differences. The rewrite
  should focus on correct runtime path discovery.
- Use `$THEOS/vendor/include/roothide.h` as the primary reference for roothide
  runtime path handling.
- Package layout and runtime discovery rules should be documented next to the
  path abstraction once implemented.

## IPC Rules

- Treat the legacy `CFMessagePort` protocol as behavior reference, not as the
  default design.
- Use `CPDistributedMessagingCenter` from the `AppSupport` framework as the IPC
  layer. Treat it as the integrated XPC client/server boundary for this
  project; do not build an additional direct-XPC layer around it.
- `CPDistributedMessagingCenter` does not bypass sandbox restrictions. If a
  sandboxed system service needs cross-process communication later, add
  `libSandy` only for that specific bridge. Do not introduce `libSandy` during
  phases that have no concrete sandbox-crossing requirement.
- The new IPC layer must define request/response shape, notifications, failure
  behavior, and payload validation.
- Do not add custom timeout handling or version negotiation on top of
  `CPDistributedMessagingCenter`. The client and SpringBoard server ship
  together, and installation requires a SpringBoard restart.
- IPC payloads must be validated before use.
- Public API calls that cross process boundaries should have predictable main
  thread behavior.
- Public notifications are process-local `NSNotification` names. Cross-process
  state changes should be propagated through IPC and then reposted locally by
  each client process.

## Data Rules

- Define schemas for assignments, profiles, blacklist entries, event metadata,
  and listener metadata.
- Direct upgrades from the legacy Activator installation to this rewrite are not
  an expected use case. Do not design automatic legacy preference migration into
  the core.
- If legacy preference import becomes useful later, implement it as an explicit
  standalone import tool rather than core startup behavior.
- New persistent data should be atomic to write, recoverable after corruption,
  and explicit about ownership and permissions.
- Prefer structured serialization over ad hoc string parsing.

## Runtime Rules

- Assume SpringBoard private APIs are unstable. Isolate every private selector
  or class lookup behind a small adapter.
- Prefer capability detection over hardcoded system-version branching.
- All event delivery must make listener compatibility checks before invocation.
- Listener callbacks should not block the event acquisition layer longer than
  necessary.
- Handling state, abort delivery, preview delivery, deactivate delivery, and
  multi-listener assignment behavior must be covered by tests or explicit
  manual verification notes.
- SpringBoard-only behavior should be verified by a lightweight on-device
  diagnostic layer and manual verification checklists at first, not by a heavy
  automated harness.
- Frida may be used against a real device with `frida -U SpringBoard` to inspect
  interface availability, attach temporary hooks, and ask the project owner to
  perform actions that validate hook behavior.

## Built-in Capability Rules

- Keep legacy built-in event, listener, and action names stable when they remain
  part of the public compatibility surface.
- Each built-in event, listener, and action must be evaluated independently for
  modern iOS capability and documented before implementation.
- Do not register a built-in listener/action unless its modern iOS behavior is
  understood and implemented.
- If a legacy built-in capability is obsolete, unavailable, or unsafe on modern
  iOS, document the reason and leave it unregistered or explicitly unavailable.

## UI Rules

- Preserve the old information architecture: modes, events, listeners, search,
  assignments, profiles, blacklist, menus, and configuration controllers.
- Rebuild the UI for iOS 15-era UIKit.
- Do not keep historical ad UI, `UIWebView`, `UIAlertView`, or `UIActionSheet`
  patterns.
- Settings UI should consume the same public API surface third-party callers
  use where practical.
- Real Settings UI logic must live in an independent dynamic library.
- `libactivator.dylib` must keep compatibility shims for public settings
  classes from `LASettingsViewController.h`, because third-party jailbreak apps
  may dynamically link `libactivator.dylib` and use those classes to present
  Settings UI.
- `LASettingsShims.m` is a narrow compatibility exception: it may contain
  multiple placeholder settings classes only because this phase provides empty
  shims for the legacy public API surface. Do not treat it as an implementation
  pattern for real Settings UI or future runtime code.
- The PreferenceBundle, Activator.app, and third-party jailbreak apps are
  hosts for the Settings UI library.
- Do not export a new Settings UI host integration API until that contract is
  explicitly designed and approved.
- Name framework-like dynamic libraries with the `libxxx.dylib` convention.
- Use `libactivatorsettings.dylib` as the Settings UI dynamic library file name
  unless implementation details force a better name.
- Install framework-like dynamic libraries under `$JBROOT/usr/lib`.
- Expose corresponding framework structures under
  `$JBROOT/Library/Frameworks`.
- The framework binary inside `$JBROOT/Library/Frameworks/<Name>.framework`
  should be a relative symlink to `../../../usr/lib/<library>.dylib` where
  possible, because the symlink itself lives inside the `.framework` directory.
- Hosts must load the Settings UI dynamic library dynamically and keep host-only
  code thin.

## Code Style Rules

- Prefer ARC for new Objective-C code unless a Theos/runtime boundary requires
  otherwise.
- Keep manual memory management out of new code by default.
- Use clear module names and small files with explicit ownership.
- New implementation code should use one primary public class per source file.
  Multiple classes in one implementation file are allowed only for explicitly
  documented compatibility shims or tiny private helper types that are wholly
  owned by that file.
- Do not place multiple unrelated runtime, model, persistence, IPC, or UI
  implementation classes in a single source file.
- Avoid global mutable state except for compatibility globals required by the
  public API, such as `LASharedActivator`.
- Keep comments sparse and useful: explain private API choices, compatibility
  quirks, and non-obvious synchronization.

## Testing And Verification

- Add API compatibility checks early.
- Add focused unit tests for pure logic: event model, assignment resolution,
  metadata compatibility, path resolution, and serialization.
- Add integration/manual verification notes for SpringBoard hooks and device-only
  behavior.
- Build verification should include rootful, rootless, and roothide packaging
  assumptions before release.

## Open Decisions

- None currently recorded.
