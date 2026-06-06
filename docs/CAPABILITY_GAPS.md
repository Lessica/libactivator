# Capability Gaps

This table tracks runtime capabilities that are not implemented yet, including
whether a modern iOS reference exists. Do not fill missing behavior by guessing
SPI behavior.

| Capability | Current placeholder | Research status | Required follow-up |
| --- | --- | --- | --- |
| SpringBoard foreground application state | `LAActivatorRuntimeStateProvider` returns safe process-based fallback values. | Reference exists: SpringBoard can query `_accessibilityFrontMostApplication`; `BKSApplicationStateMonitor` can observe foreground transitions and filter extensions/view services. | Implement SpringBoard-only state provider and verify foreground display identifier behavior during app switcher and transient states. |
| Home screen vs in-application mode | `currentEventMode` returns `springboard` inside SpringBoard and `application` elsewhere. | Reference exists: SpringBoard view visibility can be observed from `SBIconController` and modern icon manager/root folder controller callbacks. | Implement non-Logos SpringBoard hooks and fold home-screen visibility into event-mode computation. |
| Lock screen mode | `currentEventModeUnderneathLockScreen` returns `application`; lock-screen mode is not detected. | Reference exists: lock status can be queried with `SBLockScreenManager`/SpringBoardServices; lock-screen visibility can be observed from CoverSheet controllers and backlight state. | Implement lock state, lock-screen visibility, and underneath-mode computation in the SpringBoard state provider. |
| Event mode change notifications | No runtime state change observer is installed. | Reference exists: foreground app, home screen, lock screen, and screen blanking changes provide mode recompute triggers. | Notify registered listeners through `activator:didChangeToEventMode:` when the computed mode changes. |
| Unlock-to-send support | `supportsUnlockingDeviceToSendEvents` returns `NO`. | Reference exists for SpringBoard unlock requests: `SBLockScreenManager` can query UI lock state and attempt unlock after waking the screen. | Design a private unlock service, verify no-passcode/passcode/biometric behavior on device, then decide when to enable `receiveUnlockingDeviceEvent:forListenerName:`. |
| Deferred no-touch dispatch | `requires-no-touch-events` metadata is exposed, but dispatch does not defer while touches are active. | Reference exists: `_UISystemGestureWindow -sendEvent:` can observe SpringBoard touch events. | Implement a SpringBoard touch activity tracker and defer matching dispatch until active touches end. |
| Settings UI controller factories | Configuration support queries return `NO`; factory methods return `nil`. | `libactivatorsettings.dylib` host API and controller factory contract. | Settings UI design decision. |
| Built-in event sources | No built-in event hooks are registered yet. | Per-event modern capability assessment and hook/source strategy. | Event-family research and owner review. |
| Built-in listeners/actions | No built-in listener/action implementation is registered yet. | Per-listener/action modern equivalent and package/resource layout. | Listener/action priority and implementation notes. |
