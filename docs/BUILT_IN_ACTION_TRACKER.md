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

Hardware actions / listener family 已从旧 Media family 中拆出。当前 `LATHardwareActionListener` 承载 15 个 HID Consumer page 播放、音量、输出静音、亮度、Home、Sleep、屏幕键盘、截图、Spotlight 硬件键，以及 `libactivator.system.vibrate` 的硬件振动反馈。HID 动作通过 `IOHIDEventCreateKeyboardEvent` 与 `IOHIDEventSystemClientDispatchEvent` 提交；vibrate 使用 `AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)`；`event.handled = YES` 表示 action request 已被 listener 接受并提交，不表示系统 UI 或目标应用已经完成状态变化。`SBScreenShotter` 已确认在现代 iOS 不可用，因此截图不走旧 master 的 `SBScreenShotter saveScreenshot:` 路径。

System actions / listener family 已用于承载非 URL、非 HID、但低风险且接口明确的系统服务动作。当前 `LATSystemActionListener` 包含 volume HUD、now-playing application launch、ringer state sync、ringer mute/unmute/toggle、SBS first SpringBoard page。实现边界已固定：注册 name 仍由代码 allowlist 决定；metadata lookup 用于 selector metadata gate；volume/ringer 动作通过 tweak hook 缓存在 `LATBuiltInListenerRegistry` 中的 `SBVolumeControl` / `SBRingerControl` 原进程对象执行；now-playing application launch 通过 MediaRemote 解析当前播放应用后走统一 `LATApplicationLauncher`，亮屏锁屏下会请求解锁启动，熄屏仍由 `needs-powered-display` dispatch gate 拦截；ringer reset 按 1.9.13 旧实现通过 `BKSHIDServicesGetRingerState` 与 SpringBoard `-_updateRingerState:withVisuals:updatePreferenceRegister:` 同步；first-page 使用 `SBSServiceFacilityClient` checkout `SBSSystemServiceClient` 后调用 `resetToHomeScreenAnimated:`。

Telephony actions / listener family 现在只承载通话控制。`LATTelephonyActionListener` 包含 2 个 call control 动作：`answer-call` 和 `disconnect-call`；Phone tab URL 已按执行机制并入 `LATURLActionListener`。Call control 动作参考 `TRAppIntentXpcServiceConnection.mm` 中已验证的 CoreTelephony 路径，tweak 使用项目内私有 `CTCall.h` 副本并链接 `CoreTelephony.framework`，在主队列异步执行通话控制。`libactivator.phone.disconnect-call` 的 selector metadata 已从旧资源误写的 `answerCall` 规范化为 `disconnectCall`。`libactivator.phone.answer-call` 曾出现首个来电可接、后续来电不可接但可挂断的现象；原因判断为 answer 依赖当前 incoming `CTCallRef`，而参考项目还通过 `CTTelephonyCenter` 持续订阅 call status / identification change 来维护进程内 CoreTelephony 状态，当前实现已补齐这个 observer。`event.handled = YES` 表示 telephony listener 已消费请求，不表示电话状态已完成变化。

Dynamic application listeners 已实现。`LATApplicationListenerProvider` 使用 `LSApplicationWorkspace` / `LSApplicationProxy` 枚举可见 System / User 应用并注册 bundle/display identifier listener；app 列表变化通过 Darwin notification `com.apple.LaunchServices.ApplicationsChanged` 触发，并用防抖策略延迟刷新。LaunchServices snapshot 构建放在后台 utility queue，main queue 只应用 added / removed listener 变更，不全量重建其他 listener family。refresh 阶段只保留注册所需的最小 descriptor，不读取 bundle `Info.plist`、不计算 display name、也不按 display name 排序；动态 title、description、group metadata 由 `LATApplicationActionListener` 在 metadata 查询时懒加载。实际启动统一交给 `LATApplicationLauncher`，通过 `SBSLaunchApplicationWithIdentifierAndLaunchOptions` 在专用非主队列提交。`com.apple.camera` 是唯一当前已实现的动态应用 special case：锁屏模式下不请求解锁打开 Camera App，而是通过 `CSCoverSheetViewController -activateCameraViewAnimated:sendingActions:completion:` 在主队列打开锁屏相机；屏幕未点亮时通过 `LAScreenWakeCoordinator` 发送 Power HID 短按，等 `com.apple.springboard.hasBlankedScreen` 状态变为未 blank 后再提交锁屏相机切换；该 SPI 不可用时退回普通解锁启动。`event.handled = YES` 表示 launch request 已被 listener 接受并提交，不表示目标 App 已完成前台切换。

当前 built-in actions / listeners 的低风险实施面已经收束。后续阶段应从“继续补动作”转向 event source family。listener 划分仍按执行机制决定：URL action 归 `LATURLActionListener`，HID Consumer action 归 `LATHardwareActionListener`，SpringBoard/system-service action 归 `LATSystemActionListener`，通话控制归 `LATTelephonyActionListener`，动态 App 归 `LATApplicationActionListener`；新阶段不要把 event acquisition adapter 或 Settings UI 逻辑塞回现有 action listener。

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
| Music controls modal | 无 | `obsolete` | 旧 `SBNowPlayingAlertItem` modal 在现代 iOS 没有等价 UI，不作为当前 listener family 恢复。 |

## 下一阶段建议

### 1. Low-Risk Event Sources

建议进入低风险 event source family，而不是继续补零散 action。优先考虑不依赖复杂触摸识别、能通过系统通知或 SpringBoard 状态稳定采集的事件。

当前 `device locked / unlocked` 已实现。`LATLockStateEventSource` 在 SpringBoard tweak 内承载 `com.apple.springboard.lockstate` Darwin notification，使用 `SBLockScreenManager isUILocked` 读取权威锁定状态，并只在锁定状态边沿变化时发送 `libactivator.device.locked` 或 `libactivator.device.unlocked`。adapter 在 `SpringBoard applicationDidFinishLaunching:` 后启动，启动时只 seed 当前锁定状态、不发送事件，避免在 tweak constructor 阶段提前创建 `SBLockScreenManager`；adapter 同时承接原先 `ActivatorTweak.m` 中 lockstate notification 触发 runtime state refresh 的职责，避免 tweak 入口重复注册同一通知。`power connected / disconnected` 也已实现，`LATPowerStateEventSource` 通过 `UIDeviceBatteryStateDidChangeNotification` 采集 `UIDeviceBatteryStateCharging` / `Full` 与 `Unplugged` 的边沿变化，`Unknown` 状态只忽略、不发送事件。`headset connected / disconnected` 已实现，`LATMediaEventSource` 监听 MediaRemote route notification、`AVSystemController_ActiveAudioRouteDidChangeNotification`、`AVSystemController_PickableRoutesDidChangeNotification` 和旧版 headset notification，然后使用 `AVSystemController_HeadphoneJackIsConnectedAttribute` 读取有线耳机连接状态；MediaRemote notification 的 object/userInfo 只作为诊断输出并触发一次 AVSystemController 状态重读。同一 source 也承接 `libactivator.audio.launch-playing-app` 所需的 MediaRemote now-playing app identity 查询，让 listener 只保留启动应用职责。

优先候选：

- device locked / unlocked：已实现，信号来源为 `com.apple.springboard.lockstate` + `SBLockScreenManager isUILocked`；仍需在真机 checklist 中覆盖手动锁定、自动锁定、回主屏幕解锁和回 App 解锁路径。
- power connected / disconnected：已实现，信号来源为 `UIDeviceBatteryStateDidChangeNotification`；仍需在真机 checklist 中覆盖接入电源、断开电源、满电状态下重新接入等路径。
- headset connected / disconnected：已实现，信号来源为 MediaRemote route notification 和 `AVSystemController` route/headset notifications；实际状态读取使用 `AVSystemController_HeadphoneJackIsConnectedAttribute`，MediaRemote notification payload 只作为诊断日志；当前语义限定为有线耳机，蓝牙、CarPlay、AirPods 等 route 不触发该事件。
- Wi-Fi joined / left：需要确认 CaptiveNetwork / SystemConfiguration / Wi-Fi private notification 的现代可用性；不确定时先停在 probe 阶段。

实施边界：

- 每个 event family 使用独立 SpringBoard acquisition adapter，只负责采集信号并构造 `LAEvent`。
- assignment、blacklist、mode、no-touch、unlock-to-send 继续交给现有 dispatch engine，不在 adapter 中重复实现。
- 能模拟的 notification path 可进 stable tests；真实硬件状态变化进入 `RuntimeDevice` 或手工 checklist。

### 2. 暂缓 / 高风险

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

## 下一阶段验收要求

- 新增 dynamic listener family 必须有独立 provider / registry path，不把动态 App listener 塞进 static built-in action listener。
- 新增 event source family 必须有独立 acquisition adapter，不把采集 hook 混入现有 action listener。
- 每个新 family 至少拆出一个 stable suite；测试重点是 registration、metadata lookup、`hasSeen`、mode/blacklist/dispatch 语义和 metadata-only 不注册。
- `event.handled` 表示 listener 消费事件或 adapter 提交事件，不表示系统最终状态变化完成；真实系统状态变化进入设备手工 checklist。
- 不为 stable tests 给真实 action path 增加高侵入 hook；优先测试真实分层边界和可观察状态。
- 实现前先记录现代 SPI 选择；如果接口不确定，先标 `blocked` 并和 owner 确认，不用 public API fallback 掩盖行为差异。
