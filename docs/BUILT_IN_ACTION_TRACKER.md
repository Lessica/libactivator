# 内置能力跟踪表

本表跟踪 built-in listeners/actions 与 built-in events 的当前实现状态。它回答“哪些已经完成、哪些只是资源 metadata、哪些被移除或暂缓”，不替代 `BUILT_IN_ROADMAP.md` 的阶段顺序。

## 规则

- `listener` 在 Activator 语义里通常就是 action executor：它是被 assignment 选中的响应器，也是实际完成动作的主体。
- 同一个 listener class 可以注册到多个 listener name。name 决定 metadata、标题、分组、URL 或 selector；class 决定 runtime 行为。
- metadata presence 不等于 runtime behavior implemented。只有注册了真实 `LAListener` object 的 name 才能进入 `availableListenerNames` 并处理事件；只有存在 event source hook/adapter 的 event name 才能被真实触发。
- 1.9.13 资源 catalog 是当前内置能力范围的主要依据；旧 master 只用于证明历史承载方式和语义，不用于照搬实现。
- 状态值：`implemented` 表示已有 runtime 行为和测试或真机验证；`implemented-additive` 表示 2.x 为现代语义新增或公开的 name；`metadata-only` 表示当前只保留资源；`blocked` 表示需要 owner 或 SPI 决策；`obsolete` 表示不计划恢复；`out-of-scope` 表示违反当前项目架构约束。

## 资源基线

| Catalog | 1.9.13 资源 | 当前 staged | 差异 |
| --- | ---: | ---: | --- |
| Events | 121 | 123 | 当前在 1.9.13 基线外新增 `libactivator.now-playing.playing`、`libactivator.now-playing.paused` 两个现代 MediaRemote 状态事件。 |
| Static listeners/actions | 117 | 111 | 当前从 1.9.13 移除 12 个已确认失效、废弃或排除项，并新增 6 个 2.x 动作 name。 |

当前 listener staged 移除项：`libactivator.clock.bedtime`、`libactivator.phone.keypad`、`libactivator.settings.brightness`、`libactivator.settings.brightness-and-wallpaper`、`libactivator.settings.equalizer`、`libactivator.settings.facebook`、`libactivator.settings.network`、`libactivator.settings.twitter`、`libactivator.settings.usage`、`libactivator.twitter.compose-tweet`、`libactivator.facebook.compose-post`、`libactivator.weibo.compose-post`。

当前 listener staged 新增项：`libactivator.audio.mute-ringer`、`libactivator.audio.unmute-ringer`、`libactivator.audio.toggle-ringer-mute`、`libactivator.audio.toggle-output-mute`、`libactivator.keyboard.toggle-on-screen-keyboard`、`libactivator.system.hard-respring`。

`libactivator.system.voice-control` 保留历史资源 metadata，但不注册 runtime listener。旧 master 依赖 `SBVoiceControlAlert`，现代 Voice Control 已不再是同一系统 UI，AXSpringBoardServer 只提供打开入口且无法复刻旧的 cancel/toggle 语义；该 action 标记为 `obsolete`，当前无替代方案。

## 资源 metadata key 交叉比对

本节只记录 Events / Listeners resource 中出现的 metadata key。1.9.13 与当前 staged resource 的 key set 相同，差异只在各 key 覆盖的 name 数量；下表覆盖数量按当前 staged resource 统计。Settings UI 专属 key 会列出含义，但不计入 runtime 未完成项；这里的“当前状态”指 `libactivator` core、SpringBoard runtime 或 built-in listener/event source 是否已经消费该 key 的语义。

### Events keys

当前 staged event resource 共 123 个 event name，包含 12 类 key。

| Key | staged 覆盖 | 作用 | 当前状态 |
| --- | ---: | --- | --- |
| `title` | 123 | event 的本地化标题 fallback。 | `implemented`：`LADefaultEventDataSource` / `LAResourceManager` 已作为 metadata fallback 暴露。 |
| `description` | 123 | event 的本地化说明 fallback。 | `implemented`：已作为 metadata fallback 暴露。 |
| `group` | 123 | event 在列表中的分组。 | `implemented`：已作为 metadata fallback 暴露；排序/展示属于 Settings UI。 |
| `CoreFoundationVersion` | 59 | 按 CoreFoundation 版本过滤 resource。旧资源用它压制不适用 iOS 版本的 event，例如部分 button、edge、watch、network、lock screen clock、multi-touch event。 | `implemented`：`LAResourceManager resourceInfoDictionaryIsCompatible:` 已过滤。 |
| `required-capabilities` | 23 | 按设备能力过滤 event，当前用于 `ipad`、`touch-id`、`SupportsForceTouch`、`fake-home-button`、`real-home-button`、`watch-companion`。 | `implemented`：resource 层已通过 MobileGestalt/HomeButtonType 过滤；对应 runtime source 仍取决于 event family 是否已实现。 |
| `compatible-modes` | 22 | 限定 event 可分配/可触发的 mode，例如 lock/unlock、multi-touch、icon flick、SpringBoard pinch、lock screen clock。 | `implemented`：`LADefaultEventDataSource` 和 dispatch/assignment 路径已消费。 |
| `hidden` | 8 | 隐藏侧边细分 slide-in event，旧 UI 中通常不直接展示这些细分项。 | `implemented`：Public API / IPC 可查询；具体隐藏展示属于 Settings UI。 |
| `is-unprotected` | 12 | 标记 status bar event 可在旧 API protection 语义下豁免保护。1.9.4 changelog 提到 “Protect access to Activator APIs with a prompt dialog”，该 key 属于这套安全展示/授权语义的一部分。 | `partial`：metadata/API 已暴露，但当前项目尚未实现旧版 API protection prompt 与 unprotected 豁免体系。 |
| `supports-unlocking-device` | 8 | 标记 lock screen 下是否允许 unlock-to-send；当前资源中的值均为 `0`，很可能用于排除 `device.locked`、Touch ID、single menu press 等事件，而不是声明唯一可解锁事件。changelog 多次提到自动解锁/锁屏触发动作，1.9.13 又提到 iOS 12+ lock screen app activation unlock sequence。 | `partial`：当前实现了 callback-only unlock-to-send compatibility，但不实现 passcode submit 或完整主动解锁流程；当前 fallback 默认 `NO`，还需要确认 1.9.13 是否是“默认允许、key=0 排除”的语义。 |
| `settings-view-controller-bundle` | 44 | event configuration controller 所在 bundle。 | `settings-ui-only`：Settings UI 尚未实现，本轮不计入 runtime 欠账。 |
| `settings-view-controller-class` | 44 | event configuration controller class。 | `settings-ui-only`：Settings UI 尚未实现，本轮不计入 runtime 欠账。 |
| `settings-view-controller-CoreFoundationVersion` | 20 | configuration controller 的 iOS 版本门槛。 | `settings-ui-only`：Settings UI 尚未实现，本轮不计入 runtime 欠账。 |

Events key 层面的非 Settings UI 未完成项只有两个：`is-unprotected` 的 API protection/unprotected 完整语义，以及 `supports-unlocking-device` 对应的完整主动解锁流程。其余 key 要么已经由 core/resource layer 消费，要么只是 resource 展示信息；未实现的具体 event source 已在“阶段 4：events 未完成交叉比对”中按 event name 归类。

### Listeners keys

当前 staged listener/action resource 共 111 个 static listener/action name，包含 15 类 key。

| Key | staged 覆盖 | 作用 | 当前状态 |
| --- | ---: | --- | --- |
| `title` | 111 | listener/action 的本地化标题 fallback。 | `implemented`：`LAListenerFallbacks` / `LAResourceManager` 已作为 metadata fallback 暴露。 |
| `description` | 111 | listener/action 的本地化说明 fallback。 | `implemented`：已作为 metadata fallback 暴露。 |
| `group` | 109 | listener/action 分组。 | `implemented`：已作为 metadata fallback 暴露；排序/展示属于 Settings UI。 |
| `selector` | 111 | 旧 built-in action dispatcher 的 selector name，也作为当前实现的 metadata gate。 | `partial-by-name`：已实现 listener family 会校验 selector metadata；未实现 selector 对应的 blocked/out-of-scope action 已在阶段 3 表中逐项列出。 |
| `url` | 40 | 单一 URL action 入口。 | `implemented`：`LATURLActionListener` 已读取并提交 `LSApplicationWorkspace openSensitiveURL:withOptions:error:`。 |
| `urls` | 4 | 按 CoreFoundation 版本选择 URL action 入口。 | `implemented`：`LATURLActionListener` 已按阈值选择候选 URL。 |
| `compatible-modes` | 57 | 限定 listener 可在什么 mode 中作为 assignment target 或 receive target。 | `implemented`：dispatch engine 和 Public API 已消费。 |
| `incompatible-events` | 15 | 禁止特定 listener 与特定 event 组合，例如防止 unlock event 触发危险动作、button event 递归触发 virtual button。changelog 早期明确提到 block dangerous actions from device unlocked event、events incompatible with automatic unlocking。 | `implemented`：dispatch/compatibility 查询已消费；blocked listener 本身未注册时该 key 暂不可被真实触发。 |
| `exclusive-assignment-groups` | 104 | 多 action assignment 的互斥组，例如 `modal-ui`、`application-launch`、`media-playback`、`volume-change`、`lock-screen`、`virtual-button`、`orientation`。 | `implemented-api`：core 已提供 `exclusiveAssignmentGroupsForListenerName:` 和 `listenerNamesAreMutuallyCompatible:`；真正阻止 UI 中选择冲突 action 属于 Settings UI。 |
| `needs-powered-display` | 25 | 控制熄屏时是否延迟/跳过 listener。1.9.13 changelog 特别提到 reset ringer switch action 不应要求亮屏；当前 2.x 新增 ringer mute/unmute/toggle 也显式不要求亮屏。 | `implemented`：dispatch engine 已根据 runtime screen state gate listener。 |
| `requires-no-touch-events` | 5 | 触摸活跃时延迟投递 listener，changelog 明确提到新增该 info key 以便 action 等待触摸结束。 | `implemented`：dispatch core 已实现 no-touch deferral，tweak runtime 提供 touch state。 |
| `receives-raw-events` | 1 | 让 listener 接收原始 event 以实现旧 `back` action 这类依赖当前 App/UIKit 上下文的行为。 | `out-of-scope-gap`：唯一使用者是 `libactivator.system.back`；当前项目不注入用户 App，不实现 old back/local back raw-event 语义。 |
| `previews` | 5 | 允许 action 在配置/菜单中 preview。1.9.7 changelog 提到 listeners 可设置 `previews=1` 自动支持 preview，且 vibration actions 可预览。 | `partial`：core preview dispatch API 已存在，但 built-in `system.vibrate` 当前没有 preview 行为；watch haptic action 尚未实现。 |
| `tapticType` | 3 | Taptic action 类型，当前值映射 `flick=0` / `tap=1` / `quirk=2`。1.9.7 增加 taptic engine actions，1.9.13 改为 iOS 13 public haptics。 | `implemented`：`libactivator.system.haptic.*` 已按 1.9.13 解混淆语义映射到 UIKit feedback generator。 |
| `small-icons` | 66 | 小图标候选路径，按 jbroot 优先、原路径 fallback。 | `implemented`：resource manager / listener metadata cache 已解析；展示属于 Settings UI。 |
| `apply-rounded-corners` | 65 | 旧 UI 对图标做圆角处理的展示 hint。 | `settings-ui-only`：不影响 runtime，本轮不计入欠账。 |

Listeners key 层面的非 Settings UI 未完成项是：`selector` 覆盖的 blocked/out-of-scope action name、`receives-raw-events` 的 old back raw-event 语义、`previews` 对 built-in vibration / watch haptic preview 的实际动作支持。`exclusive-assignment-groups` 的核心查询已实现，配置 UI 中的冲突阻止属于后续 Settings UI，不作为 runtime 欠账。

## 已完成能力

这些条目已降级为完成状态；后续只在回归、重构或 owner 明确要求时重新打开。

| Family | 承载实体 | 已实现 name | 说明 |
| --- | --- | --- | --- |
| No-op | `LATNothingListener` | `libactivator.system.nothing` | 已注册并在 dispatch 后设置 `event.handled = YES`。 |
| URL actions | `LATURLActionListener` | `libactivator.clock.alarm`、`libactivator.clock.stopwatch`、`libactivator.clock.timer`、`libactivator.clock.world-clock`、`libactivator.settings.about`、`libactivator.settings.accessibility`、`libactivator.settings.auto-lock`、`libactivator.settings.background-app-refresh`、`libactivator.settings.battery`、`libactivator.settings.bluetooth`、`libactivator.settings.carplay`、`libactivator.settings.cellular`、`libactivator.settings.control-center`、`libactivator.settings.date-time`、`libactivator.settings.display`、`libactivator.settings.do-not-disturb`、`libactivator.settings.facetime`、`libactivator.settings.game-center`、`libactivator.settings.general`、`libactivator.settings.handoff`、`libactivator.settings.icloud`、`libactivator.settings.international`、`libactivator.settings.keyboard`、`libactivator.settings.location-services`、`libactivator.settings.mail`、`libactivator.settings.managed-configuration`、`libactivator.settings.maps`、`libactivator.settings.messages`、`libactivator.settings.music`、`libactivator.settings.notes`、`libactivator.settings.notifications`、`libactivator.settings.passcode`、`libactivator.settings.phone`、`libactivator.settings.photos`、`libactivator.settings.privacy`、`libactivator.settings.reminders`、`libactivator.settings.safari`、`libactivator.settings.sounds`、`libactivator.settings.store`、`libactivator.settings.tethering`、`libactivator.settings.virtual-assistant`、`libactivator.settings.vpn`、`libactivator.settings.wallpaper`、`libactivator.settings.wifi`、`libactivator.phone.favorites`、`libactivator.phone.recents`、`libactivator.phone.contacts`、`libactivator.phone.voicemail` | 44 个 Clock / Settings URL action 与 4 个 Phone tab hardcoded URL action 已实现。真实打开通过 `LSApplicationWorkspace openSensitiveURL:withOptions:error:` 在非主队列提交。 |
| Hardware actions | `LATHardwareActionListener` | `libactivator.ipod.toggle-playback`、`libactivator.ipod.pause-playback`、`libactivator.ipod.resume-playback`、`libactivator.ipod.next-track`、`libactivator.ipod.previous-track`、`libactivator.audio.increase-volume`、`libactivator.audio.decrease-volume`、`libactivator.audio.toggle-output-mute`、`libactivator.screen.brightness.increase`、`libactivator.screen.brightness.decrease`、`libactivator.system.homebutton`、`libactivator.system.sleepbutton`、`libactivator.keyboard.toggle-on-screen-keyboard`、`libactivator.system.take-screenshot`、`libactivator.system.spotlight`、`libactivator.system.vibrate` | HID Consumer page 动作统一通过 `LATHIDEventSender` 提交，并使用 synthetic `senderID` 防止 HID event source 回流识别；vibrate 使用 `AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)`。 |
| System actions | `LATSystemActionListener` | `libactivator.audio.show-volume-bar`、`libactivator.audio.launch-playing-app`、`libactivator.audio.reset-ringer-state`、`libactivator.audio.mute-ringer`、`libactivator.audio.unmute-ringer`、`libactivator.audio.toggle-ringer-mute`、`libactivator.system.first-springboard-page`、`libactivator.lockscreen.show`、`libactivator.lockscreen.dismiss`、`libactivator.lockscreen.toggle`、`libactivator.system.activate-control-center`、`libactivator.system.activate-notification-center`、`libactivator.system.activate-reachability`、`libactivator.system.activate-switcher`、`libactivator.system.edit-screenshot`、`libactivator.system.power-menu`、`libactivator.system.respring`、`libactivator.system.hard-respring`、`libactivator.system.safemode`、`libactivator.system.powerdown`、`libactivator.system.reboot`、`libactivator.system.haptic.flick`、`libactivator.system.haptic.tap`、`libactivator.system.haptic.quirk`、`libactivator.system.rotate.landscape-left`、`libactivator.system.rotate.landscape-right`、`libactivator.system.rotate.portrait`、`libactivator.system.rotate.portrait-upside-down`、`libactivator.system.virtual-assistant`、`libactivator.system.wallet` | Volume HUD、now-playing application launch、ringer state sync、ringer mute/unmute/toggle、SBS first SpringBoard page，以及已通过真机验证、trace 确认或 AXSpringBoardServer / AXPISystemActionHelper SPI 补齐的锁屏、切换器、电源菜单、系统 UI、haptics、rotation、截图编辑、respring/reboot/powerdown/safemode 动作已注册。ringer mute/unmute/toggle 首选 `AXPISystemActionHelper toggleRingerSwitch:` / `isRingerSwitchOn`，原 `SBRingerControl` 路径保留 fallback。`activate-reachability` 现在在主队列调用 `AXSpringBoardServerHelper isReachabilityActive` / `setReachabilityActive:`，保持旧 Activator toggle 语义。`system.haptic.flick` / `tap` / `quirk` 分别映射 `UIImpactFeedbackStyleHeavy`、`UIImpactFeedbackStyleLight`、`UINotificationFeedbackTypeSuccess`。`hard-respring` 是本轮新增 additive 高风险动作，真实副作用只通过真机手工验证，不进入 stable fake path。 |
| Telephony actions | `LATTelephonyActionListener` | `libactivator.phone.answer-call`、`libactivator.phone.disconnect-call` | Call control 使用 CoreTelephony，并持有 `CTTelephonyCenter` observer 以维持 call state。`disconnect-call` metadata selector 已规范化为 `disconnectCall`。 |
| Dynamic application listeners | `LATApplicationActionListener` + `LATApplicationListenerProvider` | 动态注册当前设备可见 App display identifier | 该 family 不以 1.9.13 bundled static app glyph 目录作为固定 runtime name 清单；它枚举现代 SpringBoard app model，WebClip 不注册，`com.apple.camera` 锁屏 special case 已实现。 |

## 已完成事件

当前已实现 event runtime 共 90 个，其中 88 个来自 1.9.13 event 资源，2 个为 2.x additive now-playing 状态事件。

| Family | 已实现 event names | 说明 |
| --- | --- | --- |
| Device / power / headset / media / network 状态 | `libactivator.device.locked`、`libactivator.device.unlocked`、`libactivator.power.connected`、`libactivator.power.disconnected`、`libactivator.headset.connected`、`libactivator.headset.disconnected`、`libactivator.now-playing.info-changed`、`libactivator.now-playing.playing`、`libactivator.now-playing.paused`、`libactivator.network.joined-wifi`、`libactivator.network.left-wifi` | 阶段 3 第一批低风险状态/通知型 event source 已收口。`now-playing.playing` / `paused` 不在 1.9.13 资源中，是 2.x additive。 |
| Hardware button events | `libactivator.volume.up.press`、`libactivator.volume.down.press`、`libactivator.volume.both.press`、`libactivator.volume.up.press.with-menu`、`libactivator.volume.down.press.with-menu`、`libactivator.volume.up.hold.short`、`libactivator.volume.down.hold.short`、`libactivator.volume.up-down`、`libactivator.volume.down-up`、`libactivator.volume.mute`、`libactivator.volume.unmute`、`libactivator.volume.toggle-mute-twice`、`libactivator.menu.press.single`、`libactivator.menu.press.double`、`libactivator.menu.press.triple`、`libactivator.menu.hold.short`、`libactivator.menu.hold.long`、`libactivator.lock.hold.short`、`libactivator.lock.hold.long`、`libactivator.lock.press.double`、`libactivator.lock.press.triple`、`libactivator.lock.press.with-menu` | 通过 SpringBoard `__handleHIDEvent*` 观察 Consumer / Telephony HID；当前不拦截默认系统行为。 |
| Status bar gestures | `libactivator.statusbar.tap.single`、`libactivator.statusbar.tap.single.left`、`libactivator.statusbar.tap.single.right`、`libactivator.statusbar.tap.double`、`libactivator.statusbar.tap.double.left`、`libactivator.statusbar.tap.double.right`、`libactivator.statusbar.hold`、`libactivator.statusbar.hold.left`、`libactivator.statusbar.hold.right`、`libactivator.statusbar.swipe.left`、`libactivator.statusbar.swipe.right`、`libactivator.statusbar.swipe.down` | `UIStatusBar_Modern touches*` hook，主屏幕、锁屏、前台 App 真机验收通过；当前不拦截 scroll-to-top 或系统顶部下拉默认行为。 |
| Slide-in / edge gestures | `libactivator.slide-in.top-left`、`libactivator.statusbar.swipe.down`、`libactivator.slide-in.top-right`、`libactivator.slide-in.bottom-left`、`libactivator.slide-in.bottom`、`libactivator.slide-in.bottom-right`、`libactivator.slide-in.left-top`、`libactivator.slide-in.left`、`libactivator.slide-in.left-bottom`、`libactivator.slide-in.right-top`、`libactivator.slide-in.right`、`libactivator.slide-in.right-bottom`、`libactivator.two-finger-slide-in.top-left`、`libactivator.two-finger-slide-in.top`、`libactivator.two-finger-slide-in.top-right`、`libactivator.two-finger-slide-in.bottom-left`、`libactivator.two-finger-slide-in.bottom`、`libactivator.two-finger-slide-in.bottom-right`、`libactivator.two-finger-slide-in.left-top`、`libactivator.two-finger-slide-in.left`、`libactivator.two-finger-slide-in.left-bottom`、`libactivator.two-finger-slide-in.right-top`、`libactivator.two-finger-slide-in.right`、`libactivator.two-finger-slide-in.right-bottom` | `_UISystemGestureWindow sendEvent:` / `UIEvent.allTouches` snapshot 纯分类。`LAEventNameSlideInFromTop` 是 public alias，实际 runtime name 为 `libactivator.statusbar.swipe.down`；1.9.13 资源中没有独立 `libactivator.slide-in.top`。 |
| Drag-along / drag-off edge gestures | `libactivator.drag-along.screen-bottom.right-to-left`、`libactivator.drag-along.screen-bottom.left-to-right`、`libactivator.drag-along.screen-left.top-to-bottom`、`libactivator.drag-along.screen-left.bottom-to-top`、`libactivator.drag-along.screen-right.top-to-bottom`、`libactivator.drag-along.screen-right.bottom-to-top`、`libactivator.drag-off.bottom`、`libactivator.drag-off.left`、`libactivator.drag-off.right`、`libactivator.drag-off.top` | 阈值按 1.9.13 解混淆 `ActivatorSpringBoard` 逆向结果对齐；真机 dispatch 验收通过。 |
| Fingerprint sensor events | `libactivator.fingerprint-sensor.press.single`、`libactivator.fingerprint-sensor.press.twice`、`libactivator.fingerprint-sensor.hold`、`libactivator.fingerprint-sensor.hold-long`、`libactivator.fingerprint-sensor.press.single.with-slide-in`、`libactivator.fingerprint-sensor.press.single.with-hold` | Touch ID HID probe 接入 `LATFingerprintSensorEventSource`；只在 `touch-id` capability 通过时注册；端到端真机验收通过。 |
| Force touch events | `libactivator.force-touch.statusbar`、`libactivator.force-touch.screen-left`、`libactivator.force-touch.screen-right`、`libactivator.force-touch.screen-bottom-left`、`libactivator.force-touch.screen-bottom`、`libactivator.force-touch.screen-bottom-right` | `_UISystemGestureWindow sendEvent:` / `UITouch.force` 数据路径；只在 `SupportsForceTouch` capability 通过时注册；六组真机验收通过。 |

## 阶段 3：listeners/actions 未完成交叉比对

1.9.13 static listener/action 资源共 117 个。当前已实现 static listener name 共 97 个，其中 91 个来自 1.9.13，6 个是 2.x additive name。未实现的 1.9.13 listener/action name 共 26 个，按处理状态归类如下；2.x additive 暂缓项单独列出。

| 分类 | Listener names | 当前状态 | 说明 |
| --- | --- | --- | --- |
| 已移除 / obsolete URL 或旧服务 | `libactivator.clock.bedtime`、`libactivator.phone.keypad`、`libactivator.settings.brightness`、`libactivator.settings.brightness-and-wallpaper`、`libactivator.settings.equalizer`、`libactivator.settings.facebook`、`libactivator.settings.network`、`libactivator.settings.twitter`、`libactivator.settings.usage`、`libactivator.facebook.compose-post`、`libactivator.twitter.compose-tweet`、`libactivator.weibo.compose-post` | `obsolete` | 已从当前 staged listener resource 移除；其中 Settings/Clock/Phone URL 经真机验证失效、重复或打开错误页面，旧 social compose 服务不作为内置 action 恢复。 |
| 旧 Audio modal | `libactivator.ipod.music-controls`、`libactivator.system.show-now-playing-bar` | `obsolete` | 旧 `SBNowPlayingAlertItem` / Now Playing Bar modal 在现代 iOS 没有等价 UI，不作为当前 listener family 恢复，也不映射到 Control Center 的 Now Playing 模块。 |
| 应用 compose / camera shutter | `libactivator.mail.compose-message`、`libactivator.sms.compose-message`、`libactivator.notes.compose-note`、`libactivator.camera.invoke-shutter` | `blocked` | 涉及目标 App 或系统相机状态，需要逐项确认现代 URL/SPI、前台/锁屏语义和失败路径。 |
| Modal/system UI actions | `libactivator.system.clear-switcher`、`libactivator.system.previous-app`、`libactivator.keyboard.dictation` | `blocked` | 需要 Frida/IDA probe 对应现代 SpringBoard / keyboard service 入口，不把旧 selector 直接映射到现代 UI。`clear-switcher` 的首轮现代路径真机验证无效，当前不注册 runtime listener，后续重新 probe。 |
| Power / lock residual actions | `libactivator.system.lock-and-wipe-credentials` | `blocked` | 1.9.13 语义是锁屏并强制 biometric lockout，不是删除 passcode 或清除系统凭据；首轮 `SBCoverSheetPresentationManager lockUIFromSource:withOptions:` 路径真机验证无效，当前不注册 runtime listener。 |
| 2.x additive deferred actions | `libactivator.system.soft-reboot` | `blocked` | Dopamine `jbctl reboot_userspace` 的 `reboot3(RB2_USERREBOOT)` 路径在 SpringBoard 进程内无法执行；当前从 staged resource 和 runtime allowlist 移除，后续需要非 SpringBoard helper 或合适 privileged execution path。 |
| Watch haptics | `libactivator.watch.haptic.tap` | `blocked` | 涉及 Watch 能力与设备差异；不作为默认 listener 主线。 |
| App 注入依赖 | `libactivator.system.local-back`、`libactivator.system.back` | `out-of-scope` | 1.9.13 旧语义依赖 `com.apple.UIKit` filter 注入用户 App 进程执行 local back；本项目不注入用户 App，因此只保留资源/逆向记录，不实现。 |

## 阶段 4：events 未完成交叉比对

1.9.13 event 资源共 121 个。当前已实现 runtime event 共 90 个，其中 88 个来自 1.9.13，2 个是 2.x additive。未实现的 1.9.13 event name 共 33 个，按 family 归类如下。

| Family | Event names | 当前状态 | 下一步 |
| --- | --- | --- | --- |
| Multi-touch gesture | `libactivator.three-finger.tap`、`libactivator.three-finger.pinch`、`libactivator.three-finger.spread`、`libactivator.four-finger.tap`、`libactivator.four-finger.pinch`、`libactivator.four-finger.spread`、`libactivator.five-finger.tap`、`libactivator.five-finger.pinch`、`libactivator.five-finger.spread` | `candidate` | 下一主线。先 probe SpringBoard 或系统手势层能否在不注入用户 App 的前提下观察多指触摸，再决定 recognizer/classifier 与 assignment-aware gate 位置。 |
| SpringBoard / icon gestures | `libactivator.springboard.pinch`、`libactivator.springboard.spread`、`libactivator.icon.flick.up`、`libactivator.icon.flick.down`、`libactivator.icon.flick.left`、`libactivator.icon.flick.right` | `candidate` | 只针对 SpringBoard UI 层实现；需确认现代 Home Screen / icon view hook 点。 |
| Lock screen clock gestures | `libactivator.lockscreen.clock.double-tap`、`libactivator.lockscreen.clock.tap-hold`、`libactivator.lockscreen.clock.swipe-left`、`libactivator.lockscreen.clock.swipe-right`、`libactivator.lockscreen.clock.swipe-down` | `blocked` | CoverSheet/lock screen clock 视图结构与 passcode/notification/camera 入口强相关，需单独 probe。 |
| Headset button | `libactivator.headset-button.press.single`、`libactivator.headset-button.hold.short` | `blocked` | 已实现 headset connected/disconnected，但线控按钮需要确认现代音频 route / HID / MediaRemote 信号来源。 |
| Motion | `libactivator.motion.shake` | `blocked` | 需要确认是否在 SpringBoard 进程内可靠接入 motion shake，不能为了该事件注入用户 App。 |
| Volume HUD tap | `libactivator.volume.display-tap` | `metadata-only` | 依赖音量 HUD 触摸，不属于 HID 按键热路径；后续若实现应作为独立 HUD/UI hook。 |
| Gesture bar | `libactivator.gesture-bar.double-tap` | `blocked` | 现代 home indicator / gesture bar 设备相关，需按设备能力和 iOS 版本 probe。 |
| Scheduled | `libactivator.scheduled.sunrise`、`libactivator.scheduled.sunset` | `metadata-only` | 需要定位旧实现语义和现代定位/日出日落调度来源；当前不作为阶段 4 主线。 |
| Car / watch / smart cover | `libactivator.car.connected`、`libactivator.car.disconnected`、`libactivator.watch.connected`、`libactivator.watch.disconnected`、`libactivator.clamshell.open`、`libactivator.clamshell.close` | `metadata-only` | 依赖外设、设备能力或私有服务；先保留资源，不用 metadata presence 推断可用性。 |

## 遗留问题

- Handled-default interception 尚未设计。当前 hardware button、status bar、edge gesture、force touch 都只负责识别和 dispatch，不根据 `event.handled` 吞掉系统默认行为。后续如果恢复拦截，应单独设计 hook 返回值、原始事件转发、fallback 重发和 `event.handled` 回传路径。
- 物理按键与 status bar scroll-to-top 是当前最明确可能需要拦截层的 family；edge gesture / force touch 当前继续保持 no-intercept 语义。
- Fingerprint sensor 遗留 1.9.13 changelog 项：“Suppress Touch ID events while showing an auth alert in Touch ID-enabled apps”。当前尚未识别现代 LocalAuthentication / biometric auth UI 状态，不做该 suppression。
- `LAEventNameSlideInFromTop` 只是 public alias 到 `LAEventNameStatusBarSwipeDown`；不要新增独立 `libactivator.slide-in.top` 资源或 runtime name。
- 高成本触摸 family 应使用 assignment-aware runtime gate；当前已接入 `EdgeGesture`、`ForceTouch`、`StatusBar`，`MultiTouch` 保留 family bit 但尚未实现 recognizer。
