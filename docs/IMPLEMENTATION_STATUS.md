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
| Event delivery | SpringBoard dispatch engine exists for event, abort, preview, deactivate, listener compatibility filtering, blacklist filtering, no-touch deferred dispatch, unlock-to-send callback compatibility, and handled-state propagation. Non-SpringBoard dispatch forwards to SpringBoard through IPC. | Implement built-in event sources separately. |
| Listener object lookup across processes | Non-SpringBoard `listenerForName:` returns a private remote proxy when SpringBoard reports that the listener exists. The proxy forwards event, abort, metadata, icon, and removal requests over IPC. | Keep object registration SpringBoard-authoritative; do not create isolated client-local runtime state. |
| Listener and event data-source registration | Registration works only in the authoritative in-process backend; non-SpringBoard calls do not create runtime state. The legacy implementation also rejected these public registration calls outside SpringBoard. | Keep public registration SpringBoard-authoritative unless a new explicit proxy design is introduced. |
| Configuration controllers | `eventWithNameSupportsConfiguration:` and `listenerWithNameSupportsConfiguration:` return `NO`; the corresponding controller factory methods return `nil`. | Implement Settings UI loading through `libactivatorsettings.dylib` in the Settings UI stage. |
| Listener images | `iconForListenerName:`, `smallIconForListenerName:`, and `imageForListenerName:usingTemplate:` query listener objects, listener resource bundles, the remote listener proxy, and the small app-icon provider. | Application icon fallback is only intended for table-cell-sized icons. |
| Runtime mode and foreground app state | `LAActivatorRuntimeStateProvider` computes SpringBoard/application/lockscreen mode from SpringBoard state hooks, lock state, screen blanking, home-screen visibility, and `_accessibilityFrontMostApplication`. Non-SpringBoard clients query SpringBoard through IPC. | Verify foreground app, home screen, lock screen, and underneath-mode behavior on device. |
| Unlock support | `supportsUnlockingDeviceToSendEvents` uses private SpringBoard capability detection, and lock-screen dispatch can call `receiveUnlockingDeviceEvent:forListenerName:` for incompatible listeners when event metadata allows it. | Verify callback-only behavior on device; passcode submission and automatic unlock remain out of scope. |
| Listener removal | `requestRemovalForListenerWithName:` calls the in-process listener object in SpringBoard and routes non-SpringBoard calls through the remote listener proxy. | Real Settings UI removal affordances are still separate. |
| `hasSeenListenerWithName:` | SpringBoard records seen listener names when listeners register and persists them in the v2 runtime plist; non-SpringBoard clients query through IPC. | The legacy private `ignoreHasSeen:` registration variant is not part of the 1.9 Public API and is not implemented. |
| Localization resources | Activator support bundle localization, event bundle localization, listener bundle localization, and stable fallback strings are implemented. | Add complete localization resources with Settings UI work. |
| State/config IPC verification | SpringBoard server startup and non-SpringBoard `com.apple.Preferences` facade round trips were verified on iPhone XR iOS 15.0 roothide. Sandboxed `Activator.app` cannot see the server until its entitlements are defined. | Continue tracking event delivery and cross-process object registration separately. |
| Runtime state verification | Local package build and Public API metadata checks pass for runtime state, no-touch dispatch, and unlock-to-send callback code. | Perform roothide on-device verification in SpringBoard. |
| Automated device tests | `scripts/run-tests.sh`, testing package, hidden testing IPC, device runner, isolated test plist, and initial SpringBoard/core suites are being added. | Run on roothide device and stabilize any flaky device-action cases. |

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
| Seen listener tracking | ✅ | Must implement | `libactivator.dylib` | In-memory listener registry, persistence, IPC server | `hasSeenListenerWithName:` returns persisted SpringBoard listener-registration history and non-SpringBoard clients query it through IPC. |
| Blacklist model | ✅ | Must implement | `libactivator.dylib` | None | Blacklist query/update works in memory for Step 2; final client-visible state must be SpringBoard/IPC-backed. |
| Profile model | ✅ | Must implement | `libactivator.dylib` | Assignment model | Default/current profile behavior is defined and deterministic in memory for Step 2; final client-visible state must be SpringBoard/IPC-backed. |
| Blacklist persistence | ✅ | Must implement | `libactivator.dylib` | Assignment persistence | SpringBoard authoritative backend persists blacklisted display identifiers in the v2 runtime preference plist. |
| Profile persistence | ✅ | Must implement | `libactivator.dylib` | Assignment persistence | SpringBoard authoritative backend persists current profile and per-profile assignments in the v2 runtime preference plist. |
| Localization resource lookup | ✅ | Must implement | `libactivator.dylib` | Public constant definitions, resource resolver | Localization methods query the Activator support bundle, event/listener bundles, and deterministic fallbacks. |
| Event data-source registration | ✅ | Must implement | `libactivator.dylib` | In-memory event registry | Register/unregister and metadata dispatch to `LAEventDataSource` work in process. |
| Default event metadata resources | ✅ | Must implement | `libactivator.dylib` | Resource resolver, event data-source registration | SpringBoard registers event metadata from `/Library/Activator/Events/<name>/Info.plist` when resources exist. |
| Listener metadata dispatch | ✅ | Must implement | `libactivator.dylib` | In-memory listener registry, resource resolver, IPC server | Optional `LAListener` metadata selectors are queried with `respondsToSelector:` and fall back to listener resource metadata. |
| Listener icon pipeline | ✅ | Settings-backed | `libactivator.dylib` | Listener metadata dispatch, IPC server | Listener image APIs query local listener objects, resource bundle PNG fallbacks, and remote proxy IPC. |
| Remote listener proxy | ✅ | Runtime-backed | `libactivator.dylib` | IPC client/server, event dispatch engine | Non-SpringBoard clients receive a private proxy from `listenerForName:` when SpringBoard has the listener; proxy calls forward to SpringBoard. |
| Event dispatch engine | ✅ | Runtime-backed | `libactivator.dylib` | Assignment model, listener registry, IPC server | SpringBoard event, abort, preview, and deactivate dispatch call registered listener objects with compatibility filtering and handled-state propagation; non-SpringBoard dispatch calls forward to SpringBoard over `CPDistributedMessagingCenter` and receive handled-state replies. |
| Runtime state provider | ✅ | Runtime-backed | `libactivator.dylib`, `ActivatorTweak.dylib` | SpringBoard IPC server | Runtime mode and current foreground display identifier are SpringBoard-authoritative and available to non-SpringBoard clients through IPC. |
| Mode change notifications | ✅ | Runtime-backed | `libactivator.dylib`, `ActivatorTweak.dylib` | Runtime state provider | Registered SpringBoard listeners receive `didChangeToEventMode:` when the computed event mode changes. |
| Deferred no-touch dispatch | ✅ | Runtime-backed | `libactivator.dylib`, `ActivatorTweak.dylib` | Event dispatch engine | Normal event dispatch honors `requires-no-touch-events` by marking the original event handled and deferring dispatch until active touches end. |
| Unlock-to-send callback compatibility | ✅ | Runtime-backed | `libactivator.dylib` | Runtime state provider, event dispatch engine | Lock-screen dispatch can call `receiveUnlockingDeviceEvent:forListenerName:` for incompatible listeners when event metadata supports unlock-to-send. |
| Public settings class shims | ✅ | Settings-backed | `libactivator.dylib` | Header modernization | Public settings classes resolve when a third-party app links only `libactivator.dylib`. |
| Settings UI implementation | Not started | Settings-backed | `libactivatorsettings.dylib` | Public settings class shims | Real Settings UI behavior is implemented in the settings library, not in `libactivator.dylib`. |
| `UIImageView (Activator)` storage | ✅ | Settings-backed | `libactivator.dylib` | Public settings class shims | Category properties store and retrieve values without image-loading behavior. |
| IPC client facade | ✅ | Runtime-backed | `libactivator.dylib` | Safe stub APIs | State/config, dispatch, metadata, remote listener, icon, and removal public calls route through `CPDistributedMessagingCenter` with safe defaults when SpringBoard is unavailable. |
| SpringBoard IPC server | ✅ | Runtime-backed | `libactivator.dylib`, `ActivatorTweak.dylib` | IPC schema, registry models, event dispatch engine | SpringBoard starts the `libactivator.springboard` messaging center and handles state/config, dispatch, metadata, remote listener, icon, and removal requests against the authoritative backend without app injection. |
| SpringBoard event runtime | Not started | Runtime-backed | `ActivatorTweak.dylib` | IPC state/config server | SpringBoard can acquire runtime events, register built-in capabilities, and dispatch listener callbacks without app injection. |
| Built-in event capability assessments | Not started | Capability gated | Docs and runtime adapters | SpringBoard event runtime | Each event family has a documented modern iOS capability result before registration. |
| Built-in listener/action assessments | Not started | Capability gated | Docs and runtime adapters | SpringBoard event runtime | Each built-in listener/action has a documented modern iOS capability result before registration. |
| API compatibility test client | ✅ | Must implement | test/check scripts | Public constants, `LAEvent`, `LAActivator` skeleton | A compile/link/runtime metadata check imports all entry points and validates public symbols, selectors, properties, and protocols from the 1.9 headers. |
| Device integration test harness | In progress | Runtime-backed | `subprojects/tests`, testing IPC | IPC server, runtime backend | `scripts/run-tests.sh` installs a testing build, runs the installed device-side runner through SSH, reports pass/fail/skip counts, and isolates test preferences. |
| Package/import verification | ✅ | Must implement | Theos package | Foundation skeleton | rootful/rootless/roothide packages build; supported import styles compile. |
