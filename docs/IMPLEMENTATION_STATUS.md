# Implementation Status

This document is the active implementation tracker for the rewrite. Update it
whenever an implementation slice starts, is verified, is blocked, or is
completed.

## Progress States

- `Not started`: documented only.
- `In progress`: implementation exists but is incomplete or not verified.
- `Done`: implemented for the slice's stated acceptance criteria and covered by
  compile/link or package verification. It does not imply that every runtime
  behavior behind the same public selector family is complete.
- `Blocked`: needs a project-owner decision or unavailable runtime knowledge.

## Current `LAActivator` Runtime Gaps

These gaps are intentionally tracked separately from ABI/source compatibility.
They must not be mistaken for completed runtime behavior.

| Area | Current state | Required follow-up |
| --- | --- | --- |
| Event delivery | `sendEvent*`, `sendAbort*`, `sendPreview*`, and `sendDeactivate*` are non-crashing stubs. | Implement SpringBoard runtime dispatch, listener compatibility checks, handled state, abort, preview, deactivate, and multi-listener delivery. |
| Listener object lookup across processes | Non-SpringBoard clients can query assigned listener names through IPC, but `listenerForName:` still returns only local in-process objects. | Keep object registration SpringBoard-only and define which public object-returning selectors are local-only versus runtime-backed. |
| Listener and event data-source registration | Registration works only in the authoritative in-process backend; non-SpringBoard calls do not create runtime state. | Make this explicit in docs/tests and keep cross-process object registration out of the first IPC slice. |
| Configuration controllers | `eventWithNameSupportsConfiguration:` and `listenerWithNameSupportsConfiguration:` can report support, but the corresponding controller factory methods return `nil`. | Implement Settings UI loading through `libactivatorsettings.dylib` or make support queries return `NO` until controller creation exists. |
| Listener images | `iconForListenerName:`, `smallIconForListenerName:`, and `imageForListenerName:usingTemplate:` return `nil`. | Implement resource lookup, bundle handling, and template image behavior. |
| Runtime mode and foreground app state | `currentEventMode` is process-based, `currentEventModeUnderneathLockScreen` is a fixed fallback, and `displayIdentifierForCurrentApplication` returns the current process bundle identifier. | Implement SpringBoard runtime state for foreground application, lock screen, home screen, and effective event mode. |
| Unlock support | `supportsUnlockingDeviceToSendEvents` returns `NO`. | Reassess modern iOS unlock/send behavior before enabling. |
| Listener removal | `requestRemovalForListenerWithName:` only calls the in-process listener object. | Decide whether removal requests are SpringBoard-only, Settings-backed, or IPC-routed. |
| `hasSeenListenerWithName:` | Currently aliases `hasListenerWithName:`. | Decide whether historical seen-listener semantics are still useful or should be documented as deprecated compatibility behavior. |
| Localization resources | Localization returns stable fallback strings and optional listener/data-source metadata only. | Add resource bundle lookup and Settings UI localization integration when resources exist. |
| State/config IPC verification | SpringBoard server startup and non-SpringBoard `com.apple.Preferences` facade round trips were verified on iPhone XR iOS 15.0 roothide. Sandboxed `Activator.app` cannot see the server until its entitlements are defined. | Continue tracking event delivery and cross-process object registration separately. |

## Tracker

| Slice | Progress | API category | Owner target | Depends on | Acceptance criteria |
| --- | --- | --- | --- | --- | --- |
| Public constant definitions | ✅ | Must implement | `libactivator.dylib` | None | Every `extern NSString * const` and `LASharedActivator` links from a client binary. |
| Version compatibility update | ✅ | Must implement | `include/Activator`, `libactivator.dylib` | None | `LAActivatorVersion_2_0 = 2000000` exists and `-[LAActivator version]` returns it. |
| Header modernization | ✅ | Must implement | `include/Activator` | Version compatibility update | Obsolete `<libkern/OSAtomic.h>` import is removed and all supported imports still compile. |
| `LAEvent` model | ✅ | Must implement | `libactivator.dylib` | Public constant definitions | Factories, initializers, properties, copy semantics, and `NSCoding` work without runtime services. |
| `LAActivator` singleton and globals | ✅ | Must implement | `libactivator.dylib` | Public constant definitions | `+sharedInstance` and `LASharedActivator` are stable and identical. |
| Runtime backend/facade split | ✅ | Runtime-backed | `libactivator.dylib` | `LAActivator` singleton and globals | `LAActivator` forwards state work to private backend/persistence types; non-SpringBoard clients do not create persistent isolated state. |
| In-memory event registry | ✅ | Must implement | `libactivator.dylib` | `LAActivator` singleton and globals | Event data sources can register/unregister and drive metadata queries in process as the Step 2 model; SpringBoard becomes authoritative after IPC/runtime work. |
| In-memory listener registry | ✅ | Must implement | `libactivator.dylib` | `LAActivator` singleton and globals | Listeners can register/unregister and drive metadata queries in process as the Step 2 model; SpringBoard becomes authoritative after IPC/runtime work. |
| Assignment model | ✅ | Must implement | `libactivator.dylib` | `LAEvent` model | Assign, unassign, multi-listener, reverse lookup, and legacy nil-mode assignment semantics work in memory as the Step 2 model; persistence and IPC-backed authority are separate slices. |
| Assignment persistence | ✅ | Must implement | `libactivator.dylib` | Assignment model, runtime backend/facade split | SpringBoard authoritative backend persists assignments to `jbroot(@"/var/mobile/Library/Preferences/libactivator.plist")` with schema validation and atomic writes; invalid plist data is ignored. |
| Listener compatibility model | ✅ | Must implement | `libactivator.dylib` | In-memory listener registry, assignment model | `listenerNamesAreMutuallyCompatible:` and exclusive group behavior are deterministic. |
| Blacklist model | ✅ | Must implement | `libactivator.dylib` | None | Blacklist query/update works in memory for Step 2; final client-visible state must be SpringBoard/IPC-backed. |
| Profile model | ✅ | Must implement | `libactivator.dylib` | Assignment model | Default/current profile behavior is defined and deterministic in memory for Step 2; final client-visible state must be SpringBoard/IPC-backed. |
| Blacklist persistence | ✅ | Must implement | `libactivator.dylib` | Assignment persistence | SpringBoard authoritative backend persists blacklisted display identifiers in the v2 runtime preference plist. |
| Profile persistence | ✅ | Must implement | `libactivator.dylib` | Assignment persistence | SpringBoard authoritative backend persists current profile and per-profile assignments in the v2 runtime preference plist. |
| Localization safe stubs | ✅ | Safe stub first | `libactivator.dylib` | Public constant definitions | Localization methods return deterministic fallback strings before resources exist. |
| Event data-source registration | ✅ | Must implement | `libactivator.dylib` | In-memory event registry | Register/unregister and metadata dispatch to `LAEventDataSource` work in process. |
| Listener metadata dispatch | ✅ | Safe stub first | `libactivator.dylib` | In-memory listener registry | Optional `LAListener` metadata selectors are queried with `respondsToSelector:`. |
| Event/listener delivery API stubs | ✅ | Runtime-backed | `libactivator.dylib` | Assignment model, listener registry | Public delivery selectors are non-crashing; real dispatch waits for IPC/runtime. |
| Public settings class shims | ✅ | Settings-backed | `libactivator.dylib` | Header modernization | Public settings classes resolve when a third-party app links only `libactivator.dylib`. |
| Settings UI implementation | Not started | Settings-backed | `libactivatorsettings.dylib` | Public settings class shims | Real Settings UI behavior is implemented in the settings library, not in `libactivator.dylib`. |
| `UIImageView (Activator)` storage | ✅ | Settings-backed | `libactivator.dylib` | Public settings class shims | Category properties store and retrieve values without image-loading behavior. |
| IPC client facade | ✅ | Runtime-backed | `libactivator.dylib` | Safe stub APIs | State/config public calls route through `CPDistributedMessagingCenter` with defined request/reply dictionaries and safe defaults when SpringBoard is unavailable. Event delivery and object registration are not included. |
| SpringBoard state/config IPC server | ✅ | Runtime-backed | `libactivator.dylib`, `ActivatorTweak.dylib` | IPC schema, registry models | SpringBoard starts the `libactivator.springboard` messaging center and handles state/config requests against the authoritative backend without app injection. |
| SpringBoard event runtime | Not started | Runtime-backed | `ActivatorTweak.dylib` | IPC state/config server | SpringBoard can acquire runtime events, register built-in capabilities, and dispatch listener callbacks without app injection. |
| Built-in event capability assessments | Not started | Capability gated | Docs and runtime adapters | SpringBoard event runtime | Each event family has a documented modern iOS capability result before registration. |
| Built-in listener/action assessments | Not started | Capability gated | Docs and runtime adapters | SpringBoard event runtime | Each built-in listener/action has a documented modern iOS capability result before registration. |
| API compatibility test client | ✅ | Must implement | test/check scripts | Public constants, `LAEvent`, `LAActivator` skeleton | A compile/link/runtime metadata check imports all entry points and validates public symbols, selectors, properties, and protocols from the 1.9 headers. |
| Package/import verification | ✅ | Must implement | Theos package | Foundation skeleton | rootful/rootless/roothide packages build; supported import styles compile. |
