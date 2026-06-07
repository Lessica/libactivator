# Built-In Capability Inventory

This document records the legacy `master` built-in capabilities as factual inventory. It is not an implementation plan and does not mark any built-in event, listener, or action as implemented in the rewrite.

## Evidence Summary

- Event metadata resources: 61 `Info.plist` bundles under `references/master/layout/Library/Activator/Events`.
- Static listener/action metadata resources: 59 `Info.plist` bundles under `references/master/layout/Library/Activator/Listeners`.
- Staged listener/action metadata resources: 58 `Info.plist` bundles. The legacy `libactivator.twitter.compose-tweet` resource is intentionally excluded because the modern project will not implement that Twitter-specific action.
- Static listener/action registration: 59 `registerListener:` calls in `references/master/LASimpleListener.x`.
- Event metadata registration: `references/master/LADefaultEventDataSource.m` scans `/Library/Activator/Events` and registers each bundle name.
- Dynamic listener registration:
  - Applications: `references/master/LAApplicationListener.x`.
  - Menus: `references/master/LAMenuListener.m`.
  - SBSettings toggles: `references/master/LAToggleListener.m`.

Modern status values:

- `resource-only`: metadata can be staged without implementing runtime behavior.
- `implementable`: behavior appears feasible without an owner-supplied SPI decision, but still needs implementation and validation.
- `needs-owner-reference`: modern SPI or behavior is unclear; ask the project owner before implementation.
- `obsolete`: legacy capability has no direct modern equivalent or depends on removed frameworks.
- `defer-to-settings-ui`: inventory belongs to Settings UI rather than runtime.

When a row lists multiple legacy names, every field in that row applies to each listed name.

## Built-In Event Sources

Every event below has a resource path of `references/master/layout/Library/Activator/Events/<legacy name>/Info.plist`. The resource itself is `resource-only`; acquisition status is tracked by the runtime dependency column.

| Legacy names | Group | Modes / flags | Legacy source | Runtime dependency or SPI family | Modern status | First validation |
| --- | --- | --- | --- | --- | --- | --- |
| `libactivator.headset-button.hold.short`, `libactivator.headset-button.press.single`, `libactivator.headset.connected`, `libactivator.headset.disconnected` | Headset | all modes | `Events.x`, `LADefaultEventDataSource.m` | Headset button hooks and audio route notification through SpringBoard / `AVSystemController` era SPI. | `needs-owner-reference` | Owner-assisted SPI probe, then roothide manual checklist. |
| `libactivator.menu.press.single`, `libactivator.menu.press.double`, `libactivator.menu.press.triple`, `libactivator.menu.hold.short`, `libactivator.menu.hold.long` | Home Button | all modes | `Events.x`, `LADefaultEventDataSource.m` | SpringBoard menu/home button hooks and timing state. | `needs-owner-reference` | Owner-assisted SPI probe, then roothide manual checklist. |
| `libactivator.lock.press.double`, `libactivator.lock.hold.short` | Sleep Button | all modes | `Events.x`, `LADefaultEventDataSource.m` | SpringBoard lock button hooks, lock timer, status bar lock state side effects. | `needs-owner-reference` | Owner-assisted SPI probe, then roothide manual checklist. |
| `libactivator.volume.up.press`, `libactivator.volume.down.press`, `libactivator.volume.up.hold.short`, `libactivator.volume.down.hold.short`, `libactivator.volume.up-down`, `libactivator.volume.down-up`, `libactivator.volume.both.press`, `libactivator.volume.toggle-mute-twice`, `libactivator.volume.display-tap` | Volume Buttons | all modes | `Events.x`, `LADefaultEventDataSource.m` | SpringBoard volume/ringer hooks, `VolumeControl`, alert/ringtone suppression, and volume HUD touch handling. | `needs-owner-reference` | Owner-assisted SPI probe, then roothide manual checklist. |
| `libactivator.motion.shake` | Motion | all modes | `Events.x`, `LADefaultEventDataSource.m` | SpringBoard motion handling hooks. | `needs-owner-reference` | Owner-assisted SPI probe. |
| `libactivator.power.connected`, `libactivator.power.disconnected` | Power | all modes | `Events.x`, `LADefaultEventDataSource.m` | SpringBoard AC power state callbacks. | `implementable` after modern notification/source probe | Roothide manual checklist. |
| `libactivator.statusbar.tap.single`, `libactivator.statusbar.tap.double`, `libactivator.statusbar.hold`, `libactivator.statusbar.swipe.left`, `libactivator.statusbar.swipe.right`, `libactivator.statusbar.swipe.down`, `libactivator.statusbar.tap.single.left`, `libactivator.statusbar.tap.single.right`, `libactivator.statusbar.tap.double.left`, `libactivator.statusbar.tap.double.right`, `libactivator.statusbar.hold.left`, `libactivator.statusbar.hold.right` | Status Bar | all modes | `Events.x`, `LADefaultEventDataSource.m` | SpringBoard status bar touch observation. The project owner has noted that modern in-app status bar touch does not require user-app injection, but the concrete implementation is still a later capability task. | `needs-owner-reference` | Owner-assisted SPI probe, then roothide manual checklist. |
| `libactivator.slide-in.bottom-left`, `libactivator.slide-in.bottom`, `libactivator.slide-in.bottom-right`, `libactivator.slide-in.top-left`, `libactivator.slide-in.top-right`, `libactivator.slide-in.left-top`, `libactivator.slide-in.left`, `libactivator.slide-in.left-bottom`, `libactivator.slide-in.right-top`, `libactivator.slide-in.right`, `libactivator.slide-in.right-bottom` | Slide In Gesture | all modes; left/right top/bottom variants are hidden in resources | `SlideEvents.x`, `LADefaultEventDataSource.m` | Edge gesture windows and SpringBoard touch handling. | `needs-owner-reference` | Roothide manual checklist with touch scenarios. |
| `libactivator.two-finger-slide-in.bottom-left`, `libactivator.two-finger-slide-in.bottom`, `libactivator.two-finger-slide-in.bottom-right`, `libactivator.two-finger-slide-in.top-left`, `libactivator.two-finger-slide-in.top`, `libactivator.two-finger-slide-in.top-right`, `libactivator.two-finger-slide-in.left-top`, `libactivator.two-finger-slide-in.left`, `libactivator.two-finger-slide-in.left-bottom`, `libactivator.two-finger-slide-in.right-top`, `libactivator.two-finger-slide-in.right`, `libactivator.two-finger-slide-in.right-bottom` | Two Finger Slide In Gesture | all modes; left/right top/bottom variants are hidden in resources | `SlideEvents.x`, `LADefaultEventDataSource.m` | Edge gesture windows and two-finger touch tracking. | `needs-owner-reference` | Roothide manual checklist with touch scenarios. |
| `libactivator.springboard.pinch`, `libactivator.springboard.spread` | SpringBoard | `springboard` only | `Events.x`, `LADefaultEventDataSource.m` | SpringBoard icon scroll view / icon touch gesture hooks. | `needs-owner-reference` | Roothide manual checklist on the home screen. |
| `libactivator.lockscreen.clock.double-tap` | Lock Screen | `lockscreen` only | `Events.x`, `LADefaultEventDataSource.m` | Lock screen clock view touch hooks. | `needs-owner-reference` | Roothide manual checklist on the lock screen. |

## Built-In Listeners And Actions

Every static listener/action below has a resource path of `references/master/layout/Library/Activator/Listeners/<legacy name>/Info.plist`. The legacy selector or URL is read from that resource and dispatched by `LASimpleListener.x`.

| Legacy names | Group | Selector / behavior source | Modes / special metadata | Runtime dependency or SPI family | Modern status | First validation |
| --- | --- | --- | --- | --- | --- | --- |
| `libactivator.system.nothing` | System Actions | `doNothing` | all modes; incompatible with lock/menu press events | none | `implemented` | SpringBoard testing IPC dispatch test. |
| `libactivator.system.homebutton`, `libactivator.system.sleepbutton` | System Actions | `homeButton`, `sleepButton` | all modes; home requires no-touch; both have incompatible hardware-button events | HID event generation or SpringBoard button simulation. | `needs-owner-reference` | Owner-assisted SPI probe, then roothide manual checklist. |
| `libactivator.system.respring`, `libactivator.system.reboot`, `libactivator.system.powerdown` | System Actions | `respring`, `reboot`, `powerDown` | all modes | SpringBoard lifecycle / power SPI. | `needs-owner-reference` | Roothide manual checklist. |
| `libactivator.system.safemode` | System Actions | `safeMode` resource selector, but the legacy method body is commented out in `LASimpleListener.x`. | all modes | Loader/safe-mode behavior decision. | `needs-owner-reference` | Owner decision before implementation. |
| `libactivator.system.spotlight`, `libactivator.system.first-springboard-page`, `libactivator.system.activate-switcher`, `libactivator.system.show-now-playing-bar`, `libactivator.audio.show-volume-bar`, `libactivator.system.activate-notification-center` | System Actions / Audio | `spotlight`, `firstSpringBoardPage`, `activateSwitcher`, `showNowPlayingBar`, `showVolumeBar`, `activateNotificationCenter` | springboard/application for most; spotlight and first page require no-touch; notification center and switcher have incompatible event lists | SpringBoard UI controllers, switcher, search, bulletin/list UI, volume bar UI. | `needs-owner-reference` | Owner-assisted SPI probe, then roothide manual checklist. |
| `libactivator.system.take-screenshot` | System Actions | `takeScreenshot` | all modes | SpringBoard screenshot service. | `needs-owner-reference` | Roothide manual checklist. |
| `libactivator.system.voice-control`, `libactivator.system.virtual-assistant`, `libactivator.settings.virtual-assistant` | System Actions / Settings | `voiceControl`, `activateVirtualAssistant`, Settings URL action | all modes for system actions; springboard/application for Settings URL | Voice Control / assistant SPI and Settings URL handling. | `needs-owner-reference` | Owner-assisted SPI probe. |
| `libactivator.twitter.compose-tweet` | System Actions | `composeTweet` | springboard/application | Legacy `TWTweetComposeViewController` flow. | `obsolete`; not staged | No implementation; no replacement planned in the current catalog. |
| `libactivator.lockscreen.dismiss`, `libactivator.lockscreen.show`, `libactivator.lockscreen.toggle` | Lock Screen | `dismissLockScreen`, `showLockScreen`, `toggleLockScreen` | dismiss is lockscreen-only; show is springboard/application; toggle is all modes | SpringBoard lock service / CoverSheet SPI. | `needs-owner-reference` | Roothide manual checklist. |
| `libactivator.ipod.toggle-playback`, `libactivator.ipod.pause-playback`, `libactivator.ipod.resume-playback`, `libactivator.ipod.previous-track`, `libactivator.ipod.next-track`, `libactivator.ipod.music-controls` | Audio | `togglePlayback`, `pauseMedia`, `playMedia`, `previousTrack`, `nextTrack`, `musicControls` | all modes | Media playback controller / now-playing UI SPI. | `needs-owner-reference` | Owner-assisted SPI probe. |
| `libactivator.phone.favorites`, `libactivator.phone.contacts`, `libactivator.phone.keypad`, `libactivator.phone.recents`, `libactivator.phone.voicemail` | Phone | Phone URL actions in `LASimpleListener.x` | springboard/application | SpringBoard URL opening and modern Phone URL availability. | `implementable` after URL validation | Roothide manual checklist. |
| `libactivator.settings.about`, `libactivator.settings.accessibility`, `libactivator.settings.auto-lock`, `libactivator.settings.bluetooth`, `libactivator.settings.brightness`, `libactivator.settings.date-time`, `libactivator.settings.equalizer`, `libactivator.settings.facetime`, `libactivator.settings.general`, `libactivator.settings.icloud`, `libactivator.settings.international`, `libactivator.settings.keyboard`, `libactivator.settings.location-services`, `libactivator.settings.music`, `libactivator.settings.network`, `libactivator.settings.notes`, `libactivator.settings.notifications`, `libactivator.settings.phone`, `libactivator.settings.photos`, `libactivator.settings.safari`, `libactivator.settings.sounds`, `libactivator.settings.store`, `libactivator.settings.twitter`, `libactivator.settings.usage`, `libactivator.settings.vpn`, `libactivator.settings.wallpaper`, `libactivator.settings.wifi` | Settings | `openURLWithActivator:event:listenerName:` and resource `url` keys | springboard/application | SpringBoard URL opening and modern Settings URL availability. | `implementable` after URL validation | Roothide manual checklist. |

## Dynamic Listener Families

| Legacy name rule | Category / group | Legacy source | Resource path | Runtime dependency or SPI family | Modern status | First validation |
| --- | --- | --- | --- | --- | --- | --- |
| Application bundle display identifiers, excluding legacy ignored system identifiers | System Applications, User Applications, Web Clips | `LAApplicationListener.x` | no fixed resource; metadata comes from SpringBoard app objects | SpringBoard application model, app activation, app icons, lock-screen camera special case. | `needs-owner-reference` | Roothide manual checklist with app launch/suspend scenes. |
| Menu keys from `LAMenuSettings` preferences | Menus | `LAMenuListener.m` | no fixed resource; menu title/items come from preferences | Settings UI-created menu data and SpringBoard action sheet presentation. | `defer-to-settings-ui` | Settings UI scenario test after menu editor exists. |
| `activatortoggles.<toggle name>` for SBSettings toggle bundles under `/Library/SBSettings/Toggles` | SBSettings Toggles | `LAToggleListener.m` | external SBSettings toggle bundles and theme icons | Legacy SBSettings plugin ABI loaded through `dlopen`. | `obsolete` unless a modern compatibility target is explicitly chosen | Owner decision; no sample package expected. |

## Resource Metadata Semantics

- Event metadata keys observed in legacy resources: `title`, `description`, `group`, `compatible-modes`, and `hidden`.
- Listener metadata keys observed in legacy resources: `title`, `description`, `group`, `selector`, `url`, `compatible-modes`, `incompatible-events`, and `requires-no-touch-events`.
- Legacy event metadata was loaded by `LADefaultEventDataSource` from `/Library/Activator/Events/<event name>/Info.plist` after an optional `CoreFoundationVersion` gate.
- Legacy listener metadata was loaded from `/Library/Activator/Listeners/<listener name>/Info.plist` or from `Listeners/bundled.plist`.
- Legacy localization was staged by the old Localization makefiles to `/Library/Activator`, and `symlink_localizations.sh` linked those `.lproj` directories into `Activator.app`. Runtime localization then used the Activator support bundle first, followed by event/listener bundles.
- The modern resource catalog stages `en.lproj/Localizable.strings` and `zh-Hans.lproj/Localizable.strings` under `/Library/Activator`. Keys are derived from staged metadata using the existing `EVENT_*`, `LISTENER_*`, and `MODE_*` lookup scheme.
- The checked-in legacy `layout/Library/Activator` resources contain metadata plists only; app icons and launch images live under `Applications/Activator.app`.
- Modern implementation should stage metadata through the existing rootful/rootless/roothide layout rules and use `jbroot(...)` at runtime.

## Settings UI Boundary

Legacy Settings controllers in `references/master/*SettingsController*`, `Preferences.m`, `Activator.m`, and `LASettingsViewControllers.m` are not part of this built-in runtime inventory. They remain in the Settings UI direction and should be implemented through `libactivatorsettings.dylib`.
