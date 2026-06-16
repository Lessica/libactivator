# 内置能力实现路线图

本路线图只保留当前需要推进和反复确认的方向。已完成或已确认的内容降级为基线事实；逐项状态和 name 级别交叉比对见 `docs/BUILT_IN_ACTION_TRACKER.md`。

## 总体原则

- 资源 metadata presence 不等于 runtime behavior implemented。`availableEventNames` 可以来自 event metadata，但没有 hook 就不能认为事件可触发；listener/action metadata 可以用于展示和 fallback，但没有 listener object 注册就不能出现在 `availableListenerNames`。
- 每个内置能力都要先确认现代 iOS 15+ 的承载模块、SPI 依赖、验证方式，再实现和注册。
- 不为旧能力引入用户 App 注入；不使用 `com.apple.UIKit` filter。
- Settings UI 不承担 runtime 行为；它只负责配置、展示和调用 Public API。
- 不确定 SPI 时停止并问 owner。不要猜实现。

## 当前基线

- 1.9.13 Public API、常量、通知、headers、import 入口和 ABI skeleton 已对齐。
- SpringBoard authoritative backend、state/config IPC、event dispatch IPC、runtime mode、no-touch deferral、unlock-to-send callback、metadata/resource lookup、localization fallback、listener metadata cache 已具备基础能力。
- event metadata 当前 123 项已 staged：121 项来自 1.9.13，`libactivator.now-playing.playing` / `libactivator.now-playing.paused` 是 2.x additive。
- listener/action metadata 当前 118 项已 staged：1.9.13 的 117 项中移除 5 个 obsolete/excluded 项，新增 6 个 2.x additive listener/action name。
- Events / Listeners resource metadata key 已完成 cross-check：常规展示、版本过滤、capability 过滤、mode compatibility、power/no-touch gate、system haptic `tapticType`、`system.back` 的 raw event 触发源判断等 key 已由 resource/core/dispatch layer 消费；`is-unprotected`、完整 unlock sequence、preview 等未完全兑现项已集中记录到 tracker。
- 阶段 0 资源模型补强已完成，`Resources` stable suite 覆盖 bundled catalog、目录式 third-party `Info.plist`、required capabilities、small-icons path fallback 和排除项。
- 阶段 1 / 阶段 3 listener/action 已完成：No-op、URL actions、HID-backed hardware actions、已验证 system actions、AXSpringBoardServer-backed system UI actions、lock screen actions、power/recovery actions、telephony call control、dynamic application listeners 已注册真实 listener object。高风险 system actions 的真实副作用只通过真机手工验证，不进入 stable fake path；首轮真机验证无效的 clear-switcher 以及 SpringBoard 进程内不可执行的 soft-reboot 当前退回 blocked。
- 阶段 3 状态/通知型 event source 第一批已完成并收口：device locked/unlocked、power connected/disconnected、headset connected/disconnected、media playback、network joined/left Wi-Fi。
- 阶段 4 已完成 hardware button、status bar、top slide / edge gesture、fingerprint sensor、force touch、drag-along / drag-off edge events。当前继续调用原始系统实现，不做 handled-default interception。

## 承载模块划分

| 能力类型 | 承载位置 | 说明 |
| --- | --- | --- |
| event metadata | `layout/Library/Activator/Events/bundled.plist` 和 `LAResourceManager` | 固定 1.9.13 事件范围、标题、分组、兼容模式、required capabilities 等信息；2.x additive event 必须明确记录。 |
| listener/action metadata | `layout/Library/Activator/Listeners/bundled.plist`、glyph 资源和 `LAResourceManager` | 固定静态动作展示信息、兼容规则、图标候选路径和 selector/url 元数据；obsolete 项可以从当前 staged 资源移除。 |
| static built-in actions | `ActivatorTweak.dylib` 中的 built-in listener registry | 由 SpringBoard 注册真实 `LAListener` object，例如 URL actions、hardware actions、system actions、telephony actions。 |
| event sources | `ActivatorTweak.dylib` 中的 SpringBoard acquisition adapters | 负责从硬件按钮、触摸手势、SpringBoard 状态、通知或系统服务采集事件，然后调用 dispatch engine。 |
| dynamic application listeners | 独立 application listener family provider | 动态读取 SpringBoard app model，注册 App launch/action listener，处理 app glyph、显示名、特殊系统 App 行为。 |
| menu listeners | Settings UI + runtime menu provider | 菜单内容来自用户配置，需等 Settings UI 菜单编辑能力落地后实现。 |
| CLI | `subprojects/cli` 的 `/usr/bin/activator` | 生产工具 target，使用 Public API 和生产 IPC，不依赖 testing IPC，也不是 test runner。 |

## 阶段 3：listeners/actions 剩余工作

当前不再把 low-risk listeners 作为主线；剩余 listener/action 工作分为当前 staged 但未注册 runtime listener、已移除 obsolete name、以及 additive 暂缓项。详细 name 清单见 `BUILT_IN_ACTION_TRACKER.md` 的“阶段 3：listeners/actions 剩余交叉比对”。

可后续小切片推进的 blocked listener family：

1. Modal/system UI actions：clear switcher、keyboard dictation 等。每项必须先用 Frida/IDA 确认现代 SpringBoard / system service 入口；`clear-switcher` 的首轮路径已经真机验证无效，不能继续直接注册。
2. Watch haptics：按设备能力和目标 App 验证，不作为默认主线。
3. Additive power action：soft-reboot。Dopamine `jbctl reboot_userspace` 的 `reboot3(RB2_USERREBOOT)` 参考路径不能直接在 SpringBoard 进程内执行，后续需要非 SpringBoard helper 或合适 privileged execution path。
4. Listener handled semantics audit：所有 built-in listener family 需要与旧 master / 1.9.13 重新对齐 `event.handled` 时机、toggle/deactivate 行为和执行失败时的消费语义；这不是拦截层设计，结论应回写 tracker 或 reverse-engineering 记录。

不恢复或架构外：

- 仍保留为已移除的旧 URL / old social compose / bedtime 等 obsolete 项不进入主线。
- `libactivator.system.voice-control` 已按现代 Voice Control 功能恢复为 toggle；实现依据是 AccessibilitySettings 中 `-[CACSettingsController setCommandAndControlEnabled:specifier:]` 只调用 `_AXSCommandAndControlSetEnabled([value boolValue])`。
- `libactivator.system.local-back` 已复用 Voice Control 的 `CACSpokenCommand goBack` 恢复；该路径保留 Safari 返回按钮标题分支和 AX escape action 兜底。
- `libactivator.system.back` 已按现代等价路径恢复：application mode 走 `local-back`，非 application mode fallback 到 Home，触发源为 `libactivator.menu.press.single` 时返回未处理。
- `libactivator.ipod.music-controls` / `libactivator.system.show-now-playing-bar` 已按现代等价入口恢复：灭屏时先点亮屏幕，再打开 Control Center；Control Center 已可见时切换 Now Playing 模块展开状态。

## 阶段 4：events 剩余工作

当前阶段 4 的主线是剩余触摸与设备事件。详细 name 清单见 `BUILT_IN_ACTION_TRACKER.md` 的“阶段 4：events 未完成交叉比对”。

优先顺序：

1. Multi-touch gesture family：`three/four/five-finger tap/pinch/spread` 共 9 个 event。先 probe SpringBoard 或系统手势层能否在不注入用户 App 的前提下观察多指触摸；若需要持续全局识别，必须接入 assignment-aware runtime gate；gate 只降低采集成本，不替代 dispatch engine。
2. SpringBoard/icon gesture family：`springboard.pinch`、`springboard.spread`、`icon.flick.*` 共 6 个 event。只针对 SpringBoard UI 层实现，先确认现代 Home Screen / icon view hook 点。
3. Lock screen clock gesture family：clock double tap、tap hold、swipe left/right/down 共 5 个 event。与 CoverSheet、通知中心、相机入口、passcode 状态强相关，需单独 probe。
4. Low-priority event backlog：headset-button press/hold、motion shake、volume display tap、gesture-bar double tap、scheduled sunrise/sunset、car/watch/clamshell connected/open 等。它们依赖设备能力、外设状态或私有服务，不用 metadata presence 推断可用性。

已完成阶段 4 family 继续保持 no-intercept：hardware button、status bar、edge gesture、fingerprint sensor、force touch、drag-along / drag-off 当前都只识别并 dispatch，继续调用原始系统实现。

## Handled-default Interception Backlog

拦截层是独立设计任务，不并入现有 event source gate。当前判断：

- 可能需要拦截的主要 family 是物理按键和 status bar scroll-to-top；HID 层未来可以考虑完全拦截后根据 `event.handled` 决定是否 fallback 重发 synthetic event。
- Edge gesture、drag-along/off、force touch 当前保持 no-intercept 语义；如未来要改变，必须逐 family 设计 hook 返回值、原始事件转发和 `event.handled` 回传路径。
- 不能把“event 已提交给 dispatch engine”当成“应拦截默认行为”；只有 listener 真正 handled 后才能决定是否拦截。

## 阶段 5：Settings UI 与菜单

目标：实现 `libactivatorsettings.dylib`，让 Preferences、Activator.app 和第三方越狱 App 都能作为 Settings UI host。

范围：

- modes/events/listeners 列表、搜索、assignments、profiles、blacklist。
- listener/event configuration controller factory。
- menu editor 和 menu listener runtime provider。
- `glyph.pdf` lookup 和 glyph/small icon 展示、localization、resource metadata 展示。
- `glyph.pdf` 只作为 Settings UI 展示资源接入，不在 `libactivator` 核心里恢复 1.9.0 大图标 callback。
- 显式暴露 application accessibility 启停开关。`libactivator.system.local-back` 可能为恢复 Voice Control 返回语义而持久打开该系统状态；Settings UI 必须让用户能看到并关闭它。

边界：Settings UI 不实现 event acquisition，也不直接拥有 SpringBoard runtime state；它通过 Public API/IPC 操作 SpringBoard authoritative backend。

## 阶段 6：CLI 兼容工具

目标：实现 1.9.13 package 中 `/usr/bin/activator` 的现代等价。

范围：

- 命令面应保持 1.9.13 兼容：`listeners`、`events`、`modes`、`current-mode`、`current-app`、`get <key>`、`set <key> <value>`、`activate <event> [<listener>]`、`send <listener>`、`deactivate <event>`。
- `postinst` 是隐藏安装后入口，旧 usage 不展示。当前保留 no-op；`prerm` 是隐藏卸载前入口，用于包卸载前关闭 application accessibility。
- `get` / `set` 只负责调用 libactivator compatibility facade，不在 CLI 内实现 flat key 解析或直接读写 plist。
- 事件触发命令使用当前 event mode 构造 `LAEvent`，按旧语义以 `event.handled ? 0 : 1` 作为退出状态。

边界：CLI 是 production tool，不是 test runner；不能依赖 DEBUG-only testing IPC、hidden testing IPC 或测试 plist。

已确认的 1.9.13 逆向结论：

- 旧 CLI 启动命令前会 `dlopen("/usr/lib/libactivator.dylib", RTLD_LAZY)` 并检查 `[LAActivator.sharedInstance isAlive]`；不可达时 `exit(-1)`。
- `listeners`、`events`、`modes` 分别逐行打印 `availableListenerNames`、`availableEventNames`、`availableEventModes`。
- `current-mode` 打印 `currentEventMode`；`current-app` 仅在 `displayIdentifierForCurrentApplication.length > 0` 时打印。
- `get <key>` 调用 `_getObjectForPreference:` 并打印返回对象的 `description`；`set <key> <value>` 调用 `_setObject:forPreference:`，value 是命令行字符串。
- `activate <event>` 调用 `sendEventToListener:`；`activate <event> <listener>` 调用 `sendEvent:toListenerWithName:`；`send <listener>` 使用 event name `libactivator` 调用指定 listener；`deactivate <event>` 调用 `sendDeactivateEventToListeners:`。
- 旧 `postinst` 在 `kCFCoreFoundationVersionNumber < 1200.0` 时清理 BulletinBoard `SectionInfo.plist` 里的 today/tomorrow 通知中心 section 和对应 PushStore 文件，并始终尝试把 `SectionInfo.plist` chown 为 `501:501`。当前项目暂不复刻该副作用，等确实需要非 shell 安装后逻辑时再实现。

## 验收要求

- 新增 dynamic listener family 必须有独立 provider / registry path，不把动态 App listener 塞进 static built-in action listener。
- 新增 event source family 必须有独立 acquisition adapter，不把采集 hook 混入现有 action listener。
- 每个新 family 至少拆出一个 stable suite；测试重点是 registration、metadata lookup、`hasSeen`、mode/blacklist/dispatch 语义和 metadata-only 不注册。
- `event.handled` 表示 listener 消费事件或 adapter 提交事件，不表示系统最终状态变化完成；真实系统状态变化进入设备手工 checklist。
- 不为 stable tests 给真实 action path 增加高侵入 hook；优先测试真实分层边界和可观察状态。
- 实现前先记录现代 SPI 选择；如果接口不确定，先标 `blocked` 并和 owner 确认，不用 public API fallback 掩盖行为差异。
