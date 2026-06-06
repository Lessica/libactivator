# Implementation Status

This document is the active implementation tracker for the rewrite. Update it
whenever an implementation slice starts, is verified, is blocked, or is
completed.

## Progress States

- `Not started`: documented only.
- `In progress`: implementation exists but is incomplete or not verified.
- `Done`: implemented and covered by compile/link or package verification.
- `Blocked`: needs a project-owner decision or unavailable runtime knowledge.

## Tracker

| Slice | Progress | API category | Owner target | Depends on | Acceptance criteria |
| --- | --- | --- | --- | --- | --- |
| Public constant definitions | Done | Must implement | `libactivator.dylib` | None | Every `extern NSString * const` and `LASharedActivator` links from a client binary. |
| Version compatibility update | Done | Must implement | `include/Activator`, `libactivator.dylib` | None | `LAActivatorVersion_2_0 = 2000000` exists and `-[LAActivator version]` returns it. |
| Header modernization | Done | Must implement | `include/Activator` | Version compatibility update | Obsolete `<libkern/OSAtomic.h>` import is removed and all supported imports still compile. |
| `LAEvent` model | Done | Must implement | `libactivator.dylib` | Public constant definitions | Factories, initializers, properties, copy semantics, and `NSCoding` work without runtime services. |
| `LAActivator` singleton and globals | Done | Must implement | `libactivator.dylib` | Public constant definitions | `+sharedInstance` and `LASharedActivator` are stable and identical. |
| Empty event registry | Done | Safe stub first | `libactivator.dylib` | `LAActivator` singleton and globals | Event registry methods are non-crashing and return deterministic empty/default values. |
| Empty listener registry | Done | Safe stub first | `libactivator.dylib` | `LAActivator` singleton and globals | Listener registry methods are non-crashing and return deterministic empty/default values. |
| Assignment model | Not started | Must implement | `libactivator.dylib` | `LAEvent` model | Assign, unassign, multi-listener, and reverse lookup behavior works in memory. |
| Assignment persistence | Not started | Must implement | `libactivator.dylib` | Assignment model, path abstraction | Assignments persist atomically in the jailbreak layout. |
| Listener compatibility model | Not started | Must implement | `libactivator.dylib` | Empty listener registry, assignment model | `listenerNamesAreMutuallyCompatible:` and exclusive group behavior are deterministic. |
| Blacklist model | Not started | Must implement | `libactivator.dylib` | Path abstraction | Blacklist query/update works without SpringBoard runtime. |
| Profile model | Not started | Must implement | `libactivator.dylib` | Assignment model | Default/current profile behavior is defined and deterministic. |
| Localization safe stubs | Done | Safe stub first | `libactivator.dylib` | Public constant definitions | Localization methods return deterministic fallback strings before resources exist. |
| Event data-source registration | Not started | Must implement | `libactivator.dylib` | Empty event registry | Register/unregister and metadata dispatch to `LAEventDataSource` work in process. |
| Listener metadata dispatch | Not started | Safe stub first | `libactivator.dylib` | Empty listener registry | Optional `LAListener` metadata selectors are queried with `respondsToSelector:`. |
| Event/listener delivery API stubs | Done | Runtime-backed | `libactivator.dylib` | Assignment model, listener registry | Public delivery selectors are non-crashing; real dispatch waits for IPC/runtime. |
| Public settings class shims | Done | Settings-backed | `libactivator.dylib` | Header modernization | Public settings classes resolve when a third-party app links only `libactivator.dylib`. |
| Settings UI implementation | Not started | Settings-backed | `libactivatorsettings.dylib` | Public settings class shims | Real settings root can be created through `LASCreateSettingsRootViewController`. |
| `UIImageView (Activator)` storage | Done | Settings-backed | `libactivator.dylib` | Public settings class shims | Category properties store and retrieve values without image-loading behavior. |
| IPC client facade | Not started | Runtime-backed | `libactivator.dylib` | Safe stub APIs | Public calls that require SpringBoard can route to IPC with timeouts and errors. |
| SpringBoard server runtime | Not started | Runtime-backed | `ActivatorSpringBoard.dylib` | IPC schema, registry models | SpringBoard can host registries and dispatch requests without app injection. |
| Built-in event capability assessments | Not started | Capability gated | Docs and runtime adapters | SpringBoard server runtime | Each event family has a documented modern iOS capability result before registration. |
| Built-in listener/action assessments | Not started | Capability gated | Docs and runtime adapters | SpringBoard server runtime | Each built-in listener/action has a documented modern iOS capability result before registration. |
| API compatibility test client | Done | Must implement | test/check scripts | Public constants, `LAEvent`, `LAActivator` skeleton | A compile/link check imports all entry points and references representative public symbols. |
| Package/import verification | Done | Must implement | Theos package | Foundation skeleton | rootful/rootless/roothide packages build; supported import styles compile. |
