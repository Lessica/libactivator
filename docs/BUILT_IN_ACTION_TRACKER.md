# 内置动作跟踪表

本表跟踪 built-in listeners/actions 的具体实现事项。它回答“是什么、为什么要做、依据来自哪里、当前状态如何”，不替代 `BUILT_IN_ROADMAP.md` 的阶段顺序。

## 规则

- `listener` 在 Activator 语义里通常就是 action executor：它是被 assignment 选中的响应器，也是实际完成动作的主体。
- 同一个 listener class 可以注册到多个 listener name。name 决定元数据、标题、分组、URL 或 selector；class 决定运行时行为。
- metadata presence 不等于已实现。只有注册了真实 `LAListener` object 的 name 才能进入 `availableListenerNames` 并处理事件。
- 1.9.13 资源 catalog 是当前内置动作范围的主要依据；旧 master 只用于证明历史承载方式和语义，不用于照搬实现。
- 状态值：`metadata-only` 表示只有资源；`candidate` 表示可进入当前阶段评估；`in-progress` 表示正在实现；`implemented` 表示已有行为和测试；`blocked` 表示需要 owner 或 SPI 决策；`obsolete` 表示不计划恢复；`out-of-scope` 表示违反当前项目架构约束。

## 阶段结论

URL actions / listener family 已完成。当前 `LATURLActionListener` 注册 44 个带 `url` 或 `urls` metadata 的 Clock / Settings URL action，并承载 4 个 hardcoded Phone tab URL action。Phone tab action 没有 `url` metadata，仍通过 selector metadata gate 校验资源形状，runtime URL 由代码 allowlist 提供。8 个经真机验证失效、重复或只打开错误页面的旧 URL action 已从资源和 allowlist 移除：`libactivator.clock.bedtime`、`libactivator.settings.brightness`、`libactivator.settings.brightness-and-wallpaper`、`libactivator.settings.equalizer`、`libactivator.settings.facebook`、`libactivator.settings.network`、`libactivator.settings.twitter`、`libactivator.settings.usage`。`libactivator.phone.keypad` 也已确认在现代 iOS 上失效且暂无替代 URL，当前从资源和 allowlist 移除并标记为 obsolete。

URL family 的实现边界已固定：注册 name 仍由代码 allowlist 决定；metadata lookup 同时支持 `Listeners/bundled.plist` 和目录式 `Listeners/<name>/Info.plist`；真实打开通过 `LSApplicationWorkspace openSensitiveURL:withOptions:error:` 在非主队列提交，`event.handled = YES` 表示 action request 已被 listener 接受并提交，不表示目标 App 已完成打开。这与旧 master 中 `applicationOpenURL:publicURLsOnly:` 后立即返回 `YES` 的语义一致。

Hardware actions / listener family 已从旧 Media family 中拆出。当前 `LATHardwareActionListener` 承载 15 个 HID Consumer page 播放、音量、输出静音、亮度、Home、Sleep、屏幕键盘、截图、Spotlight 硬件键，以及 `libactivator.system.vibrate` 的硬件振动反馈。HID 动作统一通过 tweak-side `LATHIDEventSender` 使用 `IOHIDEventCreateKeyboardEvent` 与 `IOHIDEventSystemClientDispatchEvent` 提交，并写入高位 `senderID`；HID event source 会忽略 `senderID` 最高位为 1 的事件，避免 action 发出的 HID 被内置 event source 再次识别；vibrate 使用 `AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)`；`event.handled = YES` 表示 action request 已被 listener 接受并提交，不表示系统 UI 或目标应用已经完成状态变化。`SBScreenShotter` 已确认在现代 iOS 不可用，因此截图不走旧 master 的 `SBScreenShotter saveScreenshot:` 路径。

System actions / listener family 已用于承载非 URL、非 HID、但低风险且接口明确的系统服务动作。当前 `LATSystemActionListener` 包含 volume HUD、now-playing application launch、ringer state sync、ringer mute/unmute/toggle、SBS first SpringBoard page。实现边界已固定：注册 name 仍由代码 allowlist 决定；metadata lookup 用于 selector metadata gate；volume/ringer 动作通过 tweak hook 缓存在 `LATBuiltInRegistry` 中的 `SBVolumeControl` / `SBRingerControl` 原进程对象执行；now-playing application launch 通过 MediaRemote 解析当前播放应用后走统一 `LATApplicationLauncher`，亮屏锁屏下会请求解锁启动，熄屏仍由 `needs-powered-display` dispatch gate 拦截；ringer reset 按 1.9.13 旧实现通过 `BKSHIDServicesGetRingerState` 与 SpringBoard `-_updateRingerState:withVisuals:updatePreferenceRegister:` 同步；first-page 使用 `SBSServiceFacilityClient` checkout `SBSSystemServiceClient` 后调用 `resetToHomeScreenAnimated:`。

Telephony actions / listener family 现在只承载通话控制。`LATTelephonyActionListener` 包含 2 个 call control 动作：`answer-call` 和 `disconnect-call`；Phone tab URL 已按执行机制并入 `LATURLActionListener`。Call control 动作参考 `TRAppIntentXpcServiceConnection.mm` 中已验证的 CoreTelephony 路径，tweak 使用项目内私有 `CTCall.h` 副本并链接 `CoreTelephony.framework`，在主队列异步执行通话控制。`libactivator.phone.disconnect-call` 的 selector metadata 已从旧资源误写的 `answerCall` 规范化为 `disconnectCall`。`libactivator.phone.answer-call` 曾出现首个来电可接、后续来电不可接但可挂断的现象；原因判断为 answer 依赖当前 incoming `CTCallRef`，而参考项目还通过 `CTTelephonyCenter` 持续订阅 call status / identification change 来维护进程内 CoreTelephony 状态，当前实现已补齐这个 observer。`event.handled = YES` 表示 telephony listener 已消费请求，不表示电话状态已完成变化。

Dynamic application listeners 已实现。`LATApplicationListenerProvider` 使用 `LSApplicationWorkspace` / `LSApplicationProxy` 枚举可见 System / User 应用并注册 bundle/display identifier listener；app 列表变化通过 Darwin notification `com.apple.LaunchServices.ApplicationsChanged` 触发，并用防抖策略延迟刷新。LaunchServices snapshot 构建放在后台 utility queue，main queue 只应用 added / removed listener 变更，不全量重建其他 listener family。refresh 阶段只保留注册所需的最小 descriptor，不读取 bundle `Info.plist`、不计算 display name、也不按 display name 排序；动态 title、description、group metadata 由 `LATApplicationActionListener` 在 metadata 查询时懒加载。实际启动统一交给 `LATApplicationLauncher`，通过 `SBSLaunchApplicationWithIdentifierAndLaunchOptions` 在专用非主队列提交。`com.apple.camera` 是唯一当前已实现的动态应用 special case：锁屏模式下不请求解锁打开 Camera App，而是通过 `CSCoverSheetViewController -activateCameraViewAnimated:sendingActions:completion:` 在主队列打开锁屏相机；屏幕未点亮时通过 tweak-side `LATRuntimeStateSource` 发送 Power HID 短按，等它 feed 的 screen-on runtime state 后再提交锁屏相机切换；该 SPI 不可用时退回普通解锁启动。`event.handled = YES` 表示 launch request 已被 listener 接受并提交，不表示目标 App 已完成前台切换。

当前 built-in actions / listeners 的低风险实施面已经收束；阶段 3 的低风险状态/通知型 event source 也已完成第一批。listener 划分仍按执行机制决定：URL action 归 `LATURLActionListener`，HID Consumer action 归 `LATHardwareActionListener`，SpringBoard/system-service action 归 `LATSystemActionListener`，通话控制归 `LATTelephonyActionListener`，动态 App 归 `LATApplicationActionListener`；event acquisition 划分为独立 adapter：锁定状态归 `LATLockStateEventSource`，电源状态归 `LATPowerStateEventSource`，耳机/媒体 route 与 now-playing 状态归 `LATMediaEventSource`，网络状态归 `LATNetworkEventSource`。后续不要把 event acquisition adapter 或 Settings UI 逻辑塞回现有 action listener。

## 已处理完成项

现有 static built-in actions / listeners 清单已经处理完毕，详细逐项验证记录不再保留在 tracker 中；后续追溯具体实现时以代码、测试 suite、`LEGACY_REVERSE_ENGINEERING.md` 和 git 历史为准。

| Family | 承载实体 | 状态 | 说明 |
| --- | --- | --- | --- |
| No-op | `LATNothingListener` | `implemented` | `libactivator.system.nothing` 已注册并覆盖 dispatch 后 `event.handled = YES`。 |
| URL actions | `LATURLActionListener` | `implemented` | Clock、Settings、Phone tab URL actions 已按 allowlist 注册；真机无效或重复项已从资源和 allowlist 移除。 |
| Hardware actions | `LATHardwareActionListener` | `implemented` | HID Consumer 播放、音量、输出静音、亮度、Home、Sleep、屏幕键盘、截图、Spotlight，以及 `AudioServices` vibrate 已实现并完成手工验证。 |
| System actions | `LATSystemActionListener` | `implemented` | Volume HUD、now-playing application launch、ringer state sync、ringer mute/unmute/toggle、SBS first SpringBoard page 已实现。 |
| Phone tab URL actions | `LATURLActionListener` | `implemented` | Favorites、Recents、Contacts、Voicemail 已实现；Keypad 已确认失效并移除。 |
| Telephony actions | `LATTelephonyActionListener` | `implemented` | Answer / Disconnect call 已实现；answer path 持有 `CTTelephonyCenter` observer 以维持 CoreTelephony call state。 |
| Dynamic application listeners | `LATApplicationActionListener` + `LATApplicationListenerProvider` | `implemented` | 可见 System / User App listener 已动态注册；通过 `com.apple.LaunchServices.ApplicationsChanged` 刷新动态列表；WebClip 不注册。 |
| Device locked / unlocked events | `LATLockStateEventSource` | `implemented` | `com.apple.springboard.lockstate` Darwin notification 触发，使用 `SBLockScreenManager isUILocked` 读取边沿状态；启动只 seed，不发送事件。 |
| Power connected / disconnected events | `LATPowerStateEventSource` | `implemented` | `UIDeviceBatteryStateDidChangeNotification` 触发，按 `Charging` / `Full` 与 `Unplugged` 边沿发送事件；`Unknown` 忽略。 |
| Headset connected / disconnected events | `LATMediaEventSource` | `implemented` | 监听 MediaRemote route notification、`AVSystemController` route/headset notifications，并用 `AVSystemController_HeadphoneJackIsConnectedAttribute` 读取有线耳机状态；当前语义不覆盖蓝牙耳机、CarPlay 或 AirPods。 |
| Media playback events | `LATMediaEventSource` | `implemented` | `libactivator.now-playing.info-changed` 由 MediaRemote now-playing info notification 触发，收到通知后拉取最新 info 再派发且不做内容去重；`libactivator.now-playing.playing` / `paused` 使用 MediaRemote playback-state notification，启动只 seed，后续按状态边沿派发。 |
| Network joined / left Wi-Fi events | `LATNetworkEventSource` | `implemented` | `SBWiFiManager` hook、`NWPathMonitor` 和旧 SpringBoard Wi-Fi/wake notification 触发状态重读；实际 Wi-Fi SSID 使用 `SBWiFiManager currentNetworkName` 读取；先尝试旧 per-SSID event name，再 fallback 到通用 joined/left event。 |
| Volume / Menu / Sleep button press events | `LATButtonEventSource` | `implemented` | SpringBoard `__handleHIDEvent*` hook 观察 Consumer page power/menu/volume HID keyboard 事件和 Telephony page ringer switch 事件；单键音量按 down/up 边沿在 release 时立即派发 `libactivator.volume.up.press` / `libactivator.volume.down.press`；两个音量键组合在第二个键 down 时派发 `libactivator.volume.both.press`；音量键 + Menu/Home 组合在第二个参与键 down 时派发 `libactivator.volume.up.press.with-menu` / `libactivator.volume.down.press.with-menu`；单个音量键保持 down 超过旧 `kButtonHoldDelay` 0.45 秒时派发 `libactivator.volume.up.hold.short` / `libactivator.volume.down.hold.short`；相反音量键在首个 release 后 0.45 秒窗口内顺序 release 时派发 `libactivator.volume.up-down` / `libactivator.volume.down-up`，且不派发第二个单键 press；同方向快速重复 release 在 0.45 秒窗口内不派发第二个单键 press；静音拨片 HID `0x0b/0x2e` 中 `down=NO` 派发 `libactivator.volume.mute`，`down=YES` 派发 `libactivator.volume.unmute`，两次变化在 1 秒内时额外派发 `libactivator.volume.toggle-mute-twice`；Menu/Home 单击在 release 时派发，若当前 mode 有 double/triple listener 则按旧实现延迟 0.45 秒等待升级；double 在第二次 release 派发，但若有 triple listener 会再等待 0.45 秒，第三次 release 派发 triple，否则 timeout 后派发 double；Menu/Home short hold 在 down 后 0.45 秒派发，long hold 使用 HID 侧 2.5 秒 timer 派发并 abort 已 handled 的 short hold；Sleep/Lock short hold 在 down 后 0.45 秒派发，long hold 使用 HID 侧 2.5 秒 timer 派发并 abort 已 handled 的 short hold；Sleep/Lock double press 只在当前 mode 有 double/triple assignment 时进入 0.45 秒窗口，triple press 使用内部字符串 `libactivator.lock.press.triple`；Sleep/Lock + Menu/Home 在第二个参与键 down 时派发 `libactivator.lock.press.with-menu`；both、with-menu 和 hold 会消费本轮单键 press；不吞掉原始 HID，系统默认行为保持不变。 |
| Status bar gestures | `LATStatusBarEventSource` | `implemented` | SpringBoard 内 hook `UIStatusBar_Modern` 的 `touchesBegan/Moved/Ended/Cancelled:withEvent:`，对每个 status bar view 实例维护独立 session；hold delay 使用旧 `0.5s`，single tap delay 使用旧 `0.33s`，横向/纵向 swipe 阈值分别为 `50pt` / `10pt`，横纵方向按 `deltaX^2 > deltaY^2` 判定；起点 `x < width * 0.25` 派发 left tap/hold/double，`x >= width * 0.75` 派发 right tap/hold/double，中间派发 base tap/hold/double；横向 swipe 派发 `statusbar.swipe.left/right`，向下 swipe 派发历史兼容 `statusbar.swipe.down`；前台 App 状态栏 tap 被系统 scroll-to-top 路径转成 `touchesCancelled` 时，会在短时、未滑动、仍在 bounds 内的窄条件下按 tap/double 处理；touch hook 继续调用原始实现，本阶段不做 handled 后默认行为拦截，也不注入用户 App 进程。已完成真机验收：主屏幕、锁屏和前台 App 场景下 status bar tap / double tap / hold / horizontal swipe / downward swipe 均可观测，前台 App scroll-to-top 与顶部下拉等系统默认行为仍可用。 |
| Top slide / edge gesture events | `LATEdgeGestureEventSource` + `LATEdgeGestureClassifier` | `implemented-dispatch-verified-no-intercept` | SpringBoard 内复用 `_UISystemGestureWindow sendEvent:` hook，把 `UIEvent.allTouches` 转成 touch snapshot 后交给纯分类器；分类成功后提交对应 `LAEvent`，继续调用原始 `_UISystemGestureWindow sendEvent:`，不拦截原始系统手势。分类器覆盖 24 个 slide-in / two-finger-slide-in event name：top-left/top/top-right、bottom-left/bottom/bottom-right、left-top/left/left-bottom、right-top/right/right-bottom 及其双指版本；left/right top/bottom 使用旧实现存在但 public header 未导出的字符串。stable 覆盖验证边缘起点、最小内移距离、单 session 只分类一次、横屏 bottom、非边缘起点不会后续补分类，以及 event source 只在已 start 且分类成功时 dispatch 一次；真机已通过 dispatch 验收，可观察事件计数增长，并完成少量绑定动作测试。 |
| Music controls modal | 无 | `obsolete` | 旧 `SBNowPlayingAlertItem` modal 在现代 iOS 没有等价 UI，不作为当前 listener family 恢复。 |

## 下一阶段建议

### 1. 阶段 3 收口

`device locked / unlocked`、`power connected / disconnected`、`headset connected / disconnected`、`media playback`、`network joined / left Wi-Fi` 已实现并纳入 `BuiltInEventSources` stable 覆盖。阶段 3 当前视为收口完成；不要继续把状态/通知型候选作为主线无限扩大。

剩余状态/通知型候选进入 backlog，只在明确需要时小批量 probe：

- Network source 扩展：`LATNetworkEventSource` 已接入 `NWPathMonitor`，后续如果恢复蓝牙网络、VPN、蜂窝数据或特定网络变化事件，应继续放在该 source 内做状态机扩展，不新增旧 `SCNetworkReachability` 路径。
- Car / watch / smart cover：先只做 probe 和设备 checklist，不直接实现。它们依赖设备能力、外设状态或私有服务，不能用 metadata presence 推断可用性。
- Fingerprint / home indicator / gesture bar / 3D Touch：暂不进入实现。需要按设备能力和 iOS 版本逐项判断；没有 owner 确认前只保留 metadata。

### 2. 阶段 4：Hardware Button 与 Status Bar Event Sources

第一片 `volume up/down press` 已按独立采集 adapter 实现并通过真机验证。第二片 `volume both press` 已实现并通过真机验证。第三片 `volume up/down with menu` 已实现并通过真机验证。第四片 `volume up/down hold short` 已实现并通过真机验证。第五片 `volume up-down/down-up` 已实现并通过真机验证。第六片 `volume mute/unmute/toggle-mute-twice` 已通过 HID `0x0b/0x2e` 方向实现并通过真机验证。第七片 `menu.hold.long` / `menu.hold.short` / `menu.press.single` / `menu.press.double` / `menu.press.triple` 已按 HID adapter 实现并通过真机验证。第八片 `lock.hold.long` / `lock.hold.short` / `lock.press.double` / `lock.press.triple` / `lock.press.with-menu` 已按 HID adapter 实现并通过真机验证。

Status bar gestures 已按 `LATStatusBarEventSource` 实现并纳入 stable 逻辑覆盖，且已完成真机验收。验收覆盖主屏幕、锁屏和前台 App 界面中的 `statusbar.tap.single` / `.left` / `.right`、`statusbar.tap.double` / `.left` / `.right`、`statusbar.hold` / `.left` / `.right`、`statusbar.swipe.left` / `.right` / `.down`；前台 App tap/double 场景已确认 status-bar scroll-to-top 默认行为仍可用；切换三类界面后未观察到多个 `UIStatusBar_Modern` 实例串扰；顶部下拉等系统默认行为仍可触发。本阶段不实现 handled 后拦截默认状态栏行为。

Top slide / edge gesture family 已完成分类与 dispatch-no-intercept 切片并通过真机 dispatch 验收：`LATEdgeGestureEventSource` 接在 `_UISystemGestureWindow sendEvent:` 上，把 `UIEvent` 转 snapshot 后交给 `LATEdgeGestureClassifier`，分类成功即提交对应 `LAEvent`，但继续调用原始 `_UISystemGestureWindow sendEvent:`，不 handled、不吞掉原始触摸。`LATEdgeGestureClassifier` 负责 24 个 slide-in / two-finger-slide-in event name 的纯分类；stable 测试已覆盖全部 24 个 event name、非边缘起点、移动距离不足、单 session 一次分类、横屏 bottom，以及 event source dispatch once。真机验收已观察到事件计数增长，并完成少量绑定动作测试。下一步进入 drag-along screen-side 细分和 handled 后默认行为拦截层设计。

已验证：

- 已确认现代 iOS 上 SpringBoard hook 能稳定收到物理音量键 Consumer page `0x0c`、usage `0xe9` / `0xea`，并且单键 down/up 边沿可用。
- 已确认按键后系统音量仍正常变化；本阶段即使 Activator assignment handled，也不吞掉原始音量行为。
- 已确认先后按下两个音量键时只派发 `libactivator.volume.both.press`，松开两个键时不再额外派发单键 `press`。
- 已确认 Menu/Home + 单个音量键先后按下时只派发对应 `with-menu` 事件，松开时不再额外派发单键 volume `press`；没有 real Home/Menu HID 的设备不应期望触发该事件。
- 已确认静音拨片在现代 iOS SpringBoard HID hook 中表现为 `page=0x0b usage=0x2e`，解除静音为 `down=YES`，静音为 `down=NO`。
- 已确认单个音量键按住约 0.45 秒后只派发对应 hold short，松开时不再额外派发单键 volume `press`；如果按住期间进入 both press 或 with-menu 组合，会取消 hold 识别。
- 已确认 `volume up-down/down-up` 语义：首个音量键 release 时立即派发对应单键 `press`；如果 0.45 秒窗口内相反音量键 release，再派发顺序事件且不派发第二个单键 `press`；如果 0.45 秒窗口内同方向再次 release，不派发第二个单键 `press`；超过窗口时表现为两个独立单键 press。
- 已确认拨到静音派发 `volume.mute`，拨到响铃派发 `volume.unmute`，1 秒内来回拨动时在第二次状态事件后额外派发 `volume.toggle-mute-twice`。
- 已确认 Menu/Home 单击、双击、三击、short hold、long hold 行为可用；没有 double/triple assignment 时 single 在 release 后立即派发，存在 double/triple assignment 时 single 延迟 0.45 秒等待升级，存在 triple assignment 时第二次 release 后再等待 0.45 秒，第三次 release 派发 triple，否则派发 double；short hold 在 down 后约 0.45 秒派发并消费 single；Frida 校准显示实体 Home 初始 down 到 `SBHomeHardwareButton -longPress:` 约 0.40 秒，到 Siri presentation 约 0.42 秒，因此 short hold 继续使用旧 `kButtonHoldDelay` 0.45 秒；long hold 以 HID 侧 2.5 秒 timer 派发，避免在现代 iOS 上与 Siri/Home 系统 long press 阈值重叠；已确认 short hold 被兼容 listener handled 后，升级到 long hold 时会发送对应 short hold abort。
- 已实现 Menu/Home 与 `volume.*.press.with-menu` 的互斥：只要同一轮按键进入音量 + Menu/Home 组合，pending menu press/hold 会取消，松开 Home/Menu 时不再额外派发 menu single/hold。
- 已确认 Sleep/Lock 单键行为：Consumer page `0x0c` usage `0x30` 可稳定收到 down/up；`lock.hold.short` 在 down 后约 0.45 秒派发并消费 double/triple press；Frida 校准显示 Power/Sleep 初始 down 到 `SBLockHardwareButton -longPress:` 约 2.50 秒，到 `SBPowerDownViewController -powerDownViewWillAnimateIn:` 约 2.56 秒，因此 `lock.hold.long` 以 HID 侧 2.5 秒 timer 派发；short hold 被兼容 listener handled 后，升级到 long hold 时会发送对应 short hold abort；有 double/triple assignment 时两次 release 在 0.45 秒窗口内派发 `lock.press.double`，有 triple assignment 时第三次 release 派发 `lock.press.triple`；没有 double/triple assignment 时不为普通电源键 release 派发 lock press event。
- 已确认 Sleep/Lock + Menu/Home：先后按下 Sleep/Lock 和 Menu/Home 时只派发 `lock.press.with-menu`，并取消 pending lock/menu press/hold，松开时不再额外派发 menu single、lock double/triple 或 hold。
- 已确认 status bar gestures 真机路径：主屏幕、锁屏、前台 App 三类界面均可观测 tap、left/right tap、double tap、left/right double tap、hold、left/right hold、left/right/down swipe；前台 App 的 status-bar scroll-to-top 默认行为与系统顶部下拉行为未被本阶段 hook 破坏。
- 已确认 top slide / edge gesture classifier 通过 stable 测试覆盖 24 个 slide-in / two-finger-slide-in event name；纯分类器 24 组真机验证已通过，覆盖 SpringBoard、LockScreen、Application 三类 mode。dispatch-no-intercept 路径已通过真机验收，验收中观察到事件计数增长，并完成少量绑定动作测试；当前仍不拦截默认行为。

后续阶段：

- 下一切片是 Drag-along screen-side：`LAEventScreen*Swipe*` 常量已按 1.9.13 映射到 `libactivator.drag-along.*`，但当前 classifier 只覆盖 slide-in / two-finger-slide-in，不代表 drag-along 行为已恢复。
- Top slide / edge gesture 当前继续保持“不拦截默认行为”；如果需要 handled 后拦截，必须为具体 hook 设计返回值、原始事件转发和 `event.handled` 回传路径。
- Edge gesture 之后再评估 multitouch gestures、SpringBoard/icon gestures 和 lock screen gestures；它们分别需要独立 probe 和验收清单，不与 status bar 或 button adapter 混写。
- handled 后拦截默认音量行为暂不进入当前切片；`libactivator.volume.*` 在 1.9.13 资源中没有 double press 事件，不作为 volume 路线项。
- Hardware button event source 的 volume、ringer、Menu/Home、Sleep/Lock 主路径已完成实现和真机验收；`volume.display-tap` 依赖音量 HUD 触摸，不归入当前 HID 按键切片。
- Home/Menu button 仅在有 real home button 的设备上有意义，必须复用能力过滤结论；已验证 `HomeButtonType == 1` 表示实体 Home 键，`HomeButtonType == 2` 表示无实体 Home 键；`HomeButtonType == 0` 是有效值但语义尚未确认，不要当成未就绪状态或擅自映射；fake home indicator 设备不要注册 real-home-button-only 事件。
- 所有按钮 event source 都只负责识别事件并提交 `LAEvent`，不要在 adapter 内处理 assignment、blacklist、mode、no-touch deferral 或 unlock-to-send。

后续语义约束：

- 当前 volume button event source 仍是“保留默认音量行为”的实现；后续需要恢复“如果 Activator event 被 handled，则拦截默认音量行为”的能力。实现前必须重新设计 hook 返回值和原始事件转发路径，避免重复调音量或误吞系统事件。
- `press` 语义必须逐项按旧实现恢复：both、with-menu、hold 会消费本轮单键 `press`；`up-down/down-up` 不消费首个单键 `press`，只抑制第二个相反方向单键 `press`。后续 double press、long press 等时序事件也必须先查旧实现再决定是否消费 press。
- 按键 state machine 需要为每个物理键保存 down/up、是否已被组合键消费、是否已触发 hold，以及取消/丢失 up 的恢复路径；不要只靠单个布尔值扩展到复杂手势。
- 组合键和 hold 的识别必须有确定的优先级和超时策略，并且这个策略需要能解释“先按上再按下”“先按下再按上”“按住后松开其中一个键”等顺序差异。
- 如果未来开始吞掉默认行为，必须区分“事件已提交给 Activator dispatch engine”和“event.handled 为 YES”。前者不能作为拦截依据，只有 listener 真正 handled 后才能决定是否拦截原始系统行为。

### 3. 暂缓 / 高风险

| Listener name | 标题 | 建议状态 | 说明 |
| --- | --- | --- | --- |
| Control Center / Notification Center / Switcher | 系统 modal UI | `blocked` | 需要逐项 SPI probe 和设备 checklist；不要把旧 selector 直接映射到现代 UI，尤其要确认锁屏、App 内、SpringBoard 三种 mode 的行为。 |
| Power UI / reboot / power down / Safe Mode | 电源与恢复路径 | `blocked` | 高风险动作，必须先确定 owner 可接受的 SPI、失败路径和测试边界；Safe Mode 不应靠 crash 副作用实现。 |
| Siri / Voice Control / Wallet | 系统服务 UI | `blocked` | 依赖现代 SpringBoard / Assistant / PassKit 私有入口，先做 Frida/IDA probe，再决定是否进入 action family。 |
| Rotation / orientation lock | 系统状态写入 | `blocked` | 需要确认现代 orientation policy 和 SpringBoard 同步接口，不能只改 preference 或只发通知。 |
| Lock screen show / dismiss / toggle | 锁屏状态 | `blocked` | 与 passcode、biometric、unlock-to-send 和 display power policy 强相关，需单独设计。 |
| Camera shutter / compose Mail/SMS/Notes / watch haptics | 应用或设备特定动作 | `blocked` | 涉及目标 App、设备能力或跨服务状态；不作为下一阶段默认目标。 |

### 4. 架构外 / 不恢复

| Listener name / family | 标题 | 建议状态 | 说明 |
| --- | --- | --- | --- |
| `libactivator.system.local-back` / `libactivator.system.back` | Local Back / Back | `out-of-scope` | 1.9.13 旧语义依赖 `com.apple.UIKit` filter 把 `libactivator.dylib` 注入到 App 进程；SpringBoard 端只 `notify_post("libactivator.system.back")`，真正的 `dismissViewControllerAnimated:` / `popViewControllerAnimated:` 在 App 进程内执行。本项目基本约束是不注入用户 App 进程，因此该 family 只保留资源和逆向记录，暂不实现，也不阻塞下一阶段。 |
| SBSettings toggles | Legacy toggles | `obsolete` | 旧 SBSettings ABI 已过时；除非 owner 明确要求现代兼容层，否则不恢复。 |
| 旧 social compose actions | Twitter / Facebook / Weibo compose | `obsolete` | 资源和 runtime 已排除；旧服务入口不再作为内置 action 恢复。 |

### 5. 阶段 4 完成后的大阶段

阶段 4 的 top slide / edge gesture、multitouch、SpringBoard/icon gesture 和 lock screen gesture 切片稳定后，下一大阶段是 Settings UI 与菜单：实现 `libactivatorsettings.dylib`，覆盖 modes/events/listeners 列表、搜索、assignments、profiles、blacklist、listener/event configuration controller factory、menu editor、menu listener runtime provider、glyph/small icon 展示和 metadata/localization 展示。Settings UI 仍只通过 Public API/IPC 操作 SpringBoard authoritative backend，不拥有 event acquisition 或 runtime state。

Settings UI 与菜单主路径稳定后，再推进 CLI 兼容工具：实现 `/usr/bin/activator` 的 1.9.13 命令面，覆盖 `listeners`、`events`、`modes`、`current-mode`、`current-app`、`get`、`set`、`activate`、`send`、`deactivate` 和隐藏 `postinst` no-op 边界。CLI 是 production compatibility tool，不能依赖 DEBUG-only testing IPC、hidden testing IPC 或测试 plist。

## 下一阶段验收要求

- 新增 dynamic listener family 必须有独立 provider / registry path，不把动态 App listener 塞进 static built-in action listener。
- 新增 event source family 必须有独立 acquisition adapter，不把采集 hook 混入现有 action listener。
- 每个新 family 至少拆出一个 stable suite；测试重点是 registration、metadata lookup、`hasSeen`、mode/blacklist/dispatch 语义和 metadata-only 不注册。
- `event.handled` 表示 listener 消费事件或 adapter 提交事件，不表示系统最终状态变化完成；真实系统状态变化进入设备手工 checklist。
- 不为 stable tests 给真实 action path 增加高侵入 hook；优先测试真实分层边界和可观察状态。
- 实现前先记录现代 SPI 选择；如果接口不确定，先标 `blocked` 并和 owner 确认，不用 public API fallback 掩盖行为差异。
