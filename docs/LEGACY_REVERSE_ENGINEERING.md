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

## `libactivator.audio.launch-playing-app`

1.9.13 中该 listener name 对应 `_LANowPlayingApplicationListener`，关键方法是 `-applicationForListenerName:`。解混淆后的引用可以看到 `_LANowPlayingApplicationListener`、`nowPlayingApplication`、`SBMediaController`、`SBApplicationController`、`com.apple.Music` 和 `libactivator.audio.launch-playing-app`。

旧实现语义是先取 `SBMediaController.sharedInstance`，如果它能响应并返回 `nowPlayingApplication`，则使用这个 now-playing application。若没有可用 now-playing application，则 fallback 到 `SBApplicationController.sharedInstance`，按 CoreFoundation 版本选择 `applicationWithDisplayIdentifier:` 或 `applicationWithBundleIdentifier:`，传入固定 bundle id `com.apple.Music`。

现代实现不能把这个 fallback 直接当成目标语义照搬。旧 fallback 是“无法确认 now-playing app 时打开 Music”的兼容行为，但当前项目的设计边界是不使用静态 Music fallback 伪装 now-playing identity。真机 Frida 验证显示，现代 iOS 上 `SBMediaController nowPlayingApplication` 可以返回 `nil`，但 `MRMediaRemoteGetNowPlayingApplicationDisplayID` 能回调真实 display identifier，例如 `com.apple.Music`；`MRMediaRemoteGetNowPlayingApplicationPID` 也能返回 now-playing PID，并可用 `SBSCopyDisplayIdentifierForProcessID` 转换为 display identifier。因此当前实现不保留 `SBMediaController` 路径，改用 MediaRemote display id 优先、PID + SpringBoardServices fallback 的 identity provider，再交给 SpringBoard 私有打开路径；如果没有 now-playing identity，listener 仍消费事件并记录诊断，但不打开静态 fallback。

## `libactivator.ipod.music-controls`

1.9.13 中 `musicControls` 是 `_LASimpleListener` 上的旧 selector。解混淆后的实现引用了 `SBNowPlayingAlertItem`、`SBAlertItemsController` 和 `SBMediaController`。

旧实现大意是：如果 `SBNowPlayingAlertItem` 已经显示，则通过 `SBAlertItemsController` 关闭；否则在可显示 now-playing UI 的条件下创建并激活一个 `SBNowPlayingAlertItem`。若该 UI 路径不可用，则退回到打开 now-playing application / Music fallback 的路径。

这个语义依赖旧 SpringBoard 的 now-playing alert modal。现代 iOS 已没有对应的 `SBNowPlayingAlertItem` 用户体验，用户可见的等价入口更接近 Control Center 的 Now Playing 模块。把 `libactivator.ipod.music-controls` 实现成“打开 Control Center”会改变旧 action 的含义，也属于系统 UI family 的另一个产品决策。因此当前将该动作标记为 `obsolete`，不作为 Audio / Media listener family 的待实现项。

## Phone actions

旧 master 的 `_LASimpleListener` 中包含 5 个 Phone tab selector：`showPhoneFavorites`、`showPhoneRecents`、`showPhoneContacts`、`showPhoneKeypad`、`showPhoneVoicemail`。这些动作没有 `url` metadata，但旧实现内部直接调用 SpringBoard `applicationOpenURL:publicURLsOnly:`；CoreFoundation 版本小于 675 时使用 `doubletap://com.apple.mobilephone?view=...`，675 及之后使用 `mobilephone-recents:favorites`、`mobilephone-recents:`、`mobilephone-recents:contacts`、`mobilephone-recents:keypad` 和 `vmshow:`。当前实现不照搬旧 tab URL，而是按真机验证结果使用 `mobilephone-favorites:`、`mobilephone-recents:`、`mobilephone-contacts:`、`mobilephone-keypad:`，voicemail 继续使用 `vmshow:`；打开路径通过 `LSApplicationWorkspace openSensitiveURL:withOptions:error:` 在非主队列提交。

1.9.13 资源中 `libactivator.phone.answer-call` 和 `libactivator.phone.disconnect-call` 的 selector metadata 都是 `answerCall`。当前保持这个历史资源形状，不修改 metadata；runtime 由 listener name 分派到不同 call control 行为。`answer-call` 参考 `TRAppIntentXpcServiceConnection.mm`，通过项目内私有 `CTCall.h` 副本和 `CoreTelephony.framework` 链接枚举当前 calls，查找 `kCTCallStatusIncomingCall` 并调用 `CTCallAnswer`。`disconnect-call` 使用同一参考中的“terminate any calls”路径，调用 `CTCallListDisconnectAll` 来覆盖活动通话和来电拒接场景。
