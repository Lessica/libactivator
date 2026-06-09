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
| `libactivator.clock.alarm` | Clock | Alarm | `candidate` | `clock-alarm:default` | 真机手工确认 Clock URL 是否仍有效 |
| `libactivator.clock.bedtime` | Clock | Bedtime | `candidate` | `clock-sleep-alarm:default` | 真机手工确认 Clock URL 是否仍有效 |
| `libactivator.clock.stopwatch` | Clock | Stopwatch | `candidate` | `clock-stopwatch:default` | 真机手工确认 Clock URL 是否仍有效 |
| `libactivator.clock.timer` | Clock | Timer | `candidate` | `clock-timer:default` | 真机手工确认 Clock URL 是否仍有效 |
| `libactivator.clock.world-clock` | Clock | World Clock | `candidate` | `clock-worldclock:default` | 真机手工确认 Clock URL 是否仍有效 |
| `libactivator.settings.about` | Settings | About | `candidate` | `prefs:root=General&path=About` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.accessibility` | Settings | Accessibility | `candidate` | `prefs:root=General&path=ACCESSIBILITY` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.auto-lock` | Settings | Auto-Lock | `candidate` | `prefs:root=General&path=AUTOLOCK` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.background-app-refresh` | Settings | Background App Refresh | `candidate` | `prefs:root=General&path=AUTO_CONTENT_DOWNLOAD` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.battery` | Settings | Battery | `candidate` | `prefs:root=BATTERY_USAGE` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.bluetooth` | Settings | Bluetooth | `candidate` | `prefs:root=General&path=Bluetooth`<br>`700`<br>`prefs:root=Bluetooth` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.brightness` | Settings | Brightness | `candidate` | `prefs:root=Brightness` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.brightness-and-wallpaper` | Settings | Brightness & Wallpaper | `candidate` | `prefs:root=Wallpaper` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.carplay` | Settings | Carplay | `candidate` | `prefs:root=General&path=CARPLAY` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.cellular` | Settings | Cellular | `candidate` | `prefs:root=General&path=MOBILE_DATA_SETTINGS_ID`<br>`1000`<br>`prefs:root=MOBILE_DATA_SETTINGS_ID` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.control-center` | Settings | Control Center | `candidate` | `prefs:root=ControlCenter` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.date-time` | Settings | Date & Time | `candidate` | `prefs:root=General&path=DATE_AND_TIME` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.display` | Settings | Display & Brightness | `candidate` | `prefs:root=DISPLAY` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.do-not-disturb` | Settings | Do Not Disturb | `candidate` | `prefs:root=DO_NOT_DISTURB` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.equalizer` | Settings | Equalizer | `candidate` | `prefs:root=MUSIC&path=EQ` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.facebook` | Settings | Facebook | `candidate` | `prefs:root=FACEBOOK` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.facetime` | Settings | FaceTime | `candidate` | `prefs:root=FACETIME` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.game-center` | Settings | Game Center | `candidate` | `prefs:root=GAMECENTER` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.general` | Settings | General | `candidate` | `prefs:root=General` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.handoff` | Settings | Handoff | `candidate` | `prefs:root=General&path=CONTINUITY_SPEC` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.icloud` | Settings | iCloud | `candidate` | `prefs:root=CASTLE` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.international` | Settings | Language & Region | `candidate` | `prefs:root=General&path=INTERNATIONAL` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.keyboard` | Settings | Keyboard | `candidate` | `prefs:root=General&path=Keyboard` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.location-services` | Settings | Location Services | `candidate` | `prefs:root=LOCATION_SERVICES` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.mail` | Settings | Mail, Contacts, Calendars | `candidate` | `prefs:root=ACCOUNT_SETTINGS` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.managed-configuration` | Settings | Profiles & Device Management | `candidate` | `prefs:root=General&path=ManagedConfigurationList` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.maps` | Settings | Maps | `candidate` | `prefs:root=MAPS` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.messages` | Settings | Messages | `candidate` | `prefs:root=MESSAGES` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.music` | Settings | Music | `candidate` | `prefs:root=MUSIC` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.network` | Settings | Network | `candidate` | `prefs:root=General&path=Network` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.notes` | Settings | Notes | `candidate` | `prefs:root=NOTES` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.notifications` | Settings | Notifications | `candidate` | `prefs:root=NOTIFICATIONS_ID` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.passcode` | Settings | Touch ID & Passcode | `candidate` | `prefs:root=PASSCODE` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.phone` | Settings | Phone | `candidate` | `prefs:root=Phone` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.photos` | Settings | Photos | `candidate` | `prefs:root=Photos` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.privacy` | Settings | Privacy | `candidate` | `prefs:root=Privacy` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.reminders` | Settings | Reminders | `candidate` | `prefs:root=REMINDERS` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.safari` | Settings | Safari | `candidate` | `prefs:root=Safari`<br>`1240`<br>`prefs:root=SAFARI` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.sounds` | Settings | Sounds | `candidate` | `prefs:root=Sounds` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.store` | Settings | Store | `candidate` | `prefs:root=STORE` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.tethering` | Settings | Personal Hotspot | `candidate` | `prefs:root=INTERNET_TETHERING` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.twitter` | Settings | Twitter | `candidate` | `prefs:root=TWITTER` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.usage` | Settings | Usage | `candidate` | `prefs:root=General&path=USAGE`<br>`1240`<br>`prefs:root=General&path=STORAGE_ICLOUD_USAGE` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.virtual-assistant` | Settings | Siri | `candidate` | `prefs:root=General&path=Assistant`<br>`1240`<br>`prefs:root=General&path=SIRI` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.vpn` | Settings | VPN | `candidate` | `prefs:root=General&path=VPN` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.wallpaper` | Settings | Wallpaper | `candidate` | `prefs:root=Wallpaper` | 真机手工确认 Settings URL 是否仍有效 |
| `libactivator.settings.wifi` | Settings | Wi-Fi | `candidate` | `prefs:root=WIFI` | 真机手工确认 Settings URL 是否仍有效 |
