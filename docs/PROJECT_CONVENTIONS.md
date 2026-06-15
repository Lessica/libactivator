# 项目规约

本文件是当前重写工作的高优先级规约。旧文档已归档，历史细节可查 `docs/archive/2026-06-09/`；日常实现决策先看本文件。

## 基线与目标

- 当前兼容基线是 `references/latest` 中解包出的 Activator `1.9.13~rc6`，包括 Public API、导出符号和内置资源 catalog。
- `references/headers` 中的 1.9.0 headers 只作考古参考，不再作为兼容决策依据。
- `references/master` 是旧实现语义参考，不能照搬实现；当它与 1.9.13 Public API 或资源基线冲突时，以 1.9.13 为准。
- 新版本线按 2.x 维护，假设原作者不再继续维护旧项目。
- 最低系统版本为 iOS 15.0，构建使用 Theos、`$THEOS` 中的 iOS 16.5 SDK、`arm64 arm64e`。
- 必须支持 rootful、rootless、roothide。Theos/theos-roothide 负责大部分布局差异；运行时路径必须通过 `jbroot(...)` 等 roothide 入口处理。

## 兼容性原则

- Public API 的类名、协议名、selector、常量、通知名和 import 入口是兼容契约：`#import <libactivator.h>`、`#import <Activator/Activator.h>`、`@import Activator` 都必须持续可用。
- 旧 API 中过时或不再实现的部分要保留 source/ABI 兼容符号，并明确标为 deprecated 或 no-op。典型例子包括 legacy authorization、`dangerousToSendEvents` 和 1.9.13 已降级的大图标接口。
- 不确定的 SPI 不许编造实现，也不要靠联网搜索拼答案；先留下占位和待决策点，然后问项目 owner。
- 原实现使用过的 iOS SPI 默认视为失效；原实现使用过的 Public API 必须确认 iOS 16.5 SDK 下的现代用法后才能采用；不得使用 deprecated API。
- legacy 行为如果明显是 bug、安全风险或过时包袱，可以不盲目保留，但必须记录差异原因。

## 进程与注入边界

- SpringBoard 是权威 runtime owner。event registry、listener registry、assignments、profiles、blacklist、metadata dispatch、event delivery 和 runtime mode 最终都应收敛到 SpringBoard。
- 非 SpringBoard 进程中的 `LAActivator` 是 facade。能跨进程的调用走 IPC；不能跨进程的调用必须明确 no-op、返回安全 fallback 或记录详细英文日志，不能悄悄创建本地孤岛状态。
- 不允许注入用户 App。不允许使用 `com.apple.UIKit` filter，因为它会注入所有 App。
- 允许注入明确 Bundle ID 且以 `com.apple.` 开头的 Apple App，但必须逐项说明理由并使用精确 filter。
- 如果未来某项功能确实需要用户 App 注入，它必须作为 libactivator 之外的独立可选组件设计。

## Theos 与命名

- 不在 Makefile 中定义或兜底 `$THEOS`；调用方负责提供环境。
- 不覆盖 Theos 内部路径变量或缓存变量，例如 `THEOS_LIBRARY_PATH`、`THEOS_PACKAGE_DIR`、`CLANG_MODULE_CACHE_PATH`。
- target 文件放在各自 subproject 内，根 Makefile 只负责串联 subproject。
- 不使用 Logos。tweak 代码使用 Objective-C / Objective-C++ 和 CaptainHook，源文件不要使用 `.x` 或 `.xm`。
- `ActivatorTweak.m` 只作为 tweak 主入口；新增 tweak-local 类型使用 `LAT` 或 `LATweak` 前缀。
- 独立 App 使用 `LAApp` 命名前缀；Settings UI 使用 `LAS` 或 `LASettings`；Settings preference panel 使用 `LAP` 或 `LAPreferences`。
- 不允许使用 `LibActivator` 这种旧式奇怪命名。

## 代码风格

- 与用户交流使用简体中文；代码、注释、日志、诊断文本、测试 case 名、提交信息使用英语；本地化资源除外。
- 头文件使用 Xcode 默认风格 copyright，并补齐 `NS_ASSUME_NONNULL_BEGIN/END`。
- 新代码默认使用 ARC。除非 Theos/runtime 边界确实需要，否则不要写手动内存管理。
- 私有接口必须先声明再调用；禁止直接调用 `objc_msgSend`。
- ObjC SPI 应声明原始私有类型、category 或 class extension 后直接调用，例如 `SpringBoard *`、`SBVolumeControl *`、`SBRingerControl *` 或 `UIApplication (...)`；不要用本地 `@protocol LAT...` / `id<LAT...>` 伪装某个私有类型的能力集合。
- 已持有原类型实例时，不要用 `NSSelectorFromString` + `methodForSelector` + 手写函数指针绕过编译器；应声明 selector，必要时用 `respondsToSelector:@selector(...)` 做兼容检查，然后直接发送 Objective-C 消息。
- 只有需要避免强引用 ObjC class 本体、或类在目标系统上可能不存在时，才用 `NSClassFromString` 获取 class；获取实例后仍应 cast 到原始私有类型并按声明调用。
- C SPI 的声明按规模放置：单个函数可在使用它的 `.m` 内 `extern` 声明；一组相关函数、结构体、枚举或常量才抽成 tweak-local private header。不要为单个 C 函数单独创建头文件。
- 允许链接已明确决策的私有 framework，例如 `CoreTelephony`、`BackBoardServices`、`MediaRemote` 和 `SpringBoardServices`；不要为了回避链接而默认改用 `dlopen` / `dlsym`。只有 framework 不可直接链接、符号跨系统版本高度不稳定、或确实需要 weak runtime probing 时，才使用动态解析，并记录原因。
- UIKit、SpringBoard、FrontBoard 私有 UI API 默认在主队列调用，除非已经确认该 API 线程安全。
- SpringBoard 内的 SBS/FBS 启动类 SPI 不得从主队列发起，也不得在同步 IPC handler 中同步等待其返回；listener 应只提交异步请求并按 `LAEvent.handled` 语义消费事件，实际失败用英文日志诊断。
- 默认线程模型是 SpringBoard main queue confined：event source、listener dispatch、registry、hook 回调后的状态归约和 UI/SpringBoard SPI 访问都应回到主队列。允许的非主队列只有两类：对象内部私有串行队列用于保护自己的缓存/状态，且不得在队列内反调 listener 或 UI/SpringBoard SPI；以及少数 listener/action 为避免外部 `LaunchServices`、`FrontBoardServices`、`SpringBoardServices`、`BackBoardServices` 等 IPC 反向同步卡住 SpringBoard 主队列而提交的异步系统服务调用。其他后台队列使用必须在代码或文档中说明理由。
- 用 GCD 和 `dispatch_once` 管理并发与单例，不使用 `@synchronized(self)`。
- 只有全局兼容入口或天然进程级 service 才保留单例，例如 `LAActivator` facade 和 resource manager。有明确生命周期 owner 的 helper/service 应由 owner 持有或注入，并通过现有 facade 暴露必要能力；不要为了调用方便新增 `shared...` 入口，尤其不要让 tweak 直接越级调用 hidden helper。
- 一个实现文件默认只放一个主要类。多个类堆在一个 `.m` 里只允许用于明确记录过的兼容 shim 或极小私有局部类型。
- 不要把一两行逻辑抽成无意义 C helper。只有确实有抽象价值、能减少真实复杂度的逻辑才抽成 ObjC method、类或服务。
- 可以用 `#pragma mark` 给长文件分区，但更优先把职责拆到合适的私有类型。

## IPC 与通知

- IPC 使用 `AppSupport` 的 `CPDistributedMessagingCenter`，server name 固定为 `libactivator.springboard`。
- 不再引入 direct XPC、`CFMessagePort`、自定义 timeout 或 version negotiation。客户端和 SpringBoard server 一体分发，安装后需要重启 SpringBoard。
- 当前没有具体沙盒穿透需求时不引入 `libSandy`；如果未来某个 system service bridge 需要穿透沙盒，只为那个具体 bridge 引入。
- IPC payload 只使用 property-list-safe dictionary。`LAEvent` 跨进程只传 `EventName`、`EventMode`、`EventHandled` 和 property-list-safe `UserInfo`。
- `LAIPCServer` 只能是 transport adapter：注册 message、解码 payload、调用 `LAActivator` 内部 facade、编码 reply。业务规则、通知触发、listener/resource fallback、dispatch sequencing 不应放在 IPC server 里。
- Public change notifications 是进程内 `NSNotification` 名称。跨进程传播使用私有 Darwin notification 名称，再由各进程 facade 重新投递本地 public notification，避免同名混淆。

## 数据、资源与缓存

- v2 运行时偏好路径固定为 `jbroot(@"/var/mobile/Library/Preferences/libactivator.plist")`；测试构建使用隔离路径，不读取或写入用户真实配置。
- 非 SpringBoard 客户端不得写运行时持久化文件。
- 无效或不可读 plist 当作不存在；不删除、不重命名、不备份、不立即覆盖。
- 配置变更先更新 SpringBoard in-memory state，磁盘写入可以在 main run loop 合并 flush。读取 Public API 或 IPC 应返回最新内存状态，直接读取 plist 的外部代码可能暂时看到旧磁盘快照。
- 持久化文件写入后使用旧式兼容权限 `0666`，并设置 `NSFileProtectionNone`。
- 旧实现的 `_getObjectForPreference:` / `_setObject:forPreference:` 面向 flat key；当前 v2 schema 不应退回旧 flat 文件结构。兼容层应放在 libactivator 层，由独立 bridge 负责把有 v2 等价模型的 key family 翻译到 backend，把没有 v2 等价模型的 key 保存在 legacy passthrough store。
- 目前已确认需要语义翻译的 flat key family 是 `LAEventListener(<mode>)-<eventName>`、`LABlacklisted-<displayIdentifier>` 和 `LAHasSeenListener-<listenerName>`。`LAMenuSettings`、`LAHideAds`、`LAHideIcon`、`LAShowHiddenEvents`、`LAIgnoreProtectedApplications`、`LAHasNewCydia`、`LASystemVersionPrompt-<systemVersion>` 以及第三方自定义 preference key 没有当前 v2 runtime 等价模型，应作为 legacy passthrough 数据处理，除非后续 Settings UI 或安装迁移阶段重新定义其语义。
- 资源基线来自 1.9.13：event metadata 使用 `Library/Activator/Events/bundled.plist`，listener/action metadata 使用 `Library/Activator/Listeners/bundled.plist`，目录式 `Info.plist` lookup 只作为第三方扩展兼容路径。
- runtime lookup 必须先走 `jbroot(...)` 后的路径；对历史 metadata 中的绝对路径，可先查 `jbroot(path)`，不存在时再尝试原路径。
- `required-capabilities` 这类设备能力字段属于资源模型有效性，应通过 MobileGestalt 等能力查询参与过滤，不要引入无关重量级 API。`real-home-button` / `fake-home-button` 不是可直接使用 `MGGetBoolAnswer` 的普通 key，应通过 `MGCopyAnswer(CFSTR("HomeButtonType"))` 特殊处理：真机验证中有实体 Home 键返回 `1`，无实体 Home 键返回 `2`；`0` 也是有效返回值，但当前尚未确认它对应哪类设备，不能把它当成未就绪状态或擅自映射。
- 测试和 probe 不要为了构造场景随意写 production resource 目录、用户真实配置目录或没有命名空间的临时文件。优先使用纯内存输入或测试专用 backend/fake；确实需要在 SpringBoard 进程落盘时，使用原始路径 `/var/mobile/Library/Caches/libactivator.tests.*`，不要走 `jbroot`，必须检查写入/创建返回值，并在同一测试中清理。
- listener localization、metadata、small icon 等高频查询应通过专门 cache/service 统一处理，缓存清理策略也应集中管理，例如内存警告时清理 listener metadata cache。
- Dynamic application listener refresh 运行在 SpringBoard runtime 内，只能做注册所需的最小快照：应用 identifier、System/User 分类、LaunchServices 已提供的 hidden/launchProhibited 信号。refresh 阶段禁止读取每个 bundle 的 `Info.plist`、禁止计算或按 display name 排序、禁止为 Settings UI 展示提前准备 metadata。title/group 等展示字段必须在 metadata 查询时懒加载；Settings UI 需要排序时应在 Settings 层单独处理。

## CLI 与安装后处理

- `/usr/bin/activator` 是 production compatibility tool，不是测试入口；不得为了端到端测试增加 1.9.13 不存在的子命令。
- CLI 应复刻 1.9.13 的命令面：`listeners`、`events`、`modes`、`current-mode`、`current-app`、`get <key>`、`set <key> <value>`、`activate <event> [<listener>]`、`send <listener>`、`deactivate <event>`，以及 package maintainer script 内部调用但 usage 不展示的 `postinst`。当前额外允许 DEBUG-only 便利子命令 `set-all <event> <listener>`，它只展开为三个 legacy assignment key：`springboard`、`application`、`lockscreen`。
- CLI 的 `get` / `set` 语义通过 libactivator 私有 preference compatibility bridge 进入 SpringBoard authoritative backend；不要在 CLI 内解析或直接写 preference 文件。
- `postinst` 当前保持 no-op 是有意取舍。1.9.13 的 `activator postinst` 只做安装后兼容清理：在 `kCFCoreFoundationVersionNumber < 1200.0` 时从 `/private/var/mobile/Library/BulletinBoard/SectionInfo.plist` 删除 `com.apple.springboard.notificationcenter.today` 和 `com.apple.springboard.notificationcenter.tomorrow`，删除对应 PushStore 文件，并始终尝试把 `SectionInfo.plist` chown 为 uid/gid `501`。现代 rootless/rootless-era 安装逻辑优先放在 shell maintainer script；只有遇到 shell 不适合表达的安装后操作时，才重新评估是否把逻辑放入 CLI `postinst`。

## Runtime 规则

- runtime state 应采用事件驱动缓存模型，而不是在热路径反复同步主线程查询 UI/SpringBoard 状态。
- `libactivator.dylib` 是 dispatch / assignment owner，并只持有 dispatch 所需的 runtime snapshot：当前 mode、锁屏下层 mode、当前 app display identifier、screen-on 状态，以及 listener dispatch gate 所需的触摸条件入口。SpringBoard hook、Darwin notification、runtime reducer、触摸状态机和私有系统能力调用应收敛在 `ActivatorTweak.dylib` 的 acquisition/capability layer；当前这些职责统一由 tweak-side `LATRuntimeStateSource` 承接，并写入由 SpringBoard-side `LAActivator` 持有的 hidden `LARuntimeContext`。`LARuntimeContext` 是 SpringBoard 服务端上下文，普通 client facade 不应创建本地 runtime cache；`LAActivator` 只在服务端通过 hidden accessor 暴露该 context 给 first-party tweak，并订阅 mode change handler 来发布既有通知，不提供成组 runtime snapshot 写入方法，也不要新增逐项镜像 acquisition source 的 `la_note...` 转发方法。
- 前台 App、主屏幕、App Switcher、锁屏、screen blank 等状态源应来自 SpringBoard 自身 hook 和已验证信号；不要引入 `BKSApplicationStateMonitor` 这类偏重的全局观察者来观察 SpringBoard 自身。
- screen blank 的生产信号源只使用 tweak-side `LATRuntimeStateSource` 中的 `com.apple.springboard.hasBlankedScreen` Darwin notification；不要在其他 helper 或 event source 中重复注册该通知，也不要再 hook `SBBacklightController` 的背光动画方法来更新同一状态。
- 当前 runtime mode 语义：锁屏优先；App Switcher 属于 SpringBoard UI；锁屏下的 underneath mode 按底下真实状态；覆盖层原则上按 underneath mode。
- `_accessibilityFrontMostApplication` 是 SpringBoard 内可用的前台应用来源，但只能由 tweak-side runtime acquisition source 读取。display identifier 语义优先使用 `displayIdentifier`，再 fallback 到 `bundleIdentifier`。
- `requires-no-touch-events` 是 listener-level deferral：触摸活跃时原 event 立即标记 handled，延迟事件冻结 listener name 和 event mode，触摸结束后直接投递给原 listener，不重新跑 blacklist/mode/compat 过滤。触摸采集和 drain 状态机属于 tweak-side runtime layer，libactivator dispatch core 只通过已注册的触摸条件 block 查询和排队。
- 高成本触摸手势采集可以在 tweak-side acquisition layer 使用 assignment-aware runtime gate：例如需要安装 `UIGestureRecognizer`、透明触摸窗口或复杂多指状态机的 family，在当前 mode 对应事件没有 assignment 时应尽量不安装、不启用或快速短路识别；assignment 变化通过 `LAActivatorAssignmentsChangedNotification` 触发重算。这个 gate 只用于降低采集成本，不能替代 dispatch engine 对 assignment、blacklist、mode、no-touch deferral、unlock-to-send 和 listener compatibility 的最终判断；轻量 HID、通知和状态型 event source 默认不需要为了 assignment 停止监听。
- `needs-powered-display` 是 listener-level dispatch gate：listener metadata 或 listener callback 声明需要亮屏时，只有当前缓存的 screen-on 状态为真才进入正常 dispatch。亮屏锁屏仍可 dispatch；熄屏状态下跳过该 listener，不由具体 action listener 重复判断。
- `unlock-to-send` 当前只实现 callback 兼容路径，不实现 passcode submit 或完整主动解锁流程。
- 需要操作 SpringBoard / CoverSheet UI 层级的 SPI 必须在主队列执行；不能因为服务类 SPI 需要避开主队列，就把 UI 控制器方法也放到后台队列。动态应用中的 `com.apple.camera` 锁屏 special case 只表达“打开锁屏相机”，不表达 toggle 或返回锁屏；熄屏时应通过 tweak-side `LATRuntimeStateSource` 发送 Power HID 短按，并等待它接收到 screen-on runtime state 后再提交锁屏相机 UI 切换，不直接调用 `SBBacklightController -turnOnScreenFullyWithBacklightSource:`，也不通过 `LAActivator` facade 承接 screen wake command。
- HID key down/up 事件应使用不同 timestamp 表达短按间隔；投递层仍连续 dispatch down/up，不要同时再用 `dispatch_after` 表达同一段按键时长。
- tweak-side synthetic HID 必须通过 `LATHIDEventSender` 统一发送，并用高位 `senderID` 标记；HID event source 在解析物理按键前应过滤 `senderID` 最高位为 1 的事件，避免 action 发出的 HID 被 built-in event source 回流识别。不要用 `eventFlags` 标记 synthetic keyboard event；实测会导致事件失效。
- `otherListenerDidHandleEvent:` 是全局 handled-edge notification：事件从未处理变成已处理时发送一次，通知除当前处理者以外的已注册 listener；不从当前待分发列表中移除后续 listener。
- `LAEvent.handled` 表示事件已被 listener 消费，不表示 action 最终执行成功。built-in action listener 收到自己 allowlist 内的合法 listener name 后，应在 runtime 层消费事件；缺少目标状态、私有 SPI 不存在、系统调用失败、metadata 运行时失配等执行失败应记录英文诊断，但不应把原始事件继续泄漏出去。只有 unknown listener name、未注册能力、dispatch 前兼容性过滤失败这类“不属于该 listener 处理范围”的情况才保持 unhandled。

## Settings UI 边界

- Settings UI 真实逻辑属于独立动态库 `libactivatorsettings.dylib`，PreferenceBundle、Activator.app 和第三方越狱 App 都只是 host。
- `libactivator.dylib` 只保留 public settings class compatibility shims，让旧第三方代码能链接和解析类名。
- `LASettingsShims.m` 是占位兼容例外，不得作为后续 UI 或 runtime 实现的文件组织范式。
- Settings UI、App、PreferenceBundle 暂不混入 built-in runtime 能力阶段。

## 需要停下来问 owner 的情况

- 现代 SPI 名称、调用时机、线程要求或行为语义不明确。
- 某个旧能力在 iOS 15+ 上可能需要用户 App 注入。
- 某个内置 event/listener/action 的现代实现方式没有可靠证据。
- 旧实现、1.9.13 package、现有 rewrite 行为之间出现非显然冲突。
