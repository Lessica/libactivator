# 内置能力路线图

本路线图只保留当前还需要推进、反复确认或作为边界约束的内容。已完成的 listener/action/event 明细不再放在根目录路线图；需要历史对照时查 `docs/archive/2026-06-17/BUILT_IN_ROADMAP.md` 和 `docs/archive/2026-06-17/BUILT_IN_ACTION_TRACKER.md`。

## 总体原则

- Metadata presence 不等于 runtime behavior implemented。没有真实 `LAListener` object 的 listener/action 不能进入 `availableListenerNames`；没有 hook/adapter 的 event name 不能被真实触发。
- 每个内置能力都要先确认现代 iOS 15+ 的承载模块、SPI 依赖和验证方式，再实现和注册。
- 不为旧能力引入用户 App 注入；不使用 `com.apple.UIKit` filter。
- Settings UI 不承担 runtime 行为；它只负责配置、展示和调用 Public API。
- 不确定 SPI 时停止并问 owner。不要猜实现。

## 当前剩余主线

| 主线 | 状态 | 下一步 |
| --- | --- | --- |
| Staged 但未注册的 listener/action | 剩 `watch.haptic.tap` 一项 blocked | 需要确认 Watch haptic 能力与设备差异。 |
| 未实现 event family | 1.9.13 event 中仍有 21 个未实现 | 按 icon flick、lock screen clock、headset button、HUD tap、gesture bar、scheduled、car/watch/clamshell 分组推进。 |
| Settings UI 与 menu | 尚未进入 runtime 主线 | 实现 `libactivatorsettings.dylib`、assignments/profile/blacklist UI、menu editor 和 menu listener runtime provider。 |
| Handled-default interception | 尚未设计 | 单独设计物理按键和 status bar scroll-to-top 等默认行为拦截，不并入现有 event source gate。 |
| 新增 listener/action 准入 | 持续规则 | 新增或重做 built-in listener/action 时，先落旧实现依据、现代差异和 handled 准则，再补对应测试或真机清单。 |

## 承载模块边界

| 能力类型 | 承载位置 | 边界 |
| --- | --- | --- |
| event metadata | `layout/Library/Activator/Events/bundled.plist` 和 `LAResourceManager` | 只提供标题、分组、兼容模式、capability 等静态信息；不能替代 event source。 |
| listener/action metadata | `layout/Library/Activator/Listeners/bundled.plist`、glyph 资源和 `LAResourceManager` | 只提供展示、兼容规则、图标和 selector/url metadata；不能替代 listener object。 |
| static built-in actions | `ActivatorTweak.dylib` 中的中央 listener class 清单与 built-in listener registry | `LATBuiltInRegistry` 按唯一有序清单先执行类侧 metadata gate，再通过统一 context initializer 构造并注册真实 `LAListener` object；诊断字符串不参与注册策略。 |
| dynamic event definitions | `ActivatorTweak.dylib` 中的 `LATEventDefinitionRegistry` 与 family providers | 显式管理 provider catalog、concrete event ownership、generation、property-list-safe generic create/config/remove 和持久化；Network 是首个接入 family。 |
| event acquisition | `ActivatorTweak.dylib` 中的中央 Event Source class 清单、`LATEventSourceRegistry` 与 SpringBoard acquisition adapters | `LATBuiltInRegistry` 按唯一有序清单用统一 context initializer 构造 source，并通用处理可选 provider/binding；registry 只管理 source lifecycle、producer index、多 producer 和 assignment-aware interest。 |
| dynamic application listeners | 独立 application listener family provider | 动态读取 SpringBoard app model，处理 app launch/action listener、glyph、显示名和特殊系统 App 行为。 |
| menu listeners | Settings UI + runtime menu provider | 菜单内容来自用户配置，需等 Settings UI 菜单编辑能力落地后实现。 |
| CLI | `subprojects/cli` 的 `/usr/bin/activator` | 生产兼容工具，使用 Public API 和生产 IPC，不依赖 testing IPC，也不是 test runner。 |

## Listeners/actions 剩余工作

当前不再按 1.9.13 的 117 项静态资源散列推进；剩余工作只跟踪未注册、已移除、暂缓或语义待复核的条目。

1. `libactivator.watch.haptic.tap`：依赖 Watch 能力和设备差异，当前 blocked，不作为默认 listener 主线。
2. Obsolete social/settings actions：`settings.facebook`、`settings.twitter`、`facebook.compose-post`、`twitter.compose-tweet`、`weibo.compose-post` 已从 staged resource 移除，不恢复。
3. `previews` 语义：core preview dispatch API 存在，但 built-in vibration / watch haptic preview 尚未作为实际动作支持。
4. `is-unprotected` 与 `supports-unlocking-device`：旧 API protection prompt、unprotected 豁免和完整主动解锁流程尚未兑现；当前只有 callback-only unlock-to-send compatibility。
5. 新增或重做 listener/action 准入：先在 `LEGACY_REVERSE_ENGINEERING.md` 或对应 tracker 记录 1.9.13 / 旧 master 依据、现代 SPI 差异和 handled 准则，再补无副作用 stable tests 或真机 checklist。

## Events 剩余工作

优先级按实现收益和可验证性排序：

1. Icon flick gesture family：`icon.flick.*` 共 4 个 event。`springboard.pinch` / `springboard.spread` 已通过复用 `SBIconScrollView.pinchGestureRecognizer` 实现；下一步继续针对 `SBIconView` 接入四向 flick。
2. Lock screen clock gesture family：clock double tap、tap hold、swipe left/right/down 共 5 个 event。与 CoverSheet、通知中心、相机入口、passcode 状态强相关，需要单独 probe。
3. Headset button：press single、hold short 共 2 个 event。已实现 headset connected/disconnected，但线控按钮需要确认现代音频 route、HID 或 MediaRemote 信号来源。
4. Volume HUD tap：依赖音量 HUD 触摸，应作为独立 HUD/UI hook，而不是 HID 按键热路径。
5. Gesture bar double tap：与 home indicator / gesture bar 设备能力和 iOS 版本强相关，需要按设备 probe。
6. Scheduled sunrise/sunset：需要定位旧实现语义和现代定位/日出日落调度来源。
7. Car / watch / smart cover：依赖外设、设备能力或私有服务，先保留 metadata，不用 metadata presence 推断可用性。

## Handled-default Interception Backlog

拦截层是独立设计任务，不并入现有 event source gate。

- 可能需要拦截的主要 family 是物理按键和 status bar scroll-to-top。
- HID 层未来可以考虑完全拦截后根据 `event.handled` 决定是否 fallback 重发 synthetic event。
- Edge gesture、drag-along/off、force touch、multi-touch 当前保持 no-intercept 语义；如未来要改变，必须逐 family 设计 hook 返回值、原始事件转发和 `event.handled` 回传路径。
- 不能把“event 已提交给 dispatch engine”当成“应拦截默认行为”；只有 listener 真正 handled 后才能决定是否拦截。

## Settings UI 与菜单

目标是实现 `libactivatorsettings.dylib`，让 Preferences、Activator.app 和第三方越狱 App 都能作为 Settings UI host。

范围：

- modes/events/listeners 列表、搜索、assignments、profiles、blacklist。
- Settings host 对 listener/event configuration controller factory 的实际导航与保存 UI；当前只完成 event core descriptor、get/save IPC 和本进程 factory，listener configuration bridge 仍待实现。
- Dynamic provider catalog/create 的跨进程 bridge 与 creation UI；当前 provider registry、generation 和 generic create/config/remove 只在 SpringBoard 内部可用。
- menu editor 和 menu listener runtime provider。
- `glyph.pdf` lookup、glyph/small icon 展示、localization、resource metadata 展示。
- `glyph.pdf` 只作为 Settings UI 展示资源接入，不在 `libactivator` 核心里恢复 1.9.0 大图标 callback。
- 显式暴露 application accessibility 启停开关。`libactivator.system.local-back` 可能为恢复 Voice Control 返回语义而持久打开该系统状态；Settings UI 必须让用户能看到并关闭它。

边界：Settings UI 不实现 event acquisition，也不直接拥有 SpringBoard runtime state；它通过 Public API/IPC 操作 SpringBoard authoritative backend。

## CLI 遗留边界

CLI 是 production compatibility tool，不是测试入口。

- 命令面保持 1.9.13 兼容：`listeners`、`events`、`modes`、`current-mode`、`current-app`、`get <key>`、`set <key> <value>`、`activate <event> [<listener>]`、`send <listener>`、`deactivate <event>`。
- `postinst` 是隐藏安装后入口，旧 usage 不展示；当前保留 no-op。
- `prerm` 是隐藏卸载前入口，用于包卸载前关闭 application accessibility。
- `get` / `set` 只负责调用 libactivator compatibility facade，不在 CLI 内实现 flat key 解析或直接读写 plist。
- 事件触发命令使用当前 event mode 构造 `LAEvent`，按旧语义以 `event.handled ? 0 : 1` 作为退出状态。
- CLI 不能依赖 DEBUG-only testing IPC、hidden testing IPC 或测试 plist。

## 验收要求

- 新增 dynamic listener family 必须有独立 provider / registry path，不把动态 App listener 塞进 static built-in action listener。
- 新增 static built-in listener family 必须采用 `LATBuiltInListenerRegistrant`，加入 `LATBuiltInRegistry +builtInListenerClasses` 的正确位置，并通过统一 nullable `initWithBuiltInListenerContext:` 构造。Initializer 必须从 context 提取实际依赖并转发 designated initializer，不保存 context 或取得完整 registry；动态 SpringBoard owner 只能通过弱 `LATSpringBoardInstanceProviding` 查询。Registry 不得增加逐类型 initializer 分支、factory configuration dictionary 或独立注册特例；每个 supported name 必须有 bundled metadata 正向 gate、缺失 metadata 负向 gate 和唯一 owner 测试。
- 新增 event source family 必须有独立 acquisition adapter，不把采集 hook 混入现有 action listener；source 在主实现中采用 `LATEventSource`、实现统一 nullable `initWithEventSourceContext:`，从 context 提取窄协议依赖，不读取 `LASharedActivator`，也不增加平行 factory/module 类型。
- 新 family 的 concrete class 必须加入 `LATBuiltInRegistry +builtInEventSourceClasses` 的正确位置；这是唯一允许集中 import/list concrete source 的位置。Registry 的通用构造循环不得增加逐类型 property、initializer 分支或 capability 特判；hook 按 source 采用的 typed ingress protocol 接线。
- 中央清单顺序表达构造顺序和可选前置 source 依赖，initializer 返回 `nil` 表达 capability 不满足。需要 dynamic definition/acquisition 同步时由 source 的 optional provider hook 和 registry-owned binding 接线，并保留 definition registry 的完整原子事务与回滚保证。
- 每个新 family 至少拆出一个 stable suite；测试重点是 registration、metadata lookup、`hasSeen`、mode/blacklist/dispatch 语义和 metadata-only 不注册。
- `event.handled` 表示 listener 消费事件或 adapter 提交事件，不表示系统最终状态变化完成；真实系统状态变化进入设备手工 checklist。
- listener/action handled 语义必须先有旧实现依据或明确的现代差异准则，避免测试只覆盖当前实现而没有 1.9.13 对齐结论。
- 不为 stable tests 给真实 action path 增加高侵入 hook；优先测试真实分层边界和可观察状态。
- 实现前先记录现代 SPI 选择；如果接口不确定，先标 `blocked` 并和 owner 确认，不用 public API fallback 掩盖行为差异。
