# 旧版逆向证据索引

本文只保留当前实现会反复引用的 1.9.13 旧行为结论。完整解混淆步骤、IDA 细节、长引用和历史调查记录查 `docs/archive/2026-06-17/LEGACY_REVERSE_ENGINEERING.md`。

## 使用规则

- 本文是证据索引，不是实现计划。实现顺序和当前状态仍以 `BUILT_IN_ROADMAP.md` 与 `BUILT_IN_ACTION_TRACKER.md` 为准。
- 旧 master 只能作为语义参考，不能照搬实现；1.9.13 package、Public API 和资源 catalog 优先。
- 如果本文结论不足以决定现代实现方式，先回 archive 查完整证据；仍不确定时记录待决策点并问 owner。
- 当前项目不恢复旧 `com.apple.UIKit` 全局注入。任何旧行为如果依赖用户 App 注入，都必须重新设计为 SpringBoard runtime、精确 Apple App companion tweak，或明确放弃。

## 参考产物

- 当前 package 基线：`references/latest` 中解包出的 Activator `1.9.13~rc6`。
- 旧实现源码：`references/master`。
- 旧 headers：`references/headers`，仅作考古参考。
- `ActivatorSpringBoard` 解混淆分析产物位于 `references/latest/analysis/ActivatorSpringBoard/`，只作为本地参考快照，不提交。
- 解混淆后的分析重点来自 `references/latest/analysis/ActivatorSpringBoard/ActivatorSpringBoard.arm64.decrypted.i64`。引用旧实现时应说明证据来自解混淆产物，避免把原始混淆二进制中的缺失字符串误判为未实现。

## Gesture 与 event 语义

- 1.9.13 解混淆产物确认 Event definition 并非只有 `LADefaultEventDataSource`：私有 `LAMetaEventDataSource` 协议提供 `activator:supportsEventName:` / `activator:addAvailableEventNamesToArray:`，私有 `LAEventEmitter` 协议提供 emitter configuration controller 与创建回调；`_LAActivator` 另有 emitter registry 和 `_createNewEventWithConfiguration:forEventEmitterName:`。Network、Application、Mail、Notification、Scheduled、Battery Level data source 使用这些动态能力。当前 rewrite 只借鉴“静态 definition、动态 definition/configuration、acquisition 分层”，不恢复通过全进程枚举搜索 SpringBoard/系统 framework 私有 class、固定数组或旧对象模型；只枚举明确的 libactivator-owned image 并按项目私有 module protocol 发现自有模块不属于这一禁令。
- 对应 IDA 定点为：`LADefaultEventDataSource` 的 supports/add catalog 在 `0xF740` / `0xF758`；`_LAActivator` 的 available emitter registry、register/unregister、create-new-event 和 per-event configuration get/save 分别位于 `0xE48C`、`0xE560` / `0xE574`、`0xE588`、`0xE5C8` / `0xE5F4`。这些入口证明旧版把 static catalog、dynamic definition creation 和 per-event configuration 分成了独立能力面。
- 1.9.13 `LAScheduledEventDataSource` 的 `configurationForEventWithName:`、`eventWithName:didSaveNewConfiguration:`、`removeEventWithName:` 会更新 provider-owned 配置、可用 event 和调度状态；因此现代 dynamic provider 必须由 SpringBoard authoritative store 持有配置，由独立 definition registry 执行 owner-safe definition mutation，再由 module-declared binding 把 immutable snapshot 应用到 acquisition mapping，不能让 source 或 Settings client 直接写 plist。Binding 只替代中央逐 family 接线，不改变 definition mutation 的预检、重入保护、owner postflight、通知可见性与回滚语义。
- 1.9.13 Network specific SSID definition 来自用户显式 emitter，不会随当前网络或历史网络自动生成。`LANetworkStatusEventDataSource` 的 `supportsEventName:` `0x178F0` 和 `addAvailableEventNamesToArray:` `0x17928` 只读取持久数组 `LANetworkStatusEvents`；`eventEmitterWithName:shouldAddNewEventWithConfiguration:` `0x17984` 以 `emitterName.SSID` 生成并持久化 exact name；`removeEventWithName:` `0x17C1C` 先 unassign 再移除。`updateWithNetworkName:` `0x17CCC` 只在 exact name 已配置时先派发 specific，handled 后抑制 base，否则 fallback base；A 到 B 只产生 joined(B)，不额外产生 left(A)。

- Status bar 旧 master 有两条路径：SpringBoard 端 `SBStatusBar` 派发通用 statusbar tap/hold/swipe，UIKit everywhere 注入端 `UIStatusBar` 根据触摸起点划分 left/base/right。旧实现 single tap fallback 会把触摸传回系统状态栏，说明它尽量保留系统默认行为，不是在识别阶段直接吞掉触摸。
- 1.9.13 仍保留 `libactivator.statusbar.swipe.down` 兼容名，但它已属于 top slide / edge gesture family 的历史兼容事件。现代实现应保留该事件名，同时把完整 top slide / edge gesture family 单独实现。
- 1.9.13 中 `LAEventScreen*Swipe*` public constants 仍导出，但实际字符串指向 `libactivator.drag-along.*` namespace，不是 `libactivator.screen.*.swipe.*`。当前项目常量值必须按 1.9.13 映射到 `drag-along` 名称。
- Slide / drag 阈值结论：默认 edge band 约 `13pt`，slide-in 内移触发 rect 约 `63pt`，drag-along 移动阈值约 `30pt`，drag-off 结束边缘区约 `20pt`。当前实现直接对齐 1.9.13 阈值，只有真机验收证明需要时再调整。
- 当前项目不使用旧 `com.apple.UIKit` filter 注入用户 App。现代 status bar 点位在 SpringBoard 内多个 `UIStatusBar_Modern` 实例上处理，每个实例应拥有独立识别 session，避免旧全局状态在多实例状态栏下串扰。
- Force touch 由 1.9.13 的 `ActivatorSystemGestureRecognizer` 承载，事件名包括 statusbar、screen-left、screen-right、screen-bottom-left、screen-bottom、screen-bottom-right。旧实现读取 `UITouch.force`，不是直接读取 HID pressure；当前语义也应以 `UITouch.force` 为来源。
- Force touch 区域结论：`y < 38pt` 为 statusbar；底部 `38pt` 内按 `x` 四分位划分 bottom-left/bottom/bottom-right；非底部/状态栏区域中 `x < 14pt` 为 left，`x > width - 14pt` 为 right。阈值约 `5.0`，当前实现使用 `force >= 5.0` 作为可测试边界。
- Multi-touch 同样由 1.9.13 的 `ActivatorSystemGestureRecognizer` 承载，只识别 3/4/5 指 tap、pinch、spread。Pinch 使用当前 span / baseline span `< 0.75`，spread 使用 `> 1.33333337`，tap 在 touches ended 时要求从起点到终点的总移动量 `< 10pt`；span 语义是以稳定锚点 touch 为基准，累加 active touches 到锚点的 squared distance，不使用 velocity 或 acceleration。当前项目保持 no-intercept 语义，旧版 handled 后取消触摸属于后续 handled-default interception backlog。
- SpringBoard icon pinch/spread 旧 master hook `SBIconScrollView -initWithFrame:`，把 `minimumZoomScale` 调到 `0.95` 以复用 scroll view 自带 pinch recognizer，并在 `handlePinch:` 中按 `scale < 0.95` 发送 `libactivator.springboard.pinch`、按 `scale > 1.05` 发送 `libactivator.springboard.spread`，同一 session 只发送一次。现代 iOS owner/probe 已确认仍有 `SBIconScrollView`，且它本质是 `UIScrollView` 并暴露 `pinchGestureRecognizer`；当前实现复用该 recognizer 追加 target，不新增竞争 recognizer。
- Motion shake 旧 master 在 SpringBoard 的 `_sendMotionEnded:` 中发送 `libactivator.motion.shake`，仅在事件被 listener handled 后记录时间并忽略后续 2 秒内的 shake；handled 分支还会跳过原系统实现。现代 iOS 实机调用链确认每次 shake 最终唯一到达 SpringBoard 进程内的 `-[UIApplication motionEnded:withEvent:]`，当前实现据此 hook `UIApplication` 并交给独立 `LATMotionEventSource`。现代 source 不沿用旧 2 秒窗口，以免合并两次真实的连续 shake；hook 始终继续调用 UIKit 原实现，不把默认行为拦截混入 acquisition。

## Now Playing 与媒体动作

- `libactivator.audio.launch-playing-app` 旧实现使用 `SBMediaController nowPlayingApplication`，失败时 fallback 打开 `com.apple.Music`。现代实现不保留静态 Music fallback；应使用 MediaRemote display id 优先、PID + SpringBoardServices fallback 的 identity provider。没有 now-playing identity 时仍消费事件并记录英文诊断。
- `libactivator.ipod.music-controls` 旧实现显示或关闭旧 SpringBoard now-playing alert，失败时退回 now-playing app / Music fallback。现代 iOS 没有对应 alert 体验，当前等价实现为打开 Control Center 并切换 Now Playing 模块展开状态。
- `libactivator.system.show-now-playing-bar` 使用同一现代 Now Playing Control Center 实现。

## Lock screen、Switcher、电源与系统 UI

- 阶段 3 锁屏、Switcher 和电源类 actions 优先采用现代 iOS 参考实现；1.9.13 解混淆只用于确认 selector、动作语义和参考实现未覆盖的 UI 动作。
- `libactivator.lockscreen.show` 使用 `SBLockScreenManager.sharedInstance remoteLock:YES`，不执行背光 fade out。
- `libactivator.lockscreen.dismiss` 屏幕未亮时先通过项目内 Power HID 唤醒和 screen-on state 回调，再尝试空 passcode 解锁路径；该路径只支持无密码设备或系统允许空 passcode 解锁的状态。
- `libactivator.system.respring` / `hard-respring` 使用 `SBSRelaunchAction` + `FBSSystemService`，hard respring 带 `SBSRelaunchActionOptionsRestartRenderServer`。
- `libactivator.system.soft-reboot` 使用 `jbroot(/usr/libexec/activator/user-reboot)` setuid/setgid helper 执行 `reboot3(RB2_USERREBOOT)`；SpringBoard 进程内 listener 只通过 `posix_spawn` 调用 helper。
- `libactivator.system.powerdown` / `reboot` 使用 `SpringBoard.restartManager shutdownForReason:nil` / `rebootForReason:nil`。
- 旧 master 与 1.9.13 均显示多个 `activate-*` action 是 toggle：Control Center、Notification Center、Switcher、Reachability、Siri 等现代实现也应保留 toggle 语义。
- `libactivator.system.power-menu` 的现代有效入口是 `SBMainWorkspace.sharedInstance[IfExists] presentPowerDownTransientOverlay`。
- `libactivator.system.edit-screenshot` 语义是立即截图并进入编辑，优先 `_takeScreenshotAndEdit:`，fallback `takeScreenshotAndEdit:`，再 fallback 普通 `takeScreenshot`。
- `libactivator.system.safemode` 语义是主动制造 SpringBoard exception 以触发 loader Safe Mode，owner 已接受该行为。
- `libactivator.system.clear-switcher` 参考 QuitAll 的 iOS 15 `SBMainSwitcherViewController` 删除路径，并按 iOS 16+ `SBMainSwitcherControllerCoordinator` removal SPI 做现代实现；默认跳过 Now-Playing App。执行时先判断当前 App 和现有 switcher layouts，当前处于 Now-Playing App、switcher 为空或仅有 Now-Playing App 时不打开 App Switcher；否则先打开 App Switcher，再清理列表。该行为已通过真机验收。
- `libactivator.system.lock-and-wipe-credentials` 语义是锁屏并强制 biometric lockout，不是删除 passcode 或清除系统凭据。
- Hardware action 的 handled 由 `_LASimpleListener -activator:receiveEvent:forListenerName:` 的 selector 返回值决定。1.9.13 method list 显示：`homeButton` `0x6290`、`sleepButtonFromActivator:event:` `0x63bc`、`increaseVolume` `0x85f0`、`decreaseVolume` `0x860c` 固定返回 true；`togglePlayback` `0x7a34`、`playMedia` `0x7aa0`、`pauseMedia` `0x7b30`、`previousTrack` `0x7bbc`、`nextTrack` `0x7c38` 只有能提交对应媒体命令或状态需要变化时返回 true；`takeScreenshot` `0x6c18` 在 screenshot 正在写入时返回 false；`vibrate` `0x889c` 固定返回 true。因此当前 `LATHardwareActionListener` 不应在 metadata mismatch 或 action 返回 false 时预先消费事件；统一 HID sender 的 dispatch failure gate 是现代实现差异，不应被写成 1.9.13 固定 true 完全对齐。
- 1.9.13 package 中 `libactivator.screen.brightness.increase` / `decrease` 存在 metadata，但没有 `selector` metadata；`_LASimpleListener` method list 未见对应 runtime selector，旧 master 也未注册对应 runtime listener。当前把这两个 name 作为现代 HID action 实现时，只能按当前 2.x/modern resource extension 基准记录，不能声称 1.9.13 selector 对齐。`libactivator.audio.toggle-output-mute` 和 `libactivator.keyboard.toggle-on-screen-keyboard` 是当前 2.x additive action，不属于 1.9.13 同名对齐项。
- 1.9.13 `spotlight` `0x6810` 不是单纯 Search HID：它会处理旧 App Switcher / home screen search UI，已有 Spotlight/search first responder 时可 resign 并返回 false，其他打开或聚焦搜索的路径返回 true。当前 `LATHardwareActionListener` 保持现代 HID Search 方案，只能按“metadata gate + HID request submission”记录现代差异，不能为 handled 对齐恢复旧 SpringBoard search controller 流程。
- System action 同样必须由 selector/controller 返回值决定 handled。1.9.13 `showControlCenter` `0x875c`、`musicControls` `0x7cc4`、`activateNotificationCenter` `0x8270` 和 `activateReachability` `0x87fc` 都是 toggle 语义：打开目标 UI 返回 true，关闭或已激活分支返回 false。当前 `LATSystemActionListener` 已改为不在 switch 前预先 `handled = YES`，而是使用各 controller 的 BOOL 返回值。
- 1.9.13 `activateSiri` `0x6e58` 在 preference/supported/should-enter gate 失败或关闭已显示 Siri 时返回 false，成功激活时返回 true。当前 `LATSystemAssistantController` 不复刻旧 `SBAssistantController` gate；现代准则是 Siri 已显示时 dismiss 并按旧关闭分支不消费，未显示时 `AXPISystemActionHelper activateSiri` 可提交才消费。
- 1.9.13 `editScreenshot` `0x6cf4` 在 `_takeScreenshotAndEdit:` / `takeScreenshotAndEdit:` 可用时返回 true；否则 tail-call 普通 `takeScreenshot`，继承 screenshot busy 时返回 false 的语义。当前 `LATSystemScreenshotController` 因此在 edit selector 不可用时复用 screenshot manager busy gate。
- 1.9.13 电源 selector 返回值：`respring` `0x650c` 在 `relaunchSpringBoard` 或 `SBSRelaunchAction` + BackBoard/Application send path 可用时返回 true，否则返回 false；`safeMode` `0x6650` 延迟触发 `safeModeFromActivator` 并固定返回 true；`reboot` `0x668c` 在 `restartManager rebootForReason:` 或 `UIApp reboot` 可用时返回 true，否则返回 false；`powerDown` `0x6708` 在 `powerDownRequested:` 或 `powerDown` 可用时返回 true，否则返回 false；`powerDownView` `0x6760` 固定返回 true，即使现代 fallback 不可用也仍消费事件。当前现代电源 controller 不为 handled 对齐新增旧 fallback，只在既有现代方案可提交时消费，不能表达的旧分支记录为差异。
- 1.9.13 `startDictation` `0x8628` 只 `notify_post("libactivator.keyboard.dictation")` 并固定返回 true；真实听写动作在旧 UIKit 注入端执行。当前项目不恢复用户 App 注入，因此 SpringBoard 端现代 AX fallback 的元素命中与否不回滚 handled。
- 1.9.13 `tapticWithActivator:event:listenerName:` `0x8b40` 从 listener metadata 读取 `tapticType`；`0` flick、`1` tap、`2` quirk 返回 true，未知非 0/1/2 类型返回 false。当前现代实现不复刻旧 `_tapticEngine` fallback，但保持有效类型消费、未知类型不消费。
- 1.9.13 `openWallet` `0x8d88` 在 Wallet/Passbook controller 实例存在且支持 `presentPreArmInterfaceForTriggerSource:` 时返回 true，否则返回 false。当前现代实现使用 `AXSpringBoardServer armApplePay`，只对齐“可提交才消费”的 handled 语义，真实入口仍是现代差异。
- 1.9.13 rotation selectors `rotatePortrait` / `rotatePortraitUpsideDown` / `rotateLandscapeLeft` / `rotateLandscapeRight` 分别 tail-call `0x9114` 并传入 UIKit orientation 值；`0x9114` 在锁定且目标横屏不受设备支持、当前 event mode 又不是 application 时返回 false，其余多数路径提交或尝试 orientation 后返回 true。当前现代 `AXSpringBoardServer setOrientation:` 入口只先对齐 SPI 不可用时不消费，锁定/设备能力分支仍待补。
- 1.9.13 `showVolumeBar` `0x7704` 是旧 App Switcher bottom bar 方案：目标 bar 未显示时打开/滚动并返回 true，已在目标位置时 dismiss switcher 并返回 false。当前现代 `LATSystemVolumeHUDPresenter` 只显示 Volume HUD，不为 handled 对齐恢复旧 switcher bottom bar 方案，因此只能记录为现代差异。
- 1.9.13 `resetRingerState` `0x783c` 在能解析 ringer state 函数且 SpringBoard 支持 `_updateRingerState:withVisuals:updatePreferenceRegister:` 时返回 true，否则返回 false。当前 `LATSystemRingerStateResetter` 保持同类 SPI gate。
- 1.9.13 lock screen selector 返回值：`showLockScreen` `0x78a4` 在能提交任一旧锁屏路径时返回 true，否则返回 false；`dismissLockScreen` `0x7974` 固定返回 true；`toggleLockScreen` `0x79d4` 根据旧锁屏状态 tail-call show/dismiss；`wipeCredentials` `0x6448` 固定返回 true。当前现代 Lock Screen controller 不新增旧 fallback，只在现有 `remoteLock:` / unlock / biometric lockout 方案内对齐可表达的 handled 分支。
- 1.9.13 `firstSpringBoardPage` `0x7ff8` 根据是否实际关闭 notification/switcher/folder、退出编辑、回首页或发送 home action 返回 true/false。当前现代实现使用 `SBSSystemServiceClient resetToHomeScreenAnimated:` 异步请求，无法在不改变方案的情况下复刻旧 UI 分支返回值。
- 1.9.13 `goBackWithActivator:event:` `0x8648`：application mode post local back notification 并返回 true；从 `libactivator.menu.press.single` 触发时返回 false；其他非 application mode tail-call `homeButton`。`localBack` `0x8704` 在 recursion guard 外 post notification 并返回 true，guard 内返回 false。当前现代实现不恢复 UIKit 注入，但保留 application mode local-back、menu single false 和非 application mode Home fallback 的可见分支。
- 2.x additive system actions 没有 1.9.13 同名 selector 基线。`libactivator.audio.mute-ringer` / `unmute-ringer` / `toggle-ringer-mute` 当前以 `AXPISystemActionHelper` 或 `SBRingerControl` 可提交为 handled gate；`libactivator.system.hard-respring` 复用现代 relaunch action 并带 render server restart option；`libactivator.system.soft-reboot` 只表示 helper spawn request 已排队，异步 helper 执行失败只记录诊断。

## Compose、Phone 与 Camera

- 1.9.13 `_LASimpleListener` 的 metadata-backed URL action selector `openURLWithActivator:event:listenerName:` 位于 `0x8e10`：先读取 `url` metadata，或从版本化 `urls` 数组中选择 URL；解析出 URL 后调用 `applicationOpenURL:publicURLsOnly:` / `openURL:` 并返回 true，解析不到 URL 返回 false。Phone tab actions 是单独 selector，旧 master `showPhoneFavorites` / `showPhoneRecents` / `showPhoneContacts` / `showPhoneKeypad` / `showPhoneVoicemail` 源码显示内部硬编码 URL 并固定返回 true。当前 `LATURLActionListener` 对齐该策略：unsupported name 不消费，metadata-backed URL action 只有解析出可提交 URL 才消费，hardcoded Phone URL action 不依赖 URL metadata，真实打开失败不回滚 handled。
- `libactivator.mail.compose-message`、`libactivator.sms.compose-message`、`libactivator.notes.compose-note` 旧实现都使用临时 `UIWindow` presenter；当 compose UI 已存在时，再次触发会关闭当前 UI。当前 Mail/SMS 继续 runtime 加载 `MessageUI.framework`；Notes 旧 `Social.framework` / sharing extension 路径在现代 iOS 验证无效，不保留 fallback。
- 1.9.13 Compose selectors 已补 selector 级 IDA：`composeMail` `0x8510`、`composeText` `0x8524` 均 tail-call 旧 composer object 的 `performAction...`，由旧 presenter 返回值决定是否 handled；`composeNote` `0x8594` 在已有 compose UI 时关闭并返回 true，否则创建 Notes compose view controller 并返回 presentation 结果。当前现代准则与旧策略一致：unsupported name、selector metadata 缺失或不匹配不消费；metadata gate 通过后，只有能关闭已有 compose UI 或提交 Mail/SMS/System Paper presentation request 时才消费。
- Phone tab actions 旧实现内部打开 URL。当前实现按真机验证使用 `mobilephone-favorites:`、`mobilephone-recents:`、`mobilephone-contacts:`、`vmshow:`；`phone.keypad` 恢复旧 `mobilephone-recents:keypad` URL，但现代 iOS 需要只注入 `com.apple.mobilephone` 的 companion tweak 才能切到 keypad。
- `libactivator.phone.answer-call` 的 1.9.13 resource metadata 使用 selector `answerCall`；`disconnect-call` resource metadata 也错误写成 `answerCall`，但 1.9.13 binary method list 同时存在 `disconnectCall` selector。当前将 `disconnect-call` 规范化为 `disconnectCall`，并由 telephony listener 继续以 selector metadata gate 区分动作。
- 1.9.13 Telephony selectors 已补 selector 级 IDA：`answerCall` `0x88b8` 在 telephony classes/API/call state gate 通过并能提交 answer request 时返回 true，否则 false；`disconnectCall` `0x89c8` 在 telephony classes/API/call state gate 通过并能提交 disconnect request 时返回 true，否则 false。当前现代准则与旧策略一致：unsupported name、selector metadata 缺失或不匹配不消费；answer 只有存在 incoming call 且已提交 answer request 时消费，disconnect 只有存在 current calls 且已提交 disconnect-all request 时消费。
- `answer-call` 需要持久 CoreTelephony call state observer；单次读取 current calls 会出现首个来电可接、后续来电不可接但仍可挂断的问题。
- `libactivator.camera.invoke-shutter` 旧语义是先尝试相机快门，失败时打开 Camera 并等待 ready 后重试。当前现代实现拆成 SpringBoard listener 与只注入 Camera 的 companion tweak：锁屏状态优先 CoverSheet camera，非锁屏状态下只有当前前台为 `com.apple.camera` 时才直接发送 Consumer page `VolumeDecrement` HID。
- 1.9.13 `ActivatorSpringBoard.arm64.decrypted.i64` 中 `_LASimpleListener` 的 `cameraShutterWithActivator:event:` IMP 为 `0x8d38`，通用 `activator:receiveEvent:forListenerName:` IMP 为 `0x8f50`。后者读取 `selector` metadata 并调用 selector，只有返回真才 `setHandled:`。前者调用实际 shutter 尝试函数 `0x9298`，当场 shutter 成功时返回真；如果需要等待 `libactivator.camera.ready` 后重试，则设置 pending 状态并返回假。因此当前 `LATCameraActionListener` 对齐为：unsupported name、selector metadata 缺失或不匹配均不消费；只有当场提交 shutter HID 成功时消费，打开/等待 Camera ready 的 pending 分支不消费原事件。
- Camera ready 不能只相信 launch completion 或 `UIApplication setWantsVolumeButtonEvents:YES`。当前 companion tweak 以 `CAMViewfinderViewController -_updateEnabledControlsWithReason:forceLog:` 当场满足 Camera app active 且已请求 volume button events 为条件，延迟复核后发送 `libactivator.camera.ready`。
- Synthetic volume HID 发送前，SpringBoard 端只使用可直接访问的 `appsRegisteredForVolumeEvents.firstObject.bundleIdentifier == com.apple.camera` 作为保守 gate。
- 旧 `LAApplicationListener` 的普通 dynamic application listener 在 SpringBoard mode 下有 App object 即延迟调用 `activateApplication:` 并标记 handled；lockscreen mode 下旧实现只有非密码保护状态才解锁并标记 handled；application mode 下复用 `activateApplication:` 返回值，目标 App 等于当前前台 App 时返回未处理。当前 `LATApplicationActionListener` 对齐可见分支：缺少 descriptor 不消费，application mode 目标为当前 App 不消费，其他有 descriptor 的启动路径消费后异步提交；真实锁屏解锁/启动结果由 device-runtime 或手工验收覆盖。
- `libactivator.system.previous-app` 在 1.9.13 中是单独 `_LAPreviousApplicationListener`，不是 `_LASimpleListener` selector。1.9.13 `sub_BC8C` 先检查上一 App 全局状态，为空返回 false；存在时解析 App object 并复用 application base listener launch 路径。当前实现用 `LATRuntimeStateSource` O(1) 缓存最近打开 App 和前一个不同 App，再由 `LATSystemPreviousApplicationController` 打开目标 identifier；没有 runtime state、没有 previous identifier 或 launch enqueue 失败时不消费。

## Back 与键盘动作

- 1.9.13 的 `libactivator.system.back` 在 application mode 里设置状态并 post `libactivator.system.back` Darwin notification，真实 UIKit back 行为发生在旧 `com.apple.UIKit` 注入端。当前项目不恢复用户 App 注入；`system.back` 复刻可见分支：application mode 走现代 `local-back`，非 application mode 发 Home HID，menu single 触发时返回未处理。
- 现代 `libactivator.system.local-back` 使用 AX 元素实现 Voice Control “返回”近似语义，执行顺序是 back button trait `press`、Safari back title `press`、`performAction:2013` escape。
- Voice Control 关闭时，AXRuntime 会拒绝当前元素查询。当前实现会通过 `LAActivator` 私有 application accessibility 接口请求 SpringBoard 侧真实打开 application accessibility；该状态不会由 `local-back` 自动关闭，包卸载前通过隐藏 CLI `activator prerm` best-effort 关闭。
- 旧 master `voiceControl` 使用 `SBVoiceControlAlert`：pending/active alert 存在时 cancel 并返回 true，`shouldEnterVoiceControl` 成功时创建并 activate alert 后返回 true，否则返回 false。1.9.13 `voiceControl` `0x6d84` 仍是该旧 alert family 的 selector。当前现代实现不恢复旧 alert，而是按 AccessibilitySettings 证据切换系统 Voice Control：`_AXSCommandAndControlEnabled` / `_AXSCommandAndControlSetEnabled` 都可解析时消费，否则不消费。
- `libactivator.keyboard.dictation` 旧真实动作也依赖用户 App 注入。当前项目不恢复该注入；现代实现复用 AX 元素 helper：先用多语言“键盘/Keyboard/…”标题匹配停止入口，失败后再用 `0:` keyplane identifier 前缀加多语言“听写/Dictation/…”标题匹配启动入口。
