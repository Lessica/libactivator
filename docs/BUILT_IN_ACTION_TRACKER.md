# 内置动作跟踪表

本表跟踪 built-in listeners/actions 的具体实现事项。它回答“是什么、为什么要做、依据来自哪里、当前状态如何”，不替代 `BUILT_IN_ROADMAP.md` 的阶段顺序。

## 规则

- `listener` 在 Activator 语义里通常就是 action executor：它是被 assignment 选中的响应器，也是实际完成动作的主体。
- 同一个 listener class 可以注册到多个 listener name。name 决定元数据、标题、分组、URL 或 selector；class 决定运行时行为。
- metadata presence 不等于已实现。只有注册了真实 `LAListener` object 的 name 才能进入 `availableListenerNames` 并处理事件。
- 1.9.13 资源 catalog 是当前内置动作范围的主要依据；旧 master 只用于证明历史承载方式和语义，不用于照搬实现。
- 状态值：`metadata-only` 表示只有资源；`candidate` 表示可进入当前阶段评估；`in-progress` 表示正在实现；`implemented` 表示已有行为和测试；`blocked` 表示需要 owner 或 SPI 决策；`obsolete` 表示不计划恢复。

## 阶段结论

URL actions / listener family 已完成。当前 `LATURLActionListener` 注册 44 个带 `url` 或 `urls` metadata 的 Clock / Settings URL action，并承载 5 个 hardcoded Phone tab URL action。Phone tab action 没有 `url` metadata，仍通过 selector metadata gate 校验资源形状，runtime URL 由代码 allowlist 提供。8 个经真机验证失效、重复或只打开错误页面的旧 URL action 已从资源和 allowlist 移除：`libactivator.clock.bedtime`、`libactivator.settings.brightness`、`libactivator.settings.brightness-and-wallpaper`、`libactivator.settings.equalizer`、`libactivator.settings.facebook`、`libactivator.settings.network`、`libactivator.settings.twitter`、`libactivator.settings.usage`。

URL family 的实现边界已固定：注册 name 仍由代码 allowlist 决定；metadata lookup 同时支持 `Listeners/bundled.plist` 和目录式 `Listeners/<name>/Info.plist`；真实打开通过 `LSApplicationWorkspace openSensitiveURL:withOptions:error:` 在专用非主队列提交，`event.handled = YES` 表示 action request 已被 listener 接受并提交，不表示目标 App 已完成打开。这与旧 master 中 `applicationOpenURL:publicURLsOnly:` 后立即返回 `YES` 的语义一致。

Hardware actions / listener family 已从旧 Media family 中拆出。当前 `LATHardwareActionListener` 承载 7 个 HID Consumer page 播放/音量硬件键、`libactivator.system.take-screenshot` 的 Consumer `Snapshot`、`libactivator.system.spotlight` 的 Consumer `ACSearch`，以及 `libactivator.system.vibrate` 的硬件振动反馈。HID 动作通过 `IOHIDEventCreateKeyboardEvent` 与 `IOHIDEventSystemClientDispatchEvent` 提交；vibrate 使用 `AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)`；`event.handled = YES` 表示 action request 已被 listener 接受并提交，不表示系统 UI 或目标应用已经完成状态变化。`SBScreenShotter` 已确认在现代 iOS 不可用，因此截图不走旧 master 的 `SBScreenShotter saveScreenshot:` 路径。

System actions / listener family 已用于承载非 URL、非 HID、但低风险且接口明确的系统服务动作。当前 `LATSystemActionListener` 包含 volume HUD、now-playing application launch、ringer state sync、ringer mute/unmute/toggle、SBS first SpringBoard page。实现边界已固定：注册 name 仍由代码 allowlist 决定；metadata lookup 用于 selector 或 title metadata gate；volume/ringer 动作通过 tweak hook 缓存在 `LATBuiltInListenerRegistry` 中的 `SBVolumeControl` / `SBRingerControl` 原进程对象执行；ringer reset 按 1.9.13 旧实现通过 `BKSHIDServicesGetRingerState` 与 SpringBoard `-_updateRingerState:withVisuals:updatePreferenceRegister:` 同步；first-page 使用 `SBSServiceFacilityClient` checkout `SBSSystemServiceClient` 后调用 `resetToHomeScreenAnimated:`。

Telephony actions / listener family 现在只承载通话控制。`LATTelephonyActionListener` 包含 2 个 call control 动作：`answer-call` 和 `disconnect-call`；Phone tab URL 已按执行机制并入 `LATURLActionListener`。Call control 动作参考 `TRAppIntentXpcServiceConnection.mm` 中已验证的 CoreTelephony 路径，tweak 使用项目内私有 `CTCall.h` 副本并链接 `CoreTelephony.framework`，在主队列异步执行通话控制。`libactivator.phone.disconnect-call` 的 selector metadata 仍按 1.9.13 资源保持为 `answerCall`，runtime 行为由 listener name 区分。`event.handled = YES` 表示 telephony listener 已消费请求，不表示电话状态已完成变化。

下一阶段应继续处理低风险 system selector actions，但 listener 划分应优先按执行机制决定：URL action 归 `LATURLActionListener`，HID Consumer action 归 `LATHardwareActionListener`，SpringBoard/system-service action 归 `LATSystemActionListener`，通话控制归 `LATTelephonyActionListener`。

## 已实现动作

| Listener name / family | 动作 | 承载实体 | 依据 | 状态 | 说明 |
| --- | --- | --- | --- | --- | --- |
| `libactivator.system.nothing` | 不执行操作，吞掉原始动作 | `LATNothingListener` | 1.9.13 `Listeners/bundled.plist`；旧 master `LASimpleListener -doNothing` | `implemented` | 已由 `LATBuiltInListenerRegistry` 注册，stable `BuiltInActionRegistry` 覆盖 dispatch 后 `event.handled = YES`。 |
| URL actions family | Clock、Settings、Phone tab URL actions | `LATURLActionListener` | 1.9.13 `Listeners/bundled.plist` 中保留的 `url` / `urls` metadata；旧 master `LASimpleListener -openURLWithActivator:event:listenerName:`；真机验证后的 `mobilephone-*:` URL | `implemented` | 44 个 metadata URL 项和 5 个 hardcoded Phone tab URL 项已注册；stable `BuiltInURLActions` 覆盖 metadata URL 与 hardcoded selector-gated URL。 |
| Hardware actions family | HID Consumer 播放、音量、截图、Spotlight、vibrate | `LATHardwareActionListener` | `STHIDEventGenerator.mm` 的 HID Consumer event 发送方式；IOHID usage table 中 `Snapshot` / `ACSearch` usage；`AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)` | `implemented` | 10 个 hardware action 项已注册；stable `BuiltInHardwareActions` 覆盖 allowlist、selector metadata 和 runtime registration。 |
| System actions family | Volume HUD、当前播放应用、ringer、first page | `LATSystemActionListener` | 真机 Frida 验证的 `SBVolumeControl -_presentVolumeHUDWithVolume:`；1.9.13 ringer reset 与 now-playing launch 逆向结论；`SBSSystemServiceClient resetToHomeScreenAnimated:` | `implemented` | 7 个 system-service 项已注册；stable `BuiltInSystemActions` 覆盖 allowlist、selector/title metadata 和 runtime registration。 |
| Telephony actions family | 接听来电、挂断活动或来电 | `LATTelephonyActionListener` | 1.9.13 `Listeners/bundled.plist` 中 selector metadata；`TRAppIntentXpcServiceConnection.mm` 中 CoreTelephony call control 路径 | `implemented` | 2 个 call control 项已注册；Phone tab URL 已移至 URL family；stable `BuiltInTelephonyActions` 覆盖 allowlist、selector metadata 和 runtime registration。 |

## URL Actions 完成清单

| Listener name | 分组 | 标题 | 状态 | URL metadata | 验证 |
| --- | --- | --- | --- | --- | --- |
| `libactivator.clock.alarm` | Clock | Alarm | `implemented` | `clock-alarm:default` | ✅ |
| `libactivator.clock.stopwatch` | Clock | Stopwatch | `implemented` | `clock-stopwatch:default` | ✅ |
| `libactivator.clock.timer` | Clock | Timer | `implemented` | `clock-timer:default` | ✅ |
| `libactivator.clock.world-clock` | Clock | World Clock | `implemented` | `clock-worldclock:default` | ✅ |
| `libactivator.settings.about` | Settings | About | `implemented` | `prefs:root=General&path=About` | ✅ |
| `libactivator.settings.accessibility` | Settings | Accessibility | `implemented` | `prefs:root=ACCESSIBILITY` | ✅ |
| `libactivator.settings.auto-lock` | Settings | Auto-Lock | `implemented` | `prefs:root=General&path=AUTOLOCK` | ✅ |
| `libactivator.settings.background-app-refresh` | Settings | Background App Refresh | `implemented` | `prefs:root=General&path=AUTO_CONTENT_DOWNLOAD` | ✅ |
| `libactivator.settings.battery` | Settings | Battery | `implemented` | `prefs:root=BATTERY_USAGE` | ✅ |
| `libactivator.settings.bluetooth` | Settings | Bluetooth | `implemented` | `prefs:root=General&path=Bluetooth`<br>`700`<br>`prefs:root=Bluetooth` | ✅ |
| `libactivator.settings.carplay` | Settings | Carplay | `implemented` | `prefs:root=General&path=CARPLAY` | ✅ |
| `libactivator.settings.cellular` | Settings | Cellular | `implemented` | `prefs:root=General&path=MOBILE_DATA_SETTINGS_ID`<br>`1000`<br>`prefs:root=MOBILE_DATA_SETTINGS_ID` | ✅ |
| `libactivator.settings.control-center` | Settings | Control Center | `implemented` | `prefs:root=ControlCenter` | ✅ |
| `libactivator.settings.date-time` | Settings | Date & Time | `implemented` | `prefs:root=General&path=DATE_AND_TIME` | ✅ |
| `libactivator.settings.display` | Settings | Display & Brightness | `implemented` | `prefs:root=DISPLAY` | ✅ |
| `libactivator.settings.do-not-disturb` | Settings | Do Not Disturb | `implemented` | `prefs:root=DO_NOT_DISTURB` | ✅ |
| `libactivator.settings.facetime` | Settings | FaceTime | `implemented` | `prefs:root=FACETIME` | ✅ |
| `libactivator.settings.game-center` | Settings | Game Center | `implemented` | `prefs:root=GAMECENTER` | ✅ |
| `libactivator.settings.general` | Settings | General | `implemented` | `prefs:root=General` | ✅ |
| `libactivator.settings.handoff` | Settings | Handoff | `implemented` | `prefs:root=General&path=CONTINUITY_SPEC` | ✅ |
| `libactivator.settings.icloud` | Settings | iCloud | `implemented` | `prefs:root=CASTLE` | ✅ |
| `libactivator.settings.international` | Settings | Language & Region | `implemented` | `prefs:root=General&path=INTERNATIONAL` | ✅ |
| `libactivator.settings.keyboard` | Settings | Keyboard | `implemented` | `prefs:root=General&path=Keyboard` | ✅ |
| `libactivator.settings.location-services` | Settings | Location Services | `implemented` | `prefs:root=LOCATION_SERVICES` | ✅ |
| `libactivator.settings.mail` | Settings | Mail, Contacts, Calendars | `implemented` | `prefs:root=ACCOUNT_SETTINGS` | ✅ |
| `libactivator.settings.managed-configuration` | Settings | Profiles & Device Management | `implemented` | `prefs:root=General&path=ManagedConfigurationList` | ✅ |
| `libactivator.settings.maps` | Settings | Maps | `implemented` | `prefs:root=MAPS` | ✅ |
| `libactivator.settings.messages` | Settings | Messages | `implemented` | `prefs:root=MESSAGES` | ✅ |
| `libactivator.settings.music` | Settings | Music | `implemented` | `prefs:root=MUSIC` | ✅ |
| `libactivator.settings.notes` | Settings | Notes | `implemented` | `prefs:root=NOTES` | ✅ |
| `libactivator.settings.notifications` | Settings | Notifications | `implemented` | `prefs:root=NOTIFICATIONS_ID` | ✅ |
| `libactivator.settings.passcode` | Settings | Touch ID & Passcode | `implemented` | `prefs:root=PASSCODE` | ✅ |
| `libactivator.settings.phone` | Settings | Phone | `implemented` | `prefs:root=Phone` | ✅ |
| `libactivator.settings.photos` | Settings | Photos | `implemented` | `prefs:root=Photos` | ✅ |
| `libactivator.settings.privacy` | Settings | Privacy | `implemented` | `prefs:root=Privacy` | ✅ |
| `libactivator.settings.reminders` | Settings | Reminders | `implemented` | `prefs:root=REMINDERS` | ✅ |
| `libactivator.settings.safari` | Settings | Safari | `implemented` | `prefs:root=Safari`<br>`1240`<br>`prefs:root=SAFARI` | ✅ |
| `libactivator.settings.sounds` | Settings | Sounds | `implemented` | `prefs:root=Sounds` | ✅ |
| `libactivator.settings.store` | Settings | Store | `implemented` | `prefs:root=STORE` | ✅ |
| `libactivator.settings.tethering` | Settings | Personal Hotspot | `implemented` | `prefs:root=INTERNET_TETHERING` | ✅ |
| `libactivator.settings.virtual-assistant` | Settings | Siri | `implemented` | `prefs:root=General&path=Assistant`<br>`1240`<br>`prefs:root=General&path=SIRI` | ✅ |
| `libactivator.settings.vpn` | Settings | VPN | `implemented` | `prefs:root=VPN` | ✅ |
| `libactivator.settings.wallpaper` | Settings | Wallpaper | `implemented` | `prefs:root=Wallpaper` | ✅ |
| `libactivator.settings.wifi` | Settings | Wi-Fi | `implemented` | `prefs:root=WIFI` | ✅ |

## Hardware Actions 完成清单

| Listener name | 标题 | 旧 selector / 语义 | 状态 | 实施备注 |
| --- | --- | --- | --- | --- |
| `libactivator.ipod.toggle-playback` | Play/Pause | `togglePlayback` | `implemented` | HID Consumer `PlayOrPause`。 |
| `libactivator.ipod.pause-playback` | Pause | `pauseMedia` | `implemented` | HID Consumer `Pause`。 |
| `libactivator.ipod.resume-playback` | Play | `playMedia` | `implemented` | HID Consumer `Play`。 |
| `libactivator.ipod.next-track` | Next Track | `nextTrack` | `implemented` | HID Consumer `ScanNextTrack`。 |
| `libactivator.ipod.previous-track` | Previous Track | `previousTrack` | `implemented` | HID Consumer `ScanPreviousTrack`。 |
| `libactivator.audio.increase-volume` | Volume Up | `increaseVolume` | `implemented` | HID Consumer `VolumeIncrement`；metadata 的 exclusive assignment group 继续由 resource lookup 提供。 |
| `libactivator.audio.decrease-volume` | Volume Down | `decreaseVolume` | `implemented` | HID Consumer `VolumeDecrement`；metadata 的 exclusive assignment group 继续由 resource lookup 提供。 |
| `libactivator.system.take-screenshot` | Take Screenshot | `takeScreenshot` | `implemented` | HID Consumer `Snapshot`；`SBScreenShotter` 已确认在现代 iOS 不可用。 |
| `libactivator.system.spotlight` | Spotlight | `spotlight` | `implemented` | HID Consumer `ACSearch`，对应外接键盘搜索键。 |
| `libactivator.system.vibrate` | Vibrate | `vibrate` | `implemented` | 使用 `AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)`。 |
| `libactivator.ipod.music-controls` | Music Controls | `musicControls` | `obsolete` | 1.9.13 通过 `SBNowPlayingAlertItem` / `SBAlertItemsController` 显示或关闭旧式 now-playing modal；现代 iOS 没有等价 UI，若要打开 Control Center 应作为新的系统 UI action family 决策，不复刻为本 listener。详见 `LEGACY_REVERSE_ENGINEERING.md`。 |

## System Actions 完成清单

| Listener name | 标题 | selector / 语义 | 状态 | 实施备注 |
| --- | --- | --- | --- | --- |
| `libactivator.audio.show-volume-bar` | Show Volume Bar | `showVolumeBar` | `implemented` | 现代实现不再使用旧 App Switcher 音量滑块；通过 hook `SBVolumeControl` init 捕获实例，并调用 `-_presentVolumeHUDWithVolume:` 显示系统音量 HUD。 |
| `libactivator.audio.launch-playing-app` | Launch Playing App | 无 selector metadata | `implemented` | 1.9.13 使用 `SBMediaController nowPlayingApplication`，并在缺少 now-playing app 时 fallback 到静态 `com.apple.Music`。现代实现不保留 `SBMediaController` 路径，也不复刻静态 Music fallback；改用 Frida 真机验证的 `MRMediaRemoteGetNowPlayingApplicationDisplayID`，必要时通过 `MRMediaRemoteGetNowPlayingApplicationPID` + `SBSCopyDisplayIdentifierForProcessID` 解析真实 display identifier，再交给 SpringBoard 私有打开路径。缺少 identity 或打开失败时仍消费事件并记录诊断。详见 `LEGACY_REVERSE_ENGINEERING.md`。 |
| `libactivator.audio.reset-ringer-state` | Reset Ringer | `resetRingerState` | `implemented` | 按 1.9.13 旧实现：通过 `BackBoardServices.framework` 的 `BKSHIDServicesGetRingerState` 读取硬件开关状态，并调用 SpringBoard `-_updateRingerState:withVisuals:updatePreferenceRegister:`，后两个参数均为 `NO`。 |
| `libactivator.audio.mute-ringer` | Mute Ringer | `muteRinger` | `implemented` | 现代新增 action；不复用 `libactivator.volume.mute` event name。通过 `SBRingerControl setRingerMuted:YES` 设置软静音，并调用 `activateRingerHUDFromMuteSwitch:0`。 |
| `libactivator.audio.unmute-ringer` | Unmute Ringer | `unmuteRinger` | `implemented` | 现代新增 action；不复用 `libactivator.volume.unmute` event name。通过 `SBRingerControl setRingerMuted:NO` 取消软静音，并调用 `activateRingerHUDFromMuteSwitch:1`。 |
| `libactivator.audio.toggle-ringer-mute` | Toggle Ringer Mute | `toggleRingerMute` | `implemented` | 现代新增 action；不复用 `libactivator.volume.toggle-mute-twice` event name。通过 `SBRingerControl isRingerMuted` 计算目标状态，再调用 `setRingerMuted:` 与 ringer HUD。 |
| `libactivator.system.first-springboard-page` | First SpringBoard Page | `firstSpringBoardPage` | `implemented` | 使用 `SBSServiceFacilityClient` checkout `SBSSystemServiceClient` 后调用 `resetToHomeScreenAnimated:`，提交到专用非主队列。 |

## Phone Tab URL Actions 完成清单

| Listener name | 标题 | selector / 语义 | 状态 | 实施备注 |
| --- | --- | --- | --- | --- |
| `libactivator.phone.favorites` | Show Favorites | `showPhoneFavorites` | `implemented` | 由 `LATURLActionListener` 承载，使用真机验证后的 `mobilephone-favorites:`。 |
| `libactivator.phone.recents` | Show Recents | `showPhoneRecents` | `implemented` | 由 `LATURLActionListener` 承载，使用真机验证后的 `mobilephone-recents:`。 |
| `libactivator.phone.contacts` | Show Contacts | `showPhoneContacts` | `implemented` | 由 `LATURLActionListener` 承载，使用真机验证后的 `mobilephone-contacts:`。 |
| `libactivator.phone.keypad` | Show Keypad | `showPhoneKeypad` | `implemented` | 由 `LATURLActionListener` 承载，使用真机验证后的 `mobilephone-keypad:`。 |
| `libactivator.phone.voicemail` | Show Voicemail | `showPhoneVoicemail` | `implemented` | 由 `LATURLActionListener` 承载，使用旧 master 的现代 URL `vmshow:`。 |

## Telephony Actions 完成清单

| Listener name | 标题 | selector / 语义 | 状态 | 实施备注 |
| --- | --- | --- | --- | --- |
| `libactivator.phone.answer-call` | Answer Call | `answerCall` | `implemented` | 通过 CoreTelephony 查找 incoming call 并调用 `CTCallAnswer`；若无通话或无来电，仍消费事件并记录诊断。 |
| `libactivator.phone.disconnect-call` | Disconnect Call | `answerCall` | `implemented` | 资源中的 selector metadata 保持旧值 `answerCall`；runtime 按 listener name 调用 `CTCallListDisconnectAll`，用于挂断活动通话或拒接来电。 |

## 下一阶段建议

### 1. Low-Risk System Actions Candidates

这些动作可并行调研，但不建议抢在 media command family 之前批量实现。

| Listener name | 标题 | 建议状态 | 实施备注 |
| --- | --- | --- | --- |
| `libactivator.system.homebutton` | Home Button | `candidate` | 可能可走 HID Consumer `Menu`，但需要和已有 Home button event 语义区分。 |
| `libactivator.system.sleepbutton` | Sleep Button | `candidate` | 可能可走 HID Consumer `Power`，但长按/短按语义需要单独验证。 |
| `libactivator.system.local-back` | Local Back | `candidate` | 需要确认现代系统返回键 HID 或 SpringBoard 分发入口。 |
| `libactivator.screen.brightness.increase` / `decrease` | Brightness | `candidate` | 可能可走 HID Consumer brightness usages，但需要确认和系统亮度 HUD/限制策略的交互。 |

### 2. 暂缓或高风险

以下 action family 暂不作为下一阶段默认目标：Control Center、Notification Center、Switcher、Power UI、Siri/Voice Control、Wallet、rotation、lock screen show/dismiss/toggle、Safe Mode、watch haptics、camera shutter、compose mail/SMS/notes、screen brightness。它们不是不能做，而是需要 owner-assisted SPI probe、真实 UI checklist 或明确产品决策后再进入 `candidate`。

## 下一阶段验收要求

- 新增 family 必须有独立 listener class，代码层面显式 allowlist 注册，不扫描 metadata 自动生成 runtime listener。
- 每个 family 至少拆出一个 stable suite，延续 `BuiltInActionRegistry` / `BuiltInURLActions` 的风格，不把新阶段测试继续塞进旧 URL suite。
- stable tests 覆盖 registration、`hasSeen`、metadata-only 不注册、metadata / selector gate 和 `event.handled` 语义；`event.handled` 表示 listener 消费事件，不表示系统动作最终成功；真实系统状态变化进入设备手工 checklist。不要为了 stable tests 给真实 action path 增加替换 sender、presenter、launcher 或 opener 的测试 hook。
- 实现前先记录现代 SPI 选择；如果接口不确定，先标 `blocked` 并和 owner 确认，不用 public API fallback 掩盖行为差异。
