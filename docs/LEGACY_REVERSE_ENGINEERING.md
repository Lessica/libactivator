# 旧版逆向记录

本文记录需要反复引用的 1.9.13 旧实现证据。它不是实现计划；实现计划仍以 `BUILT_IN_ROADMAP.md` 和 `BUILT_IN_ACTION_TRACKER.md` 为准。

## ActivatorSpringBoard 解混淆记录

当前参考输入是 `references/latest/Library/Activator/ActivatorSpringBoard.bundle/ActivatorSpringBoard`。该 Mach-O 是 universal binary，包含 armv6、arm64、arm64e slice；本次分析使用 arm64 slice。已解混淆二进制和 IDA 数据库保存在 `references/latest/analysis/ActivatorSpringBoard/`，该目录只作为本地参考快照复用，不提交到仓库。

`LC_ENCRYPTION_INFO_64` 中的 `cryptid` 为 `0`，因此这里处理的不是 FairPlay 加密，而是 Activator 自己对字符串和 ObjC metadata 做的混淆。未处理的二进制中，`__objc_classname`、`__objc_methname`、`__objc_methtype` 和 `__cstring` 的关键内容不可直接用 strings / IDA 识别。

可复现的处理步骤如下：

```sh
lipo -thin arm64 references/latest/Library/Activator/ActivatorSpringBoard.bundle/ActivatorSpringBoard -output references/latest/analysis/ActivatorSpringBoard/ActivatorSpringBoard.arm64
otool -l references/latest/analysis/ActivatorSpringBoard/ActivatorSpringBoard.arm64 | rg -C 3 'LC_ENCRYPTION|crypt'
```

对比已解混淆产物 `references/latest/analysis/ActivatorSpringBoard/ActivatorSpringBoard.arm64.decrypted` 可见两段连续区域发生变化：`0x3f3e1..0x47ab2` 覆盖 ObjC class / method / type metadata，`0x49ab1..0x50719` 覆盖 `__cstring`。这两段使用相同的滚动 XOR 规则，分别以 `0x72` 作为初始 `previous` 值：

```c
uint8_t previous = 0x72;
for (uint64_t offset = rangeStart; offset < rangeEnd; offset++) {
    uint8_t plain = data[offset] ^ previous;
    data[offset] = plain;
    previous = plain;
}
```

该规则可以由 `0x3f3e1` 起始处验证：原始字节 `0x33` 与 seed `0x72` 异或得到 `A`，下一字节 `0x22` 与上一明文字节 `A` 异或得到 `c`，解出的开头为 `ActivatorSlideGestureRecognizer`。明文字节为 NUL 时，下一密文字节等于上一明文字节，这也符合滚动 previous-plaintext XOR。

解混淆后再用 IDA 分析 `references/latest/analysis/ActivatorSpringBoard/ActivatorSpringBoard.arm64.decrypted.i64`。后续引用旧实现时，应说明证据来自这个解混淆后的本地分析产物，避免把原始混淆二进制中的缺失字符串误判为旧版没有实现。

## Status bar gestures

旧 master 中状态栏触摸分为两条路径：SpringBoard 端 `Events.x` hook `SBStatusBar`，只能派发通用 `libactivator.statusbar.tap.single`、`tap.double`、`hold`、`swipe.left`、`swipe.right`、`swipe.down`；UIKit everywhere 注入端 `EverywhereHooks.x` hook `UIStatusBar`，按触摸起点的 `x < width * 0.25`、`width * 0.25 <= x < width * 0.75`、`x >= width * 0.75` 分别派发 left、base、right 的 tap/hold/double-tap 事件。旧阈值来自 `references/master/Constants.h`：hold delay `0.5` 秒，single tap delay `0.33` 秒，horizontal swipe threshold `50.0pt`，vertical swipe threshold `10.0pt`；移动方向使用 `deltaX^2 > deltaY^2` 决定横向优先还是纵向优先。

旧 master 的 `EverywhereHooks.x` 在 `touchesBegan:` 中启动 hold timer 并记录起点；`touchesMoved:` 会取消 hold/tap timer，达到横向阈值时派发 `statusbar.swipe.right/left`，达到向下纵向阈值时在旧 CoreFoundation 版本下派发 `statusbar.swipe.down`；`touchesEnded:` 中 `tapCount == 2` 立即派发 double tap，否则延迟 `0.33` 秒派发 single tap。该 hook 在 single tap fallback 中通过 `passThroughStatusBar` 重新调用一次 `touchesBegan:` 并继续 `%orig`，说明旧实现也尽量保留系统状态栏默认行为，而不是在事件识别阶段直接吞掉触摸。

1.9.13 的解混淆 `ActivatorSpringBoard` 中仍可见 `ActivatorSlideGestureRecognizer`、`ActivatorSystemGestureRecognizer`、`UIStatusBarWindow`、`UIStatusBar`、`SBOffscreenSwipeGestureRecognizer`、`libactivator.statusbar.swipe.down` 和 `libactivator.statusbar.` 前缀。IDA 中 `UIStatusBar initWithFrame:showForegroundView:` 的 replacement 会在原始初始化后创建并 `addGestureRecognizer:` 一个 recognizer；`UIStatusBarWindow initWithFrame:` 在存在 `SBOffscreenSwipeGestureRecognizer` 时也会向 window 加 recognizer。`libactivator.statusbar.swipe.down` 的 xref 落在 slide/edge gesture 计算逻辑，符合 public header 中 “Now a slide in gesture on iOS5.0+; extern and name kept for backwards compatibility” 的注释。因此现代实现应把 `statusbar.swipe.down` 当作历史兼容事件保留，但完整 top slide / edge gesture family 应单独实现。

1.9.13 中 screen-side swipe public constants 是旧 API 名称保留，但实际字符串已更名到 `drag-along` event namespace，而不是新增一套 `screen.*.swipe.*` 事件。证据来自 `references/latest/package/usr/lib/libactivator.dylib` arm64 slice：导出符号 `_LAEventScreenBottomSwipeLeft` 到 `_LAEventScreenRightSwipeUp` 仍存在，`__TEXT,__cstring` 中不存在 `libactivator.screen.*.swipe.*` 字符串，只存在 `libactivator.drag-along.*`；`__DATA_CONST,__const` 中这些 symbol 依次指向 `libactivator.drag-along.screen-bottom.right-to-left`、`libactivator.drag-along.screen-bottom.left-to-right`、`libactivator.drag-along.screen-left.top-to-bottom`、`libactivator.drag-along.screen-left.bottom-to-top`、`libactivator.drag-along.screen-right.top-to-bottom` 和 `libactivator.drag-along.screen-right.bottom-to-top`。因此当前项目的 `LAEventScreen*Swipe*` 常量值必须以 1.9.13 为准映射到 `drag-along` 名称，不能保留旧推测的 `libactivator.screen.*.swipe.*`。

当前项目不使用旧 `com.apple.UIKit` filter 注入用户 App 进程。现代 iOS 目标点位改为 SpringBoard 进程内多个 `UIStatusBar_Modern` 实例：主屏幕、锁屏和前台 App 界面各自可能有独立实例。实现时应在 SpringBoard tweak 内 hook `UIStatusBar_Modern` 的 touch 方法，并让每个 status bar view 实例拥有独立识别 session，避免旧 master 的全局状态在多实例现代状态栏下串扰。

## `libactivator.audio.launch-playing-app`

1.9.13 中该 listener name 对应 `_LANowPlayingApplicationListener`，关键方法是 `-applicationForListenerName:`。解混淆后的引用可以看到 `_LANowPlayingApplicationListener`、`nowPlayingApplication`、`SBMediaController`、`SBApplicationController`、`com.apple.Music` 和 `libactivator.audio.launch-playing-app`。

旧实现语义是先取 `SBMediaController.sharedInstance`，如果它能响应并返回 `nowPlayingApplication`，则使用这个 now-playing application。若没有可用 now-playing application，则 fallback 到 `SBApplicationController.sharedInstance`，按 CoreFoundation 版本选择 `applicationWithDisplayIdentifier:` 或 `applicationWithBundleIdentifier:`，传入固定 bundle id `com.apple.Music`。

现代实现不能把这个 fallback 直接当成目标语义照搬。旧 fallback 是“无法确认 now-playing app 时打开 Music”的兼容行为，但当前项目的设计边界是不使用静态 Music fallback 伪装 now-playing identity。真机 Frida 验证显示，现代 iOS 上 `SBMediaController nowPlayingApplication` 可以返回 `nil`，但 `MRMediaRemoteGetNowPlayingApplicationDisplayID` 能回调真实 display identifier，例如 `com.apple.Music`；`MRMediaRemoteGetNowPlayingApplicationPID` 也能返回 now-playing PID，并可用 `SBSCopyDisplayIdentifierForProcessID` 转换为 display identifier。因此当前实现不保留 `SBMediaController` 路径，改用 MediaRemote display id 优先、PID + SpringBoardServices fallback 的 identity provider，再交给 SpringBoard 私有打开路径；如果没有 now-playing identity，listener 仍消费事件并记录诊断，但不打开静态 fallback。

## `libactivator.ipod.music-controls`

1.9.13 中 `musicControls` 是 `_LASimpleListener` 上的旧 selector。解混淆后的实现引用了 `SBNowPlayingAlertItem`、`SBAlertItemsController` 和 `SBMediaController`。

旧实现大意是：如果 `SBNowPlayingAlertItem` 已经显示，则通过 `SBAlertItemsController` 关闭；否则在可显示 now-playing UI 的条件下创建并激活一个 `SBNowPlayingAlertItem`。若该 UI 路径不可用，则退回到打开 now-playing application / Music fallback 的路径。

这个语义依赖旧 SpringBoard 的 now-playing alert modal。现代 iOS 已没有对应的 `SBNowPlayingAlertItem` 用户体验，用户可见的等价入口更接近 Control Center 的 Now Playing 模块。把 `libactivator.ipod.music-controls` 实现成“打开 Control Center”会改变旧 action 的含义，也属于系统 UI family 的另一个产品决策。因此当前将该动作标记为 `obsolete`，不作为 Audio / Media listener family 的待实现项。

## Phone actions

旧 master 的 `_LASimpleListener` 中包含 5 个 Phone tab selector：`showPhoneFavorites`、`showPhoneRecents`、`showPhoneContacts`、`showPhoneKeypad`、`showPhoneVoicemail`。这些动作没有 `url` metadata，但旧实现内部直接调用 SpringBoard `applicationOpenURL:publicURLsOnly:`；CoreFoundation 版本小于 675 时使用 `doubletap://com.apple.mobilephone?view=...`，675 及之后使用 `mobilephone-recents:favorites`、`mobilephone-recents:`、`mobilephone-recents:contacts`、`mobilephone-recents:keypad` 和 `vmshow:`。当前实现不照搬旧 tab URL，而是按真机验证结果使用 `mobilephone-favorites:`、`mobilephone-recents:`、`mobilephone-contacts:`，voicemail 继续使用 `vmshow:`；`libactivator.phone.keypad` 已确认失效且无可替代 URL，已从资源和 allowlist 移除。打开路径通过 `LSApplicationWorkspace openSensitiveURL:withOptions:error:` 在非主队列提交。

1.9.13 资源中 `libactivator.phone.answer-call` 和 `libactivator.phone.disconnect-call` 的 selector metadata 都是 `answerCall`。这会让两个不同动作在资源层共享同一 selector，当前已将 `disconnect-call` 规范化为 `disconnectCall`，并让 telephony listener 继续以 selector metadata gate 区分动作。`answer-call` 参考 `TRAppIntentXpcServiceConnection.mm`，通过项目内私有 `CTCall.h` 副本和 `CoreTelephony.framework` 链接枚举当前 calls，查找 `kCTCallStatusIncomingCall` 并调用 `CTCallAnswer`。`disconnect-call` 使用同一参考中的“terminate any calls”路径，调用 `CTCallListDisconnectAll` 来覆盖活动通话和来电拒接场景。

`libactivator.phone.answer-call` 出现首个来电可接、后续来电不可接但仍可挂断后，重新对比了 `TRAppIntentXpcServiceConnection.mm` 与 `TRAppIntentXpcServiceTelephonyCenter.mm`。参考项目的 answer 方法本身同样在 main queue 中调用 `CTGetCurrentCallCount`、`CTCopyCurrentCalls`、逐个检查 `CTCallGetStatus(call) == kCTCallStatusIncomingCall`，然后调用 `CTCallAnswer(call)`；但同一服务还存在一个持久的 `CTTelephonyCenter` observer，订阅 `kCTCallStatusChangeNotification` 和 `kCTCallIdentificationChangeNotification`。由于 answer 依赖当前 incoming `CTCallRef`，而 disconnect 使用全局 `CTCallListDisconnectAll()`，漏掉 observer 会导致“后续 answer 依赖的 current calls / status 没有刷新，但 disconnect 仍可用”的表现。当前 `LATTelephonyActionListener` 已补齐 `LATTelephonyCallStateObserver`，在 listener 生命周期内持续接收 CoreTelephony call 状态变化，并保留 call count、copied call object count、call status/type/address 与 answer request 诊断日志。

## Back actions

旧 master 源码没有 `libactivator.system.local-back`，但 1.9.13 的 `ActivatorSpringBoard` 二进制中 `_LASimpleListener` 同时实现了 `-goBackWithActivator:event:` 和 `-localBack`。资源层 `libactivator.system.back` 使用 selector `goBackWithActivator:event:`，`libactivator.system.local-back` 使用 selector `localBack`。SpringBoard 端 `-goBackWithActivator:event:` 在 application mode 下设置 back 状态并 `notify_post("libactivator.system.back")`；`-localBack` 设置 local-back 状态后也 post 同一个 Darwin notification。真正的 UIKit back 行为在被注入到 App 进程的 `/usr/lib/libactivator.dylib` 中执行：1.9.13 的 `Activator.plist` 使用 `com.apple.UIKit` filter，App 端注册 `libactivator.system.back` Darwin notification，收到后从 `UIApp.keyWindow.rootViewController` 开始递归处理 presented / child view controllers，必要时调用 `dismissViewControllerAnimated:completion:`，最后在 `UINavigationController` 且 `viewControllers.count >= 2` 时调用 `popViewControllerAnimated:YES`。因此 Back / Local Back family 违反本项目“不注入用户 App 进程”的基本约束；当前只保留逆向记录和资源 metadata，不进入实现阶段，也不应以 HID `Menu`、keyboard Escape 或其他近似输入事件替代。
