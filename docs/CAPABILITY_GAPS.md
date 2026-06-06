# Capability Gaps

This table tracks runtime capabilities that still need modern iOS research or
project-owner input before implementation. Do not fill these gaps by guessing
SPI behavior.

| Capability | Current placeholder | What must be determined | Owner input needed |
| --- | --- | --- | --- |
| SpringBoard foreground application state | `LAActivatorRuntimeStateProvider` returns safe process-based fallback values. | Modern iOS 15+ way to identify the foreground application from SpringBoard, including app switcher and transient states. | Reference implementation or verified private API notes. |
| Home screen vs in-application mode | `currentEventMode` returns `springboard` inside SpringBoard and `application` elsewhere. | Reliable SpringBoard state source for home screen visibility versus foreground application visibility. | Known SpringBoard state sample. |
| Lock screen mode | `currentEventModeUnderneathLockScreen` returns `application`; lock-screen mode is not detected. | Reliable lock-screen visibility and underneath-mode state on iOS 15+. | Known SpringBoard/lock-screen state sample. |
| Event mode change notifications | No runtime state change observer is installed. | Which SpringBoard notifications/hooks should trigger `activator:didChangeToEventMode:`. | Modern state transition hooks. |
| Unlock-to-send support | `supportsUnlockingDeviceToSendEvents` returns `NO`. | Whether old unlock-to-send behavior should exist on iOS 15+, and which lock/unlock APIs are valid. | Product decision and modern lock behavior notes. |
| Deferred no-touch dispatch | `requires-no-touch-events` metadata is exposed, but dispatch does not defer while touches are active. | Modern touch activity source and whether deferred dispatch is still required. | SpringBoard touch tracking strategy. |
| Settings UI controller factories | Configuration support queries return `NO`; factory methods return `nil`. | `libactivatorsettings.dylib` host API and controller factory contract. | Settings UI design decision. |
| Built-in event sources | No built-in event hooks are registered yet. | Per-event modern capability assessment and hook/source strategy. | Event-family research and owner review. |
| Built-in listeners/actions | No built-in listener/action implementation is registered yet. | Per-listener/action modern equivalent and package/resource layout. | Listener/action priority and implementation notes. |
