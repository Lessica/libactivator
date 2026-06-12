# 内置能力实现路线图

本路线图指导下一阶段 built-in events、listeners/actions、dynamic listener families 和 CLI 的实现顺序。旧 inventory 已归档到 `docs/archive/2026-06-09/`；路线图只保留当前需要执行和反复确认的方向。

## 总体原则

- 资源 metadata presence 不等于 runtime behavior implemented。`availableEventNames` 可以来自 event metadata，但没有 hook 就不能认为事件可触发；listener/action metadata 可以用于展示和 fallback，但没有 listener object 注册就不能出现在 `availableListenerNames`。
- 每个内置能力都要先确认现代 iOS 15+ 的承载模块、SPI 依赖、验证方式，再实现和注册。
- 不为旧能力引入用户 App 注入；不使用 `com.apple.UIKit` filter。
- Settings UI 不承担 runtime 行为；它只负责配置、展示和调用 Public API。
- 不确定 SPI 时停止并问 owner。不要猜实现。

## 承载模块划分

| 能力类型 | 承载位置 | 说明 |
| --- | --- | --- |
| event metadata | `layout/Library/Activator/Events/bundled.plist` 和 `LAResourceManager` | 固定 1.9.13 事件范围、标题、分组、兼容模式、required capabilities 等信息。 |
| listener/action metadata | `layout/Library/Activator/Listeners/bundled.plist`、glyph 资源和 `LAResourceManager` | 固定 1.9.13 静态动作展示信息、兼容规则、图标候选路径和 selector/url 元数据。 |
| static built-in actions | `ActivatorTweak.dylib` 中的 built-in listener registry | 由 SpringBoard 注册真实 `LAListener` object，例如 `libactivator.system.nothing`、URL actions、系统 UI actions。 |
| event sources | `ActivatorTweak.dylib` 中的 SpringBoard acquisition adapters | 负责从硬件按钮、触摸手势、SpringBoard 状态、通知或系统服务采集事件，然后调用 dispatch engine。 |
| dynamic application listeners | 独立 application listener family provider | 动态读取 SpringBoard app model，注册 App launch/action listener，处理 app glyph、显示名、特殊系统 App 行为。 |
| menu listeners | Settings UI + runtime menu provider | 菜单内容来自用户配置，需等 Settings UI 菜单编辑能力落地后实现。 |
| SBSettings toggles | 暂不实现 | 旧 SBSettings ABI 过时，除非 owner 明确要求现代兼容层，否则标为 obsolete。 |
| CLI | `subprojects/cli` 的 `/usr/bin/activator` | 生产工具 target，使用 Public API 和生产 IPC，不依赖 testing IPC，也不是 test runner。 |

## 已完成基础

- 1.9.13 Public API、常量、通知、headers、import 入口和 ABI skeleton 已对齐。
- SpringBoard authoritative backend、state/config IPC、event dispatch IPC、runtime mode、no-touch deferral、unlock-to-send callback、metadata/resource lookup、localization fallback、listener metadata cache 已具备基础能力。
- event metadata 当前 123 项已 staged，其中 121 项来自 1.9.13，`libactivator.now-playing.playing` / `libactivator.now-playing.paused` 是阶段 3 明确新增的现代 MediaRemote 播放状态事件。
- 1.9.13 listener/action metadata 过滤后 114 项已 staged；`libactivator.twitter.compose-tweet`、`libactivator.facebook.compose-post`、`libactivator.weibo.compose-post` 已排除。
- `libactivator.system.nothing` 已实现并进入 stable tests。

## 阶段 0：资源模型补强

目标：确保 staged metadata 能被可靠解析、过滤、缓存和测试，为后续 action/event 注册提供可信基础。

范围：

- `required-capabilities` 通过 MobileGestalt 能力 key 过滤，例如 `ipad`、`touch-id`、`real-home-button`、`fake-home-button`、`watch-companion`。
- `small-icons` 路径按 `jbroot(path)` 优先、原路径 fallback 的方式解析。
- resource manager 缓存必须有并发保护，清理策略要集中。
- resource tests 覆盖 bundled plist、目录式 third-party `Info.plist`、required capabilities、small-icons path fallback、excluded social compose actions。

验收：stable `Resources` suite 覆盖上述行为，`scripts/check-public-api.sh` 不出现新 public surface。

## 阶段 1：低风险 static actions

目标：先实现无需复杂 hook、无需 Settings UI、可在 SpringBoard 内直接验证的 listener/action。

优先顺序：

1. No-op action：`libactivator.system.nothing`，已完成。
2. URL actions：metadata 中带 `url` 或 `urls`，且现代 iOS 上 URL 可验证的 actions，例如 Settings 页面、Clock 页面、Phone/Contacts/Mail/SMS 中能以 URL 打开的入口。
3. Simple selector actions：无需复杂状态源、只调用明确 SpringBoard 或系统服务能力的动作，例如部分媒体控制、音量步进、截图、Home button HID 等；每项必须先确认现代接口。
4. Modal/system UI actions：会展示系统 UI 或改变 SpringBoard UI 状态的动作，例如 switcher、notification center、power menu、Siri/assistant、Wallet，逐个做 SPI probe 和手工 checklist。
5. 高风险或待决策 actions：Safe Mode、call control、camera shutter、watch haptics、过时第三方服务集成，先保留 metadata，不注册 runtime listener。

承载方式：新增一个或多个 `LAListener` 实现类，由 `LATBuiltInRegistry` 在 SpringBoard 中创建和注册。不要把所有 action 堆进一个巨型类；可以按 URL、media、system UI、lock screen 等 family 拆分。

测试方式：纯 dispatch 语义进 stable `BuiltInActions`；真正打开 App、弹 UI、锁屏/解锁、系统服务变化进入 `RuntimeDevice` 或手工 checklist。

## 阶段 2：dynamic application listeners

目标：恢复“打开某个 App / App 相关动作”这类动态 listener family。

关键点：

- 数据来自 SpringBoard app model，而不是硬编码 1.9.13 中的静态第三方 glyph 目录。
- display identifier 语义优先使用 SpringBoard app object 的 `displayIdentifier`。
- app icon 可用小图 fallback，指定大图尺寸不是当前需求。
- 静态 glyph 目录只作为兼容资源；不能误认为这些第三方 App 必然存在。
- 注册动态 listener 时需要支持旧私有 `ignoreHasSeen:` 语义，避免动态扫描把所有 App 都标记为 seen。

测试方式：metadata/registration 可进 SpringBoard-owned stable；真实打开 App、App-to-App 切换、强杀 App、特殊系统 App 行为进 `RuntimeDevice` 或手工观察。

## 阶段 3：通知型与状态型 event sources

目标：先实现不依赖复杂触摸识别的 event source family。

候选 family：

- device locked/unlocked、power connected/disconnected、headset connected/disconnected、network joined/left Wi-Fi。
- media playback、car/watch/smart cover 等必须先确认现代通知或系统服务来源。
- fingerprint/home-indicator/gesture-bar/3D Touch 等需要按设备能力和 iOS 版本判断，不能只看 metadata。

承载方式：每个 family 使用独立 SpringBoard event acquisition adapter，adapter 只负责采集事件并构造 `LAEvent`；assignment、blacklist、dispatch、no-touch、unlock-to-send 继续由 `LAActivator` dispatch engine 处理。

测试方式：能模拟通知的可进专项自动化；需要硬件动作或真实系统状态的进入手工 checklist。

## 阶段 4：按钮与触摸手势 event sources

目标：恢复 Activator 最核心但风险最高的事件采集能力。

分组：

- hardware buttons：Home/Menu、Sleep/Lock、Volume、ringer/mute、组合键和 hold timing。
- status bar gestures：tap、hold、swipe，要求不注入用户 App。
- edge gestures：slide in/out、two-finger slide、drag along screen edge。
- multitouch gestures：three/four/five finger tap、pinch、spread。
- SpringBoard/icon gestures：home screen pinch/spread、icon flick。
- lock screen gestures：CoverSheet/lock screen clock gestures。

承载方式：按 family 建 adapter，不把所有 hook 混进 `ActivatorTweak.m`。CaptainHook hook 点应尽量收敛，先通过 Frida probe 和 owner 手工操作确认信号可靠，再落地。

测试方式：触摸 tracker 等纯逻辑进 stable；真实手势采集以 `RuntimeDevice` 和手工 checklist 为主。Frida 只能作为探针，不作为测试结果。

## 阶段 5：Settings UI 与菜单

目标：实现 `libactivatorsettings.dylib`，让 Preferences、Activator.app 和第三方越狱 App 都能作为 Settings UI host。

范围：

- modes/events/listeners 列表、搜索、assignments、profiles、blacklist。
- listener/event configuration controller factory。
- menu editor 和 menu listener runtime provider。
- `glyph.pdf` lookup 和 glyph/small icon 展示、localization、resource metadata 展示。
- `glyph.pdf` 只作为 Settings UI 展示资源接入，不在 `libactivator` 核心里恢复 1.9.0 大图标 callback。

边界：Settings UI 不实现 event acquisition，也不直接拥有 SpringBoard runtime state；它通过 Public API/IPC 操作 SpringBoard authoritative backend。

## 阶段 6：CLI 兼容工具

目标：实现 1.9.13 package 中 `/usr/bin/activator` 的现代等价。

范围：

- 命令面应保持 1.9.13 兼容：`listeners`、`events`、`modes`、`current-mode`、`current-app`、`get <key>`、`set <key> <value>`、`activate <event> [<listener>]`、`send <listener>`、`deactivate <event>`。
- `postinst` 是隐藏安装后入口，旧 usage 不展示。当前保留 no-op；不要为了测试或便利增加新子命令。
- `get` / `set` 只负责调用 libactivator compatibility facade，不在 CLI 内实现 flat key 解析或直接读写 plist。
- 事件触发命令使用当前 event mode 构造 `LAEvent`，按旧语义以 `event.handled ? 0 : 1` 作为退出状态。

边界：CLI 是 production tool，不是 test runner；不能依赖 `LA_TESTING`、hidden testing IPC 或测试 plist。

已确认的 1.9.13 逆向结论：

- 旧 CLI 启动命令前会 `dlopen("/usr/lib/libactivator.dylib", RTLD_LAZY)` 并检查 `[LAActivator.sharedInstance isAlive]`；不可达时 `exit(-1)`。
- `listeners`、`events`、`modes` 分别逐行打印 `availableListenerNames`、`availableEventNames`、`availableEventModes`。
- `current-mode` 打印 `currentEventMode`；`current-app` 仅在 `displayIdentifierForCurrentApplication.length > 0` 时打印。
- `get <key>` 调用 `_getObjectForPreference:` 并打印返回对象的 `description`；`set <key> <value>` 调用 `_setObject:forPreference:`，value 是命令行字符串。
- `activate <event>` 调用 `sendEventToListener:`；`activate <event> <listener>` 调用 `sendEvent:toListenerWithName:`；`send <listener>` 使用 event name `libactivator` 调用指定 listener；`deactivate <event>` 调用 `sendDeactivateEventToListeners:`。
- 旧 `postinst` 在 `kCFCoreFoundationVersionNumber < 1200.0` 时清理 BulletinBoard `SectionInfo.plist` 里的 today/tomorrow 通知中心 section 和对应 PushStore 文件，并始终尝试把 `SectionInfo.plist` chown 为 `501:501`。当前项目暂不复刻该副作用，等确实需要非 shell 安装后逻辑时再实现。

legacy preference 兼容边界：

- 旧 flat key 不应迫使 v2 persistence 退回 flat 结构。`LAEventListener(<mode>)-<eventName>`、`LABlacklisted-<displayIdentifier>`、`LAHasSeenListener-<listenerName>` 属于 runtime model，应翻译到 v2 backend。
- `LAMenuSettings`、Settings UI flag、system version prompt 和第三方自定义 key 暂无 v2 runtime 等价模型，应走 legacy passthrough store，后续 Settings UI 或安装迁移阶段可以再定义更具体的语义。

## 当前建议的下一步

先完成阶段 0 的资源模型补强与测试，然后从阶段 1 的 URL actions 开始逐个实现。每实现一个 built-in action 或 event family，都要同时更新本路线图中的状态、补充所属测试类别，并明确是否需要 owner-assisted SPI probe。
