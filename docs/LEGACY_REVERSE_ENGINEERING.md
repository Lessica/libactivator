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

- Status bar 旧 master 有两条路径：SpringBoard 端 `SBStatusBar` 派发通用 statusbar tap/hold/swipe，UIKit everywhere 注入端 `UIStatusBar` 根据触摸起点划分 left/base/right。旧实现 single tap fallback 会把触摸传回系统状态栏，说明它尽量保留系统默认行为，不是在识别阶段直接吞掉触摸。
- 1.9.13 仍保留 `libactivator.statusbar.swipe.down` 兼容名，但它已属于 top slide / edge gesture family 的历史兼容事件。现代实现应保留该事件名，同时把完整 top slide / edge gesture family 单独实现。
- 1.9.13 中 `LAEventScreen*Swipe*` public constants 仍导出，但实际字符串指向 `libactivator.drag-along.*` namespace，不是 `libactivator.screen.*.swipe.*`。当前项目常量值必须按 1.9.13 映射到 `drag-along` 名称。
- Slide / drag 阈值结论：默认 edge band 约 `13pt`，slide-in 内移触发 rect 约 `63pt`，drag-along 移动阈值约 `30pt`，drag-off 结束边缘区约 `20pt`。当前实现直接对齐 1.9.13 阈值，只有真机验收证明需要时再调整。
- 当前项目不使用旧 `com.apple.UIKit` filter 注入用户 App。现代 status bar 点位在 SpringBoard 内多个 `UIStatusBar_Modern` 实例上处理，每个实例应拥有独立识别 session，避免旧全局状态在多实例状态栏下串扰。
- Force touch 由 1.9.13 的 `ActivatorSystemGestureRecognizer` 承载，事件名包括 statusbar、screen-left、screen-right、screen-bottom-left、screen-bottom、screen-bottom-right。旧实现读取 `UITouch.force`，不是直接读取 HID pressure；当前语义也应以 `UITouch.force` 为来源。
- Force touch 区域结论：`y < 38pt` 为 statusbar；底部 `38pt` 内按 `x` 四分位划分 bottom-left/bottom/bottom-right；非底部/状态栏区域中 `x < 14pt` 为 left，`x > width - 14pt` 为 right。阈值约 `5.0`，当前实现使用 `force >= 5.0` 作为可测试边界。

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
- `libactivator.system.soft-reboot` 当前从 staged resource 和 runtime allowlist 移除，后续需要非 SpringBoard helper 或合适 privileged execution path。
- `libactivator.system.powerdown` / `reboot` 使用 `SpringBoard.restartManager shutdownForReason:nil` / `rebootForReason:nil`。
- 旧 master 与 1.9.13 均显示多个 `activate-*` action 是 toggle：Control Center、Notification Center、Switcher、Reachability、Siri 等现代实现也应保留 toggle 语义。
- `libactivator.system.power-menu` 的现代有效入口是 `SBMainWorkspace.sharedInstance[IfExists] presentPowerDownTransientOverlay`。
- `libactivator.system.edit-screenshot` 语义是立即截图并进入编辑，优先 `_takeScreenshotAndEdit:`，fallback `takeScreenshotAndEdit:`，再 fallback 普通 `takeScreenshot`。
- `libactivator.system.safemode` 语义是主动制造 SpringBoard exception 以触发 loader Safe Mode，owner 已接受该行为。
- `libactivator.system.clear-switcher` 参考 QuitAll 的 iOS 15 `SBMainSwitcherViewController` 删除路径，并按 iOS 16+ `SBMainSwitcherControllerCoordinator` removal SPI 做现代实现；默认跳过 Now-Playing App。执行时先判断当前 App 和现有 switcher layouts，当前处于 Now-Playing App、switcher 为空或仅有 Now-Playing App 时不打开 App Switcher；否则先打开 App Switcher，再清理列表。该行为已通过真机验收。
- `libactivator.system.lock-and-wipe-credentials` 语义是锁屏并强制 biometric lockout，不是删除 passcode 或清除系统凭据。

## Compose、Phone 与 Camera

- `libactivator.mail.compose-message`、`libactivator.sms.compose-message`、`libactivator.notes.compose-note` 旧实现都使用临时 `UIWindow` presenter；当 compose UI 已存在时，再次触发会关闭当前 UI。当前 Mail/SMS 继续 runtime 加载 `MessageUI.framework`；Notes 旧 `Social.framework` / sharing extension 路径在现代 iOS 验证无效，不保留 fallback。
- Phone tab actions 旧实现内部打开 URL。当前实现按真机验证使用 `mobilephone-favorites:`、`mobilephone-recents:`、`mobilephone-contacts:`、`vmshow:`；`phone.keypad` 恢复旧 `mobilephone-recents:keypad` URL，但现代 iOS 需要只注入 `com.apple.mobilephone` 的 companion tweak 才能切到 keypad。
- `libactivator.phone.answer-call` 和 `disconnect-call` 的 1.9.13 resource metadata 都曾使用 selector `answerCall`。当前将 `disconnect-call` 规范化为 `disconnectCall`，并由 telephony listener 继续以 selector metadata gate 区分动作。
- `answer-call` 需要持久 CoreTelephony call state observer；单次读取 current calls 会出现首个来电可接、后续来电不可接但仍可挂断的问题。
- `libactivator.camera.invoke-shutter` 旧语义是先尝试相机快门，失败时打开 Camera 并等待 ready 后重试。当前现代实现拆成 SpringBoard listener 与只注入 Camera 的 companion tweak：锁屏状态优先 CoverSheet camera，非锁屏状态下只有当前前台为 `com.apple.camera` 时才直接发送 Consumer page `VolumeDecrement` HID。
- Camera ready 不能只相信 launch completion 或 `UIApplication setWantsVolumeButtonEvents:YES`。当前 companion tweak 以 `CAMViewfinderViewController -_updateEnabledControlsWithReason:forceLog:` 当场满足 Camera app active 且已请求 volume button events 为条件，延迟复核后发送 `libactivator.camera.ready`。
- Synthetic volume HID 发送前，SpringBoard 端只使用可直接访问的 `appsRegisteredForVolumeEvents.firstObject.bundleIdentifier == com.apple.camera` 作为保守 gate。
- `libactivator.system.previous-app` 在 1.9.13 中是单独 `_LAPreviousApplicationListener`，不是 `_LASimpleListener` selector。当前实现用 `LATRuntimeStateSource` O(1) 缓存最近打开 App 和前一个不同 App，再由 `LATSystemPreviousApplicationController` 打开目标 identifier。

## Back 与键盘动作

- 1.9.13 的 `libactivator.system.back` 在 application mode 里设置状态并 post `libactivator.system.back` Darwin notification，真实 UIKit back 行为发生在旧 `com.apple.UIKit` 注入端。当前项目不恢复用户 App 注入；`system.back` 复刻可见分支：application mode 走现代 `local-back`，非 application mode 发 Home HID，menu single 触发时返回未处理。
- 现代 `libactivator.system.local-back` 使用 AX 元素实现 Voice Control “返回”近似语义，执行顺序是 back button trait `press`、Safari back title `press`、`performAction:2013` escape。
- Voice Control 关闭时，AXRuntime 会拒绝当前元素查询。当前实现会通过 `LAActivator` 私有 application accessibility 接口请求 SpringBoard 侧真实打开 application accessibility；该状态不会由 `local-back` 自动关闭，包卸载前通过隐藏 CLI `activator prerm` best-effort 关闭。
- `libactivator.keyboard.dictation` 旧真实动作也依赖用户 App 注入。当前项目不恢复该注入；现代实现复用 AX 元素 helper：先用多语言“键盘/Keyboard/…”标题匹配停止入口，失败后再用 `0:` keyplane identifier 前缀加多语言“听写/Dictation/…”标题匹配启动入口。
