# 内置动作跟踪表

本表跟踪 built-in listeners/actions 的具体实现事项。它回答“是什么、为什么要做、依据来自哪里、当前状态如何”，不替代 `BUILT_IN_ROADMAP.md` 的阶段顺序。

## 规则

- `listener` 在 Activator 语义里通常就是 action executor：它是被 assignment 选中的响应器，也是实际完成动作的主体。
- 同一个 listener class 可以注册到多个 listener name。name 决定元数据、标题、分组、URL 或 selector；class 决定运行时行为。
- metadata presence 不等于已实现。只有注册了真实 `LAListener` object 的 name 才能进入 `availableListenerNames` 并处理事件。
- 1.9.13 资源 catalog 是当前内置动作范围的主要依据；旧 master 只用于证明历史承载方式和语义，不用于照搬实现。
- 状态值：`metadata-only` 表示只有资源；`candidate` 表示可进入当前阶段评估；`in-progress` 表示正在实现；`implemented` 表示已有行为和测试；`blocked` 表示需要 owner 或 SPI 决策；`obsolete` 表示不计划恢复。

## 已实现动作

| Listener name | 动作 | 承载实体 | 依据 | 状态 | 说明 |
| --- | --- | --- | --- | --- | --- |
| `libactivator.system.nothing` | 不执行操作，吞掉原始动作 | `LATNothingListener` | 1.9.13 `Listeners/bundled.plist`；旧 master `LASimpleListener -doNothing` | `implemented` | 已由 `LATBuiltInListenerRegistry` 注册，stable `BuiltInActions` 覆盖 dispatch 后 `event.handled = YES`。 |

## URL actions 候选

URL actions 的范围来自 1.9.13 `layout/Library/Activator/Listeners/bundled.plist` 中带 `url` 或 `urls` 的条目，共 52 项。旧 master 中这些条目通常通过 `LASimpleListener openURLWithActivator:event:listenerName:` 承载；重写中建议由共享的 `LATURLActionListener` 承载，并由 `LATBuiltInListenerRegistry` 批量注册到不同 listener name。

| Listener name | 分组 | 标题 | 当前阶段 | URL metadata | 首次验证 |
| --- | --- | --- | --- | --- | --- |
| `libactivator.clock.alarm` | Clock | Alarm | `implemented` | `clock-alarm:default` | ✅ |
| `libactivator.clock.bedtime` | Clock | Bedtime | `obsolete` | `clock-sleep-alarm:default` | 已失效 |
| `libactivator.clock.stopwatch` | Clock | Stopwatch | `implemented` | `clock-stopwatch:default` | ✅ |
| `libactivator.clock.timer` | Clock | Timer | `implemented` | `clock-timer:default` | ✅ |
| `libactivator.clock.world-clock` | Clock | World Clock | `implemented` | `clock-worldclock:default` | ✅ |
| `libactivator.settings.about` | Settings | About | `implemented` | `prefs:root=General&path=About` | ✅ |
| `libactivator.settings.accessibility` | Settings | Accessibility | `implemented` | `prefs:root=ACCESSIBILITY` | ✅ |
| `libactivator.settings.auto-lock` | Settings | Auto-Lock | `implemented` | `prefs:root=General&path=AUTOLOCK` | ✅ |
| `libactivator.settings.background-app-refresh` | Settings | Background App Refresh | `implemented` | `prefs:root=General&path=AUTO_CONTENT_DOWNLOAD` | ✅ |
| `libactivator.settings.battery` | Settings | Battery | `implemented` | `prefs:root=BATTERY_USAGE` | ✅ |
| `libactivator.settings.bluetooth` | Settings | Bluetooth | `implemented` | `prefs:root=General&path=Bluetooth`<br>`700`<br>`prefs:root=Bluetooth` | ✅ |
| `libactivator.settings.brightness` | Settings | Brightness | `obsolete` | `prefs:root=Brightness` | 和 `libactivator.settings.display` 重复 |
| `libactivator.settings.brightness-and-wallpaper` | Settings | Brightness & Wallpaper | `obsolete` | `prefs:root=Wallpaper` | 和 `libactivator.settings.wallpaper` 重复 |
| `libactivator.settings.carplay` | Settings | Carplay | `implemented` | `prefs:root=General&path=CARPLAY` | ✅ |
| `libactivator.settings.cellular` | Settings | Cellular | `implemented` | `prefs:root=General&path=MOBILE_DATA_SETTINGS_ID`<br>`1000`<br>`prefs:root=MOBILE_DATA_SETTINGS_ID` | ✅ |
| `libactivator.settings.control-center` | Settings | Control Center | `implemented` | `prefs:root=ControlCenter` | ✅ |
| `libactivator.settings.date-time` | Settings | Date & Time | `implemented` | `prefs:root=General&path=DATE_AND_TIME` | ✅ |
| `libactivator.settings.display` | Settings | Display & Brightness | `implemented` | `prefs:root=DISPLAY` | ✅ |
| `libactivator.settings.do-not-disturb` | Settings | Do Not Disturb | `implemented` | `prefs:root=DO_NOT_DISTURB` | ✅ |
| `libactivator.settings.equalizer` | Settings | Equalizer | `obsolete` | `prefs:root=MUSIC&path=EQ` | 只能打开音乐设置 |
| `libactivator.settings.facebook` | Settings | Facebook | `obsolete` | `prefs:root=FACEBOOK` | 已失效 |
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
| `libactivator.settings.network` | Settings | Network | `obsolete` | `prefs:root=General&path=Network` | 已失效 |
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
| `libactivator.settings.twitter` | Settings | Twitter | `obsolete` | `prefs:root=TWITTER` | 已失效 |
| `libactivator.settings.usage` | Settings | Usage | `obsolete` | `prefs:root=General&path=USAGE`<br>`1240`<br>`prefs:root=General&path=STORAGE_ICLOUD_USAGE` | 已失效 |
| `libactivator.settings.virtual-assistant` | Settings | Siri | `implemented` | `prefs:root=General&path=Assistant`<br>`1240`<br>`prefs:root=General&path=SIRI` | ✅ |
| `libactivator.settings.vpn` | Settings | VPN | `implemented` | `prefs:root=VPN` | ✅ |
| `libactivator.settings.wallpaper` | Settings | Wallpaper | `implemented` | `prefs:root=Wallpaper` | ✅ |
| `libactivator.settings.wifi` | Settings | Wi-Fi | `implemented` | `prefs:root=WIFI` | ✅ |
