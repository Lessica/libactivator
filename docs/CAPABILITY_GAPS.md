# Capability Gaps

This table tracks runtime capabilities that are not implemented yet, including
whether a modern iOS reference exists. Do not fill missing behavior by guessing
SPI behavior.

| Capability | Current placeholder | Research status | Required follow-up |
| --- | --- | --- | --- |
| SpringBoard foreground application state | Implemented in `LAActivatorRuntimeStateProvider`; SpringBoard queries `_accessibilityFrontMostApplication` on demand. | Code implemented without `BKSApplicationStateMonitor`. | Verify foreground display identifier behavior during app switcher and transient states on device. |
| Home screen vs in-application mode | Implemented through SpringBoard home-screen visibility hooks and runtime mode recomputation. | Code implemented with non-Logos hooks. | Verify mode transitions between home screen, foreground app, and app switcher on device. |
| Lock screen mode | Implemented through `SBLockScreenManager` lock-state checks, CoverSheet visibility, and blank-screen notifications. | Code implemented with SpringBoard-only state hooks. | Verify lock-screen visibility and underneath-mode behavior on device. |
| Event mode change notifications | Implemented through state-provider recomputation and listener `didChangeToEventMode:` callbacks. | Code implemented. | Verify callback timing and duplicate suppression on device. |
| Unlock-to-send support | Implemented as callback-only compatibility path with private SpringBoard capability detection. | Code implemented without passcode submission or automatic unlock. | Verify callback behavior for compatible and incompatible lock-screen listeners on device. |
| Deferred no-touch dispatch | Implemented through `_UISystemGestureWindow -sendEvent:` touch tracking and deferred normal event dispatch. | Code implemented with old handled-on-enqueue semantics. | Verify active-touch tracking and deferred dispatch on device. |
| Settings UI controller factories | Configuration support queries return `NO`; factory methods return `nil`. | `libactivatorsettings.dylib` host API and controller factory contract. | Settings UI design decision. |
| Built-in event sources | No built-in event hooks are registered yet. | Per-event modern capability assessment and hook/source strategy. | Event-family research and owner review. |
| Built-in listeners/actions | No built-in listener/action implementation is registered yet. | Per-listener/action modern equivalent and package/resource layout. | Listener/action priority and implementation notes. |
