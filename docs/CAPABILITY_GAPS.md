# Capability Gaps

This table tracks runtime capabilities that are not implemented yet, including whether a modern iOS reference exists. Do not fill missing behavior by guessing SPI behavior.

| Capability | Current placeholder | Research status | Required follow-up |
| --- | --- | --- | --- |
| SpringBoard foreground application state | Implemented in `LAActivatorRuntimeStateProvider`; SpringBoard queries `_accessibilityFrontMostApplication` on demand. | Verified on iPhone XR iOS 15.0 roothide without `BKSApplicationStateMonitor`. | Re-verify foreground display identifier behavior on higher iOS versions. |
| Home screen vs in-application mode | Implemented through SpringBoard home-screen visibility hooks and runtime mode recomputation. | Verified on iPhone XR iOS 15.0 roothide with non-Logos hooks. | Re-verify mode transitions on higher iOS versions. |
| Lock screen mode | Implemented through `SBLockScreenManager` lock-state checks, CoverSheet visibility, and blank-screen notifications. | Verified on iPhone XR iOS 15.0 roothide with SpringBoard-only state hooks. | Re-verify lock-screen visibility and underneath-mode behavior on higher iOS versions. |
| Event mode change notifications | Implemented through state-provider recomputation and listener `didChangeToEventMode:` callbacks. | Verified on iPhone XR iOS 15.0 roothide. | Re-verify callback timing and duplicate suppression on higher iOS versions. |
| Unlock-to-send support | Implemented as callback-only compatibility path with private SpringBoard capability detection. | Callback-only behavior is the scoped compatibility requirement; passcode submission and complete active unlock flow are not part of the legacy core behavior. | Re-verify callback behavior on higher iOS versions. |
| Deferred no-touch dispatch | Implemented through `_UISystemGestureWindow -sendEvent:` touch tracking and deferred normal event dispatch. | Verified on iPhone XR iOS 15.0 roothide with old handled-on-enqueue semantics. | Re-verify active-touch tracking and deferred dispatch on higher iOS versions. |
| Settings UI controller factories | Configuration support queries return `NO`; factory methods return `nil`. | `libactivatorsettings.dylib` host API and controller factory contract. | Implement with the Settings UI stage. |
| Built-in event sources | No built-in event hooks are registered yet. | Per-event modern capability assessment and hook/source strategy. | Event-family research and owner review. |
| Built-in listeners/actions | `libactivator.system.nothing` is implemented; other staged listener/action metadata remains metadata-only. | Per-listener/action modern equivalent and package/resource layout; follow the 1.9.13 bundled resource catalog while excluding obsolete social compose actions. | Listener/action priority and implementation notes. |
