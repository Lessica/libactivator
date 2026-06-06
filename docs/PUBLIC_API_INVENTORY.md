# Public API Inventory

This inventory records the public API surface inherited from Activator 1.9 and
the additional wrapper entry points introduced by the rewrite foundation. It is
not an implementation plan; it is the compatibility checklist for the next
public API skeleton work.

## Baseline

- Authoritative legacy API source: `references/headers`.
- Current public header source: `include/Activator` and
  `include/ActivatorSettings`.
- Current compatibility entry points:
  - `#import <libactivator.h>`
  - `#import <Activator/Activator.h>`
  - `@import Activator`
- Current header delta from `references/headers`:
  - `include/Activator/Activator.h` is a new framework umbrella header.
  - `layout/usr/include/libactivator.h` is the flat compatibility umbrella and
    imports `<Activator/Activator.h>`.
  - `include/ActivatorSettings/ActivatorSettings.h` is a new settings host
    umbrella.
  - The copied 1.9 headers are otherwise API-equivalent, apart from removal of
    a trailing blank line.

## Implementation Status Legend

- `Must implement`: required for source or binary compatibility.
- `Safe stub first`: may initially return conservative empty/default values,
  but must have stable symbols and non-crashing behavior.
- `Runtime-backed`: requires IPC, SpringBoard state, private adapters, or
  device-only behavior before becoming meaningful.
- `Settings-backed`: belongs to the settings UI library and host loading work.
- `Capability gated`: must be evaluated on modern iOS before registration or
  behavior is enabled.
- `Decision needed`: requires project-owner decision before changing the public
  surface or legacy behavior.

## Headers

| Header | Public surface | Initial status | Notes |
| --- | --- | --- | --- |
| `Activator/Activator.h` | Framework umbrella for the Activator module. | Must implement | Imports all 1.9 Activator public headers. |
| `libactivator.h` | Flat legacy umbrella. | Must implement | Installed at `/usr/include/libactivator.h`; imports `<Activator/Activator.h>`. |
| `LAActivatorVersion.h` | `LAActivatorVersion` enum and `LA_PRIVATE_IVARS`. | Must implement | Version values are compatibility constants. Add `LAActivatorVersion_2_0 = 2000000` and report it for the 2.0 rewrite. |
| `LAActivator.h` | Main facade, assignments, metadata, modes, blacklist, profiles, localization, constants, notifications. | Must implement | API skeleton should land before IPC or SpringBoard runtime. |
| `LAEvent.h` | `LAEvent` model and built-in event/userInfo constants. | Must implement | Event constants are compatibility symbols; actual event acquisition is capability gated. |
| `LAListener.h` | `LAListener` protocol for event callbacks, metadata, icons, removal, configuration. | Must implement | Dispatch behavior is runtime-backed; metadata queries can be safe stubs first. |
| `LAEventDataSource.h` | `LAEventDataSource` protocol for event metadata, removal, configuration. | Must implement | Registration and metadata routing can be safe stubs first. |
| `LASettingsViewController.h` | Settings controller class family and configuration controllers. | Settings-backed | Header remains part of the Activator public API. `libactivator` must keep class compatibility shims; real UI implementation lives in `libactivatorsettings.dylib`. |
| `UIImageView+Activator.h` | Listener image category properties. | Settings-backed | Likely implemented with associated objects; loading behavior can be deferred. |
| `ActivatorSettings/ActivatorSettings.h` | `LASCreateSettingsRootViewController`. | Settings-backed | Host-facing entry point for PreferenceBundle, Activator.app, and third-party hosts. |

## LAActivator Facade

### Singleton And State

| Symbol | Status | Notes |
| --- | --- | --- |
| `+sharedInstance` | Must implement | Must return the same object as `LASharedActivator`. |
| `LASharedActivator` | Must implement | Global compatibility variable. |
| `version` | Must implement | Should report `LAActivatorVersion_2_0` for the 2.0 rewrite. |
| `runningInsideSpringBoard` | Runtime-backed | Can be detected locally; behavior gates SpringBoard-only methods. |
| `dangerousToSendEvents` | Runtime-backed | Depends on current mode/state and dispatch safety rules. |

### Listener Lookup And Delivery

| Symbols | Status | Notes |
| --- | --- | --- |
| `listenerForEvent:` | Runtime-backed | Assignment resolution plus listener registry lookup. |
| `sendEventToListener:` | Runtime-backed | Dispatches to assigned listeners. |
| `sendEvent:toListenerWithName:` | Runtime-backed | Direct listener dispatch. |
| `sendEvent:toListenersWithNames:` | Runtime-backed | Multi-listener dispatch. |
| `sendAbortToListener:` | Runtime-backed | Assignment resolution plus abort dispatch. |
| `sendAbortEvent:toListenerWithName:` | Runtime-backed | Direct abort dispatch. |
| `sendAbortEvent:toListenersWithNames:` | Runtime-backed | Multi-listener abort dispatch. |
| `sendPreviewEventToListenerWithName:` | Runtime-backed | Settings preview behavior; may dispatch locally or over IPC. |
| `sendDeactivateEventToListeners:` | Runtime-backed | Needs modern menu/deactivate semantics. |
| `listenerForName:` | Must implement | Registry lookup; safe stub can return `nil`. |
| `hasListenerWithName:` | Must implement | Registry lookup; safe stub can return `NO`. |
| `registerListener:forName:` | Runtime-backed | SpringBoard-only registration. Non-SpringBoard behavior must be explicit and non-crashing. |
| `unregisterListenerWithName:` | Runtime-backed | SpringBoard-only unregistration. |
| `hasSeenListenerWithName:` | Safe stub first | Requires persistent metadata for meaningful behavior. |

### Assignments

| Symbols | Status | Notes |
| --- | --- | --- |
| `assignEvent:toListenerWithName:` | Must implement | Core model/storage API. |
| `assignEvent:toListenersWithNames:` | Must implement | Multi-listener assignment compatibility. |
| `addListenerAssignment:toEvent:` | Must implement | Incremental assignment update. |
| `removeListenerAssignment:fromEvent:` | Must implement | Incremental assignment removal. |
| `unassignEvent:` | Must implement | Clears all listeners for event. |
| `assignedListenerNameForEvent:` | Must implement | Legacy single-listener compatibility view. |
| `assignedListenerNamesForEvent:` | Must implement | Canonical multi-listener query. |
| `eventsAssignedToListenerWithName:` | Must implement | Reverse lookup. |

### Event Registry And Metadata

| Symbols | Status | Notes |
| --- | --- | --- |
| `availableEventNames` | Must implement | Empty array is acceptable before built-ins land. |
| `hasEventWithName:` | Must implement | Registry query. |
| `eventWithNameIsHidden:` | Safe stub first | Data-source-backed metadata. |
| `eventWithNameRequiresAssignment:` | Safe stub first | Data-source-backed metadata. |
| `compatibleModesForEventWithName:` | Safe stub first | May derive from data source; default should be conservative. |
| `eventWithName:isCompatibleWithMode:` | Safe stub first | Compatibility query. |
| `eventWithNameSupportsUnlockingDeviceToSend:` | Runtime-backed | Lock-screen capability. |
| `eventWithNameSupportsRemoval:` | Safe stub first | Data-source-backed metadata. |
| `removeEventWithName:` | Runtime-backed | Calls data source or built-in removal path. |
| `registerEventDataSource:forEventName:` | Must implement | Core event registry. |
| `unregisterEventDataSourceWithEventName:` | Must implement | Core event registry. |
| `eventWithNameSupportsConfiguration:` | Settings-backed | Depends on configuration controller metadata. |
| `configurationViewControllerForEventWithName:` | Settings-backed | Must resolve through the settings compatibility shim and load/coordinate with `libactivatorsettings.dylib`. |

### Listener Metadata

| Symbols | Status | Notes |
| --- | --- | --- |
| `availableListenerNames` | Must implement | Empty array is acceptable before built-ins land. |
| `infoDictionaryValueOfKey:forListenerWithName:` | Safe stub first | Listener metadata query. |
| `listenerWithNameRequiresAssignment:` | Safe stub first | Listener metadata query. |
| `compatibleEventModesForListenerWithName:` | Safe stub first | Listener metadata query. |
| `listenerWithName:isCompatibleWithMode:` | Safe stub first | Listener metadata query. |
| `listenerWithName:isCompatibleWithEventName:` | Safe stub first | Requires event and listener compatibility checks. |
| `listenerWithNameNeedsPoweredDisplay:` | Safe stub first | Listener metadata query. |
| `exclusiveAssignmentGroupsForListenerName:` | Safe stub first | Needed for multi-listener assignment compatibility. |
| `listenerNamesAreMutuallyCompatible:` | Must implement | Core assignment compatibility logic. |
| `iconForListenerName:` | Settings-backed | May ask listener metadata provider. |
| `smallIconForListenerName:` | Settings-backed | May ask listener metadata provider. |
| `imageForListenerName:usingTemplate:` | Settings-backed | Template-based legacy image behavior. |
| `listenerWithNameSupportsRemoval:` | Safe stub first | Listener metadata query. |
| `requestRemovalForListenerWithName:` | Runtime-backed | Calls listener removal hook. |
| `listenerWithNameSupportsConfiguration:` | Settings-backed | Listener configuration support query. |
| `configurationViewControllerForListenerWithName:` | Settings-backed | Must resolve through the settings compatibility shim and load/coordinate with `libactivatorsettings.dylib`. |

### Modes, Blacklist, Profiles, Localization

| Symbols | Status | Notes |
| --- | --- | --- |
| `availableEventModes` | Must implement | Should include legacy modes even before runtime is complete. |
| `currentEventMode` | Runtime-backed | Depends on foreground app, SpringBoard, and lock state. |
| `currentEventModeUnderneathLockScreen` | Runtime-backed | Needs lock-screen state adapter. |
| `supportsUnlockingDeviceToSendEvents` | Runtime-backed | Lock-screen capability. |
| `displayIdentifierForCurrentApplication` | Runtime-backed | Requires modern foreground application lookup. |
| `applicationWithDisplayIdentifierIsBlacklisted:` | Must implement | Core blacklist storage/query. |
| `setApplicationWithDisplayIdentifier:isBlacklisted:` | Must implement | Core blacklist storage/update. |
| `availableProfileNames` | Must implement | Empty/default profile behavior must be defined. |
| `currentProfileName` | Must implement | Profile timing was deferred until core compatibility is stable. |
| `localizedStringForKey:value:` | Safe stub first | Can return value/key before localization resources land. |
| `localizedTitleForEventMode:` | Safe stub first | Data/resource-backed later. |
| `localizedTitleForEventName:` | Safe stub first | Data-source/resource-backed later. |
| `localizedTitleForListenerName:` | Safe stub first | Listener/resource-backed later. |
| `localizedTitleForListenerNames:` | Safe stub first | Should join localized listener names deterministically. |
| `localizedGroupForEventName:` | Safe stub first | Data-source/resource-backed later. |
| `localizedGroupForListenerName:` | Safe stub first | Listener/resource-backed later. |
| `localizedDescriptionForEventMode:` | Safe stub first | Data/resource-backed later. |
| `localizedDescriptionForEventName:` | Safe stub first | Data-source/resource-backed later. |
| `localizedDescriptionForListenerName:` | Safe stub first | Listener/resource-backed later. |

## LAEvent Model

| Symbol | Status | Notes |
| --- | --- | --- |
| `+eventWithName:` | Must implement | Factory for default/current mode. |
| `+eventWithName:mode:` | Must implement | Factory for explicit mode. |
| `-initWithName:` | Must implement | Designated or convenience initializer. |
| `-initWithName:mode:` | Must implement | Must store immutable name/mode. |
| `name` | Must implement | Readonly. |
| `mode` | Must implement | Readonly. |
| `handled` | Must implement | Mutable dispatch flag. |
| `userInfo` | Must implement | Copy semantics. |
| `NSCoding` | Must implement | Legacy compatibility. Additive `NSSecureCoding` can be considered separately. |

## Protocols

### LAListener

The listener protocol has only optional methods. The implementation must check
`respondsToSelector:` before calling any listener callback.

| Group | Methods | Status |
| --- | --- | --- |
| Mode change | `didChangeToEventMode:` | Runtime-backed |
| Event delivery | `receiveEvent:forListenerName:`, `abortEvent:forListenerName:`, `receiveUnlockingDeviceEvent:forListenerName:`, `receiveDeactivateEvent:`, `otherListenerDidHandleEvent:`, `receivePreviewEventForListenerName:` | Runtime-backed |
| Simple event delivery | `receiveEvent:`, `abortEvent:` | Runtime-backed |
| Text metadata | localized title, description, group | Safe stub first |
| Compatibility metadata | requires assignment, compatible modes, compatible event, exclusive groups, info dictionary, powered display | Safe stub first |
| Icon metadata | icon PNG data, small icon PNG data, icon image, small icon image, glyph descriptor | Settings-backed |
| Removal and configuration | supports removal, removal request, configuration controller class, configuration load/save | Runtime-backed and settings-backed |

### LAEventDataSource

| Group | Methods | Status |
| --- | --- | --- |
| Required metadata | localized title, group, description | Must implement dispatch to data source |
| Visibility and assignment | hidden, requires assignment, compatible mode, unlock-to-send support | Safe stub first |
| Removal | supports removal, remove event | Runtime-backed |
| Configuration | configuration controller class, configuration load/save | Settings-backed |

## Settings Public Surface

| Symbol | Status | Notes |
| --- | --- | --- |
| `LASettingsViewController` | Settings-backed | Base settings controller. Class identity must be available from `libactivator`; real behavior lives in `libactivatorsettings.dylib`. |
| `LARootSettingsController` | Settings-backed | Root settings UI. Class identity must be available from `libactivator`; real behavior lives in `libactivatorsettings.dylib`. |
| `LAModeSettingsController` | Settings-backed | Mode-specific settings UI. Class identity must be available from `libactivator`; real behavior lives in `libactivatorsettings.dylib`. |
| `LAEventSettingsController` | Settings-backed | Event assignment UI. Class identity must be available from `libactivator`; real behavior lives in `libactivatorsettings.dylib`. |
| `LAListenerSettingsViewController` | Settings-backed | Listener detail UI. Class identity must be available from `libactivator`; real behavior lives in `libactivatorsettings.dylib`. |
| `LAEventConfigurationViewController` | Settings-backed | Event configuration base class. Class identity must be available from `libactivator`; real behavior lives in `libactivatorsettings.dylib`. |
| `LAListenerConfigurationViewController` | Settings-backed | Listener configuration base class. Class identity must be available from `libactivator`; real behavior lives in `libactivatorsettings.dylib`. |
| `LA_SETTINGS_CONTROLLER(superclass)` | Decision needed | Macro exists for old PreferenceLoader-style superclass substitution. Keep header compatibility; implementation should avoid depending on old host assumptions. |
| `UIImageView (Activator)` | Settings-backed | Category storage can be implemented early; image loading behavior can wait. |
| `LASCreateSettingsRootViewController` | Settings-backed | Host-facing function exported by `libactivatorsettings.dylib`. |

## Constants

### Version Constants

`LAActivatorVersion` preserves legacy version values from 1.3 through 1.9.0.
Add `LAActivatorVersion_2_0 = 2000000`, and make `-[LAActivator version]`
return it for the 2.0 rewrite while preserving older enum values as ABI/source
constants.

### Event Mode Constants

- `LAEventModeSpringBoard`
- `LAEventModeApplication`
- `LAEventModeLockScreen`

These constants are core compatibility symbols. Mode detection is
runtime-backed, but the strings must exist in the public dylib immediately.

### Notifications

- `LAActivatorAvailableListenersChangedNotification`
- `LAActivatorAvailableEventsChangedNotification`
- `LAActivatorAssignmentsChangedNotification`

Notifications are public process-local names. Cross-process state propagation
belongs to IPC, then each process can repost local notifications.

### Built-In Event Name Constants

The public API exposes legacy event names even when the corresponding modern
iOS acquisition is not implemented yet. Constants must exist; registration and
actual delivery are capability gated.

| Event family | Constants |
| --- | --- |
| Menu button | `LAEventNameMenuPressSingle`, `LAEventNameMenuPressDouble`, `LAEventNameMenuPressTriple`, `LAEventNameMenuHoldShort`, `LAEventNameMenuHoldLong` |
| Lock button | `LAEventNameLockHoldShort`, `LAEventNameLockHoldLong`, `LAEventNameLockPressDouble`, `LAEventNameLockPressWithMenu` |
| SpringBoard gestures | `LAEventNameSpringBoardPinch`, `LAEventNameSpringBoardSpread` |
| Status bar | `LAEventNameStatusBarSwipeRight`, `LAEventNameStatusBarSwipeLeft`, `LAEventNameStatusBarTapDouble`, `LAEventNameStatusBarTapDoubleLeft`, `LAEventNameStatusBarTapDoubleRight`, `LAEventNameStatusBarTapSingle`, `LAEventNameStatusBarTapSingleLeft`, `LAEventNameStatusBarTapSingleRight`, `LAEventNameStatusBarHold`, `LAEventNameStatusBarHoldLeft`, `LAEventNameStatusBarHoldRight` |
| Volume | `LAEventNameVolumeDownUp`, `LAEventNameVolumeUpDown`, `LAEventNameVolumeDisplayTap`, `LAEventNameVolumeToggleMuteTwice`, `LAEventNameVolumeDownHoldShort`, `LAEventNameVolumeUpHoldShort`, `LAEventNameVolumeDownPress`, `LAEventNameVolumeUpPress`, `LAEventNameVolumeBothPress` |
| Edge slide | `LAEventNameSlideInFromBottom`, `LAEventNameSlideInFromBottomLeft`, `LAEventNameSlideInFromBottomRight`, `LAEventNameSlideInFromLeft`, `LAEventNameSlideInFromRight`, `LAEventNameStatusBarSwipeDown`, `LAEventNameSlideInFromTop`, `LAEventNameSlideInFromTopLeft`, `LAEventNameSlideInFromTopRight` |
| Two-finger edge slide | `LAEventNameTwoFingerSlideInFromBottom`, `LAEventNameTwoFingerSlideInFromBottomLeft`, `LAEventNameTwoFingerSlideInFromBottomRight`, `LAEventNameTwoFingerSlideInFromLeft`, `LAEventNameTwoFingerSlideInFromRight`, `LAEventNameTwoFingerSlideInFromTop`, `LAEventNameTwoFingerSlideInFromTopLeft`, `LAEventNameTwoFingerSlideInFromTopRight` |
| Drag off screen | `LAEventNameDragOffBottom`, `LAEventNameDragOffLeft`, `LAEventNameDragOffRight`, `LAEventNameDragOffTop` |
| Screen-side swipes | `LAEventScreenBottomSwipeLeft`, `LAEventScreenBottomSwipeRight`, `LAEventScreenLeftSwipeDown`, `LAEventScreenLeftSwipeUp`, `LAEventScreenRightSwipeDown`, `LAEventScreenRightSwipeUp` |
| Motion | `LAEventNameMotionShake` |
| Headset | `LAEventNameHeadsetButtonPressSingle`, `LAEventNameHeadsetButtonHoldShort`, `LAEventNameHeadsetConnected`, `LAEventNameHeadsetDisconnected` |
| Lock screen clock | `LAEventNameLockScreenClockDoubleTap`, `LAEventNameLockScreenClockTapHold`, `LAEventNameLockScreenClockSwipeLeft`, `LAEventNameLockScreenClockSwipeRight`, `LAEventNameLockScreenClockSwipeDown` |
| Power | `LAEventNamePowerConnected`, `LAEventNamePowerDisconnected` |
| Multitouch | `LAEventNameThreeFingerTap`, `LAEventNameThreeFingerPinch`, `LAEventNameThreeFingerSpread`, `LAEventNameFourFingerTap`, `LAEventNameFourFingerPinch`, `LAEventNameFourFingerSpread`, `LAEventNameFiveFingerTap`, `LAEventNameFiveFingerPinch`, `LAEventNameFiveFingerSpread` |
| Clamshell | `LAEventNameClamshellOpen`, `LAEventNameClamshellClose` |
| SpringBoard icon gestures | `LAEventNameSpringBoardIconFlickUp`, `LAEventNameSpringBoardIconFlickDown`, `LAEventNameSpringBoardIconFlickLeft`, `LAEventNameSpringBoardIconFlickRight` |
| Device state | `LAEventNameDeviceLocked`, `LAEventNameDeviceUnlocked` |
| Network | `LAEventNameNetworkJoinedWiFi`, `LAEventNameNetworkLeftWiFi` |
| Fingerprint sensor | `LAEventNameFingerprintSensorPressSingle` |

`LAEventNameSlideInFromTop` is a macro alias for
`LAEventNameStatusBarSwipeDown`, so there is no separate exported symbol for
that alias.

### Event User Info Constants

- `LAEventUserInfoDisplayIdentifier`
- `LAEventUserInfoIconView`
- `LAEventUserInfoUnlockedDeviceToSendEvent`

## Compatibility Issues To Resolve Before Implementation

1. `LAActivator.h` currently imports `<libkern/OSAtomic.h>`, but the public API
   surface does not expose OSAtomic types. Remove this obsolete import from the
   rewritten public header.
2. `LASettingsViewController.h` is part of the Activator public header set, and
   some third-party jailbreak apps dynamically link `libactivator.dylib` to
   present Settings UI. `libactivator` must therefore keep compatibility shims
   for the public settings classes, while real Settings UI implementation lives
   in `libactivatorsettings.dylib`.
3. `LAEvent` declares `NSCoding`, not `NSSecureCoding`. Implement `NSCoding`
   for compatibility; additive secure coding support needs separate approval.
4. `LA_SETTINGS_CONTROLLER(superclass)` encodes old settings host flexibility.
   Keep the macro for source compatibility, but do not let it drive the modern
   host architecture without an explicit need.
5. Legacy built-in event constants do not imply immediate event registration.
   Each event family still needs a modern iOS capability assessment before it
   becomes available in `availableEventNames`.

## Recommended Next Implementation Slice

1. Define all public constants and `LASharedActivator` in `libactivator`.
2. Add `LAActivatorVersion_2_0 = 2000000` and remove the obsolete
   `<libkern/OSAtomic.h>` import.
3. Implement `LAEvent` with immutable `name`/`mode`, `handled`, `userInfo`, and
   `NSCoding`.
4. Implement `LAActivator` singleton with safe empty registries and no-crash
   behavior for all public selectors.
5. Add compatibility shims in `libactivator` for public settings classes, with
   real Settings UI behavior delegated to `libactivatorsettings.dylib`.
6. Add compile/link checks that reference every exported constant, instantiate
   `LAEvent`, call representative `LAActivator` selectors, and import through
   all supported entry points.
7. Document every safe stub behavior before adding IPC or SpringBoard runtime.
