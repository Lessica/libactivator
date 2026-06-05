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

## Project Goals

- Preserve, remain source-compatible with, and extend the final public API.
- Target iOS 15.0 and newer.
- Support rootful, rootless, and roothide jailbreak layouts.
- Build with Theos, using `$THEOS` and its iOS 16.5 SDK.
- Build for `arm64` and `arm64e`.

## Compatibility Rules

- Public class names, protocol names, selectors, constants, and expected
  semantics from `references/headers` are compatibility contracts.
- API extensions must be additive unless we intentionally create a documented
  compatibility break.
- New behavior should prefer graceful no-op or explicit error reporting over
  crashes when a listener, event, private API, or SpringBoard feature is absent.
- Keep legacy event and listener names stable, even when the implementation is
  completely new.

## Architecture Rules

- Keep the public client library small and stable.
- Keep SpringBoard-specific private API usage behind a SpringBoard runtime
  layer.
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

## Build Rules

- Use modern Theos project structure, not the historical `framework` submodule.
- Set deployment target to iOS 15.0.
- Build all production binaries for `arm64 arm64e`.
- Avoid implicit SDK-version assumptions in source. Gate private symbols and
  optional runtime features dynamically.
- Do not introduce generated build artifacts into source control.

## Jailbreak Layout Rules

- Do not scatter absolute paths such as `/Library`, `/usr/lib`, or
  `/var/mobile` through feature code.
- Route install paths and runtime lookup paths through one path abstraction.
- Path decisions must account for rootful, rootless, and roothide separately.
- Package layout and runtime discovery should be documented next to the path
  abstraction once implemented.

## IPC Rules

- Treat the legacy `CFMessagePort` protocol as behavior reference, not as the
  default design.
- The new IPC layer must define request/response shape, notifications,
  timeouts, version negotiation, and failure behavior.
- IPC payloads must be validated before use.
- Public API calls that cross process boundaries should have predictable main
  thread behavior.

## Data Rules

- Define schemas for assignments, profiles, blacklist entries, event metadata,
  and listener metadata.
- Support migration from known legacy preference keys where practical.
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

## UI Rules

- Preserve the old information architecture: modes, events, listeners, search,
  assignments, profiles, blacklist, menus, and configuration controllers.
- Rebuild the UI for iOS 15-era UIKit.
- Do not keep historical ad UI, `UIWebView`, `UIAlertView`, or `UIActionSheet`
  patterns.
- Settings UI should consume the same public API surface third-party callers
  use where practical.

## Code Style Rules

- Prefer ARC for new Objective-C code unless a Theos/runtime boundary requires
  otherwise.
- Keep manual memory management out of new code by default.
- Use clear module names and small files with explicit ownership.
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

- IPC transport.
- Exact package layout for rootful/rootless/roothide.
- Minimum set of built-in events for the first working milestone.
- Minimum set of built-in listeners/actions for the first working milestone.
- Whether profiles are implemented in the first milestone or after assignment
  compatibility lands.
- Test harness strategy for SpringBoard-only behavior.
