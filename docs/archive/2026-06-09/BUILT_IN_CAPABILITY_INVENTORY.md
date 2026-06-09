# Built-In Capability Inventory

This document records the Activator 1.9.13 built-in capabilities as factual inventory. It is not an implementation plan and does not mark any built-in event, listener, or action as implemented in the rewrite.

## Evidence Summary

- Baseline package: `references/latest/libactivator_1.9.13~rc6_iphoneos-arm.deb`.
- Event metadata resources: 121 entries in `references/latest/package/Library/Activator/Events/bundled.plist`, staged as `layout/Library/Activator/Events/bundled.plist`.
- Listener/action metadata resources: 117 entries in `references/latest/package/Library/Activator/Listeners/bundled.plist`; 114 entries are staged after excluding the social compose actions `libactivator.twitter.compose-tweet`, `libactivator.facebook.compose-post`, and `libactivator.weibo.compose-post`.
- Listener glyph/resource directories: 156 directories in the 1.9.13 package; 153 are staged after excluding the same social compose action resources.
- Legacy implementation references remain split across `references/master/Events.x`, `references/master/SlideEvents.x`, `references/master/LASimpleListener.x`, `references/master/LAApplicationListener.x`, `references/master/LAMenuListener.m`, and `references/master/LAToggleListener.m`, but they are behavior references only.

Modern status values:

- `resource-only`: metadata can be staged without implementing runtime behavior.
- `implemented`: behavior exists in the rewrite and has stable test coverage for its stated scope.
- `implementable`: behavior appears feasible without an owner-supplied SPI decision, but still needs implementation and validation.
- `needs-owner-reference`: modern SPI or behavior is unclear; ask the project owner before implementation.
- `obsolete`: legacy capability has no direct modern equivalent or depends on removed frameworks or obsolete third-party service integrations.
- `defer-to-settings-ui`: inventory belongs to Settings UI rather than runtime.

## Built-In Event Source Families

All event metadata is staged from `Events/bundled.plist`; metadata presence does not register a hook or imply runtime behavior.

| Family | Count | Representative legacy names | Runtime dependency or SPI family | Modern status | First validation |
| --- | --- | --- | --- | --- | --- |
| Home button | 5 | `libactivator.menu.press.single`, `libactivator.menu.press.double`, `libactivator.menu.hold.short` | SpringBoard hardware button hooks and timing state. | `needs-owner-reference` | Owner-assisted SPI probe, then roothide checklist. |
| Sleep button | 7 | `libactivator.lock.hold.short`, `libactivator.lock.hold.long`, `libactivator.lock.press.with-menu` | SpringBoard lock button hooks, lock timer, and hardware chord state. | `needs-owner-reference` | Owner-assisted SPI probe, then roothide checklist. |
| Volume buttons | 11 | `libactivator.volume.up.press`, `libactivator.volume.mute`, `libactivator.volume.down.press.with-menu` | SpringBoard volume/ringer hooks, volume HUD touch handling, and hardware chord state. | `needs-owner-reference` | Owner-assisted SPI probe, then roothide checklist. |
| Status bar | 11 | `libactivator.statusbar.tap.single`, `libactivator.statusbar.swipe.down`, `libactivator.statusbar.hold.right` | Modern status bar touch observation without user-app injection. | `needs-owner-reference` | Owner-assisted SPI probe, then roothide checklist. |
| Slide in / slide out / drag along | 32 | `libactivator.slide-in.bottom`, `libactivator.two-finger-slide-in.left`, `libactivator.drag-along.screen-bottom.left-to-right` | SpringBoard gesture recognizers, edge windows, and touch routing. | `needs-owner-reference` | Roothide touch checklist. |
| Multitouch gestures | 9 | `libactivator.three-finger.tap`, `libactivator.four-finger.pinch`, `libactivator.five-finger.spread` | SpringBoard touch gesture recognition. | `needs-owner-reference` | Roothide touch checklist. |
| SpringBoard and icon gestures | 6 | `libactivator.springboard.pinch`, `libactivator.icon.flick.up` | SpringBoard icon/root folder views and icon gesture hooks. | `needs-owner-reference` | Roothide home-screen checklist. |
| Lock screen | 5 | `libactivator.lockscreen.clock.double-tap`, `libactivator.lockscreen.clock.swipe-left` | CoverSheet/lock-screen view hooks. | `needs-owner-reference` | Roothide lock-screen checklist. |
| Device, power, network, headset, watch, car, Smart Cover, scheduled, motion, fingerprint, gesture bar, 3D Touch, media playback | 35 | `libactivator.device.locked`, `libactivator.power.connected`, `libactivator.network.joined-wifi`, `libactivator.fingerprint-sensor.press.twice` | Mixed SpringBoard notifications, hardware state, unavailable legacy sensors, and modern iOS capability probes. | `needs-owner-reference` by default; obvious notification-backed items may become `implementable` after probe. | Owner-assisted SPI probe or targeted roothide checklist. |

## Built-In Listener And Action Families

All listener/action metadata is staged from `Listeners/bundled.plist` except the excluded social compose actions. Metadata presence does not register a listener object; concrete listeners/actions must be implemented and registered separately.

| Family | Count | Representative legacy names | Runtime dependency or behavior source | Modern status | First validation |
| --- | --- | --- | --- | --- | --- |
| No-op action | 1 | `libactivator.system.nothing` | Marks the event handled and suppresses the original action. | `implemented` | SpringBoard testing IPC dispatch test. |
| Audio and media | 11 | `libactivator.ipod.toggle-playback`, `libactivator.audio.show-volume-bar`, `libactivator.audio.launch-playing-app` | Media remote commands, now-playing state, volume UI, and audio app launch. | `needs-owner-reference` | Owner-assisted SPI probe. |
| Phone | 7 | `libactivator.phone.contacts`, `libactivator.phone.answer-call`, `libactivator.phone.disconnect-call` | Phone URL handling and call control SPI. | URL actions are `implementable` after validation; call control needs owner reference. | Roothide URL/call checklist. |
| Settings URL actions | 47 | `libactivator.settings.wifi`, `libactivator.settings.battery`, `libactivator.settings.privacy` | SpringBoard URL opening and modern Settings URL availability. | `implementable` after URL validation. | Roothide manual checklist. |
| System UI actions | 30 | `libactivator.system.homebutton`, `libactivator.system.activate-switcher`, `libactivator.system.power-menu`, `libactivator.system.wallet` | SpringBoard UI controllers, HID generation, system services, power UI, screenshot, Siri, Wallet, orientation, and haptics. | `needs-owner-reference` unless a specific modern path is already known. | Owner-assisted SPI probe and roothide checklist. |
| Lock screen actions | 3 | `libactivator.lockscreen.dismiss`, `libactivator.lockscreen.show`, `libactivator.lockscreen.toggle` | SpringBoard lock/CoverSheet services. | `needs-owner-reference` | Roothide lock-screen checklist. |
| Sharing compose actions | 3 excluded | `libactivator.twitter.compose-tweet`, `libactivator.facebook.compose-post`, `libactivator.weibo.compose-post` | Obsolete social framework integrations and third-party service targeting. | `obsolete`; not staged | No implementation planned. |
| Camera, Clock, Notes, SMS, Mail, Vibration, Watch | 22 | `libactivator.camera.invoke-shutter`, `libactivator.clock.timer`, `libactivator.sms.compose-message`, `libactivator.watch.haptic.tap` | Mix of URL actions, app-specific integrations, modal compose UI, haptics, and watch services. | `implementable` for URL-style actions after validation; otherwise `needs-owner-reference`. | Roothide checklist or owner-assisted SPI probe. |

## Dynamic Listener Families

| Legacy name rule | Category / group | Legacy source | Resource source | Runtime dependency or SPI family | Modern status | First validation |
| --- | --- | --- | --- | --- | --- | --- |
| Application bundle display identifiers | System Applications, User Applications, Web Clips | `LAApplicationListener.x` | 1.9.13 stages many static app glyph directories, but dynamic app metadata still comes from SpringBoard app objects. | SpringBoard application model, app activation, app icons, and special camera/lock-screen handling. | `needs-owner-reference` | Roothide checklist with app launch/suspend scenes. |
| Menu keys from `LAMenuSettings` preferences | Menus | `LAMenuListener.m` | No fixed resource; menu title/items come from preferences. | Settings UI-created menu data and SpringBoard action sheet presentation. | `defer-to-settings-ui` | Settings UI scenario test after menu editor exists. |
| `activatortoggles.<toggle name>` for SBSettings toggle bundles | SBSettings Toggles | `LAToggleListener.m` | External SBSettings toggle bundles and theme icons. | Legacy SBSettings plugin ABI loaded through `dlopen`. | `obsolete` unless a modern compatibility target is explicitly chosen. | Owner decision; no sample package expected. |

## Resource Metadata Semantics

- 1.9.13 event metadata keys include `title`, `description`, `group`, `compatible-modes`, `hidden`, `is-unprotected`, `supports-unlocking-device`, `required-capabilities`, `CoreFoundationVersion`, and Settings controller keys.
- 1.9.13 listener metadata keys include `title`, `description`, `group`, `selector`, `url`, `urls`, `compatible-modes`, `incompatible-events`, `exclusive-assignment-groups`, `needs-powered-display`, `requires-no-touch-events`, `receives-raw-events`, `previews`, `small-icons`, `apply-rounded-corners`, and `tapticType`.
- The rewrite stages built-in metadata through `bundled.plist` and keeps directory-style `Info.plist` lookup only for third-party extension compatibility.
- Support localizations live under `/Library/Activator/*.lproj`; the rewrite keeps its `en.lproj` and `zh-Hans.lproj` resources and also stages reusable 1.9.13 localization directories.
- Runtime lookup must use `jbroot(...)`; implementation code must not use raw `/Library/Activator` paths.

## Settings UI Boundary

Legacy Settings controllers in the package and in `references/master/*SettingsController*`, `Preferences.m`, `Activator.m`, and `LASettingsViewControllers.m` are not part of this built-in runtime inventory. They remain in the Settings UI direction and should be implemented through `libactivatorsettings.dylib`.
