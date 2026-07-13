# 项目规约

本文件是当前重写工作的硬边界。它不是旧实现笔记，也不是所有细节的收纳箱；旧证据查 `LEGACY_REVERSE_ENGINEERING.md` 和 `docs/archive/`，内置能力排期查 `BUILT_IN_ROADMAP.md` / `BUILT_IN_ACTION_TRACKER.md`。

## 开工闸门

- 先判断任务是否触碰 Public API、runtime ownership、注入范围、IPC、持久化、资源 metadata、SpringBoard 私有 API、真机验证或测试分层；触碰就先读对应根文档。
- 先查 1.9.13 基线、Public API 和旧实现证据，再做实现判断；不确定时记录待决策点并问 owner。
- 保持改动范围单一，不把无关重构、历史清理或测试框架调整混入当前任务。
- 与用户交流使用简体中文；代码、注释、日志、诊断文本、测试名和提交信息使用英语。

## 基线

- 当前兼容基线是 `references/latest` 中的 Activator `1.9.13~rc6`，包括 Public API、导出符号和内置资源 catalog。
- `references/master` 是旧实现语义参考，不能照搬实现；当它与 1.9.13 Public API 或资源基线冲突时，以 1.9.13 为准。
- `references/headers` 中的 1.9.0 headers 只作考古参考，不再作为兼容决策依据。
- 新版本线按 2.x 维护；最低系统版本为 iOS 15.0；构建使用 Theos、`$THEOS` 中的 iOS 16.5 SDK、`arm64 arm64e`。
- 必须支持 rootful、rootless、roothide。布局差异优先交给 Theos / theos-roothide；运行时路径必须通过 `jbroot(...)` 等 roothide 入口处理。
- 不提交 `references/`。它只是本地参考快照。

## 兼容契约

- Public API 的类名、协议名、selector、常量、通知名和 import 入口是兼容契约：`#import <libactivator.h>`、`#import <Activator/Activator.h>`、`@import Activator` 都必须持续可用。
- 旧 API 中过时或不再实现的部分要保留 source/ABI 兼容符号，并明确标为 deprecated 或 no-op。
- 不确定的 SPI 不许编造实现，也不要靠联网搜索拼答案；先留下占位和待决策点，然后问 owner。
- 原实现使用过的 iOS SPI 默认视为失效；原实现使用过的 Public API 必须确认 iOS 16.5 SDK 下的现代用法后才能采用；不得新增使用 deprecated API。
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
- 独立 App 使用 `LAApp` 前缀；Settings UI 使用 `LAS` 或 `LASettings`；Settings preference panel 使用 `LAP` 或 `LAPreferences`。
- 不使用 `LibActivator` 这种旧式命名。

## 代码风格

- 头文件使用 Xcode 默认风格 copyright，并补齐 `NS_ASSUME_NONNULL_BEGIN/END`。
- 新代码默认使用 ARC。除非 Theos/runtime 边界确实需要，否则不要写手动内存管理。
- 私有接口必须先声明再调用；禁止直接调用 `objc_msgSend`。
- ObjC SPI 应声明原始私有类型、category 或 class extension 后直接调用，不要用本地 `@protocol LAT...` / `id<LAT...>` 伪装私有类型能力集合。
- 如果某个私有 SPI 值已经可以合理断定原始类型，就必须用该原始类型表达；只有 property-list、metadata、notification token、弱探测得到的 class object 或确实无法静态断定类型的动态边界，才保留 `id`。
- 已持有原类型实例时，应声明 selector，必要时用 `respondsToSelector:@selector(...)` 做兼容检查，然后直接发送 Objective-C 消息；不要用 `NSSelectorFromString` + `methodForSelector` 绕过编译器。
- 只有需要避免强引用 ObjC class 本体、或类在目标系统上可能不存在时，才用 `NSClassFromString` 获取 class；获取实例后仍应 cast 到原始私有类型并按声明调用。
- C SPI 单个函数可在使用它的 `.m` 内 `extern` 声明；一组相关函数、结构体、枚举或常量才抽成 tweak-local private header。
- 允许链接已明确决策的私有 framework，例如 `CoreTelephony`、`BackBoardServices`、`MediaRemote` 和 `SpringBoardServices`；只有 framework 不可直接链接、符号跨系统版本高度不稳定、或确实需要 weak runtime probing 时，才使用动态解析并记录原因。
- UIKit、SpringBoard、FrontBoard 私有 UI API 默认在主队列调用，除非已经确认该 API 线程安全。
- SpringBoard 内的 SBS/FBS 启动类 SPI 不得从主队列发起，也不得在同步 IPC handler 中同步等待其返回；listener 应只提交异步请求并按 `LAEvent.handled` 语义消费事件，实际失败用英文日志诊断。
- 默认线程模型是 SpringBoard main queue confined。允许的非主队列只有对象内部私有串行队列，或少数 listener/action 为避免外部系统服务 IPC 反向同步卡住 SpringBoard 主队列而提交的异步系统服务调用；其他后台队列使用必须说明理由。
- 用 GCD 和 `dispatch_once` 管理并发与单例，不使用 `@synchronized(self)`。
- 只有全局兼容入口或天然进程级 service 才保留单例，例如 `LAActivator` facade 和 resource manager；有明确生命周期 owner 的 helper/service 应由 owner 持有或注入。
- 一个实现文件默认只放一个主要类。多个类堆在一个 `.m` 里只允许用于明确记录过的兼容 shim 或极小私有局部类型。
- 不要在 ObjC 实现的同一个源码文件中声明本实现自己的私有方法；Class extension 只用于属性、实例变量、协议采纳或确实需要暴露给同文件其他类型的声明。
- 含有 ObjC 类 `@implementation` 的实现文件中，类相关逻辑禁止写成 C helper；纯 C callback、CaptainHook hook glue、C SPI trampoline 这类由 C ABI 要求的入口可以保留。

## IPC、数据与资源

- IPC 使用 `AppSupport` 的 `CPDistributedMessagingCenter`，server name 固定为 `libactivator.springboard`。
- 不引入 direct XPC、`CFMessagePort`、自定义 timeout 或 version negotiation。客户端和 SpringBoard server 一体分发，安装后需要重启 SpringBoard。
- 当前没有具体沙盒穿透需求时不引入 `libSandy`；如果未来某个 system service bridge 需要穿透沙盒，只为那个具体 bridge 引入。
- IPC payload 只使用 property-list-safe dictionary。`LAEvent` 跨进程只传 `EventName`、`EventMode`、`EventHandled` 和 property-list-safe `UserInfo`。
- `LAIPCServer` 只能是 transport adapter；业务规则、通知触发、listener/resource fallback、dispatch sequencing 不应放在 IPC server 里。
- Public change notifications 是进程内 `NSNotification` 名称。跨进程传播使用私有 Darwin notification 名称，再由各进程 facade 重新投递本地 public notification。
- v2 运行时偏好路径固定为 `jbroot(@"/var/mobile/Library/Preferences/libactivator.plist")`；`LIBACTIVATOR_TEST_SUPPORT=1` 测试构建使用隔离路径，不读取或写入用户真实配置。
- 非 SpringBoard 客户端不得写运行时持久化文件。无效或不可读 plist 当作不存在；不删除、不重命名、不备份、不立即覆盖。
- 配置变更先更新 SpringBoard in-memory state，磁盘写入可以在 main run loop 合并 flush；Public API 或 IPC 应返回最新内存状态。
- 所有 assignment mutation 入口，包括 Public API、IPC 和 `_setObject:forPreference:` legacy compatibility bridge，都必须在 SpringBoard authoritative state 实际改变后同步发布同一条进程内 assignment change notification；不得依赖后续 mode/profile/UI lifecycle 变化补做 Event Source interest 刷新。
- 持久化文件写入后使用旧式兼容权限 `0666`，并设置 `NSFileProtectionNone`。
- 资源基线来自 1.9.13：event metadata 使用 `Library/Activator/Events/bundled.plist`，listener/action metadata 使用 `Library/Activator/Listeners/bundled.plist`，目录式 `Info.plist` lookup 只作为第三方扩展兼容路径。
- runtime lookup 必须先走 `jbroot(...)` 后的路径；对历史 metadata 中的绝对路径，可先查 `jbroot(path)`，不存在时再尝试原路径。
- 测试和 probe 不要写 production resource 目录、用户真实配置目录或没有命名空间的临时文件。需要在 SpringBoard 进程落盘时，使用原始路径 `/var/mobile/Library/Caches/libactivator.tests.*`，不要走 `jbroot`，并在同一测试中清理。
- Dynamic application listener refresh 只能做注册所需的最小快照：应用 identifier、System/User 分类、LaunchServices hidden/launchProhibited 信号。禁止在 refresh 阶段读取每个 bundle 的 `Info.plist`、计算或按 display name 排序、提前准备 Settings UI metadata。

## Runtime 规则

- runtime state 采用事件驱动缓存模型，不在热路径反复同步主线程查询 UI/SpringBoard 状态。
- 禁止为了发现或补找私有 UI owner 扫描 SpringBoard 的 window/view hierarchy，也禁止递归遍历全局 view tree 作为 lifecycle hook 漏接后的兜底。应在明确的 owner、初始化或生命周期 hook 中采集所需实例，并使用弱引用维护最小实例清单。
- Public `LAEventDataSource` 只表示 event definition/metadata/configuration owner；tweak-side `LATEventSource` 才表示 runtime acquisition producer。一个 event name 只能有一个 definition owner，但可以有多个 acquisition producer。
- 禁止使用 `objc_getClassList`、`objc_copyClassList` 或同类全进程枚举扫描 SpringBoard、系统 framework 或其他非本项目 image 的 class 来发现私有能力、UI owner 或 Event Source module。Event Source module discovery 只允许对明确的 libactivator-owned image 调用 `class_getImageName` 与 `objc_copyClassNamesForImage`，再按项目私有 module protocol 过滤；不得把 class 名称前缀或任意 `NSObject` subclass 当作模块资格。
- Event Source module 不得通过 `+load`、constructor 或其他隐式副作用自行注册 source/provider。Composition loader 负责发现 module factory、校验稳定且唯一的 module identifier、解析依赖与 capability，并在满足依赖拓扑后按 priority 和 identifier 稳定排序，再把 module result 显式提交给 SpringBoard main queue confined 的 registries。一对一的 Event Source family 默认由 concrete source class 通过私有 class-side category 采用 module protocol，不得为它平行新增只做构造转发的 `*EventSourceModule` class/file；只有一个稳定 domain module 确实组合多个 source 或无法由任一 source 表达 ownership 时，才允许独立 factory class。
- Event Source module graph 是 SpringBoard 启动期的不可变 composition；typed ingress 可以缓存该次装载结果。运行期动态能力由 definition provider、binding 与可变 producer catalog 提供，不能把现有实现描述成支持 module 热装卸；变更 module 集合仍需要 respring。
- `LATBuiltInRegistry` 在 Event Source 路径中只创建共享基础设施、启动 composition loader 并持有装载结果，不逐项 import、构造或注册具体 Event Source family。Source class 的 class-side module factory 接收明确的构造环境并返回 sources、definition providers、typed hook ingress/services 与需要的 definition/acquisition binding；`LATRuntimeStateSource` 不发送 `LAEvent`，不得注册成 Event Source。
- `subprojects/tweak/events` 按职责分为 `core`、`definitions`、`sources`、`recognizers`。Core 保存 composition、dispatch 与 registry 基础设施；definitions 保存 dynamic definition provider、registry 与 binding；sources 保存系统输入 acquisition adapter 及其 class-side module factory；recognizers 只保存可复用识别算法和状态机。不要恢复按每个 source 镜像一份文件的 `events/modules` 目录。
- Concrete Event Source 不得取得 `LASharedActivator` 或自行查找核心 service。Event dispatch、abort/deactivate、current mode、definition/assignment query 等能力必须按实际需要通过窄协议注入；hook glue 只调用 module result 暴露的 typed ingress protocol，不依赖具体 source class 或中央 registry 的逐类型 property。
- 高成本 source 的 assignment-aware interest 默认从真实 producer catalog 推导；composite acquisition 可以用 `interestEventNames` 声明额外依赖，但这些 name 不进入 producer index。不得在独立 enum/switch 中维护第二份 gate 清单，也不得提前声明尚未实现的 event。
- `LATEventSourceRegistry` 只管理 acquisition lifecycle、producer index 和 interest；不得注册、拥有或回收 event definition。Source 不得写 provider preference 或实现 dynamic creation protocol。
- Registry 必须允许合法的空 producer catalog，使纯动态 source 能以 dormant 状态存在并在第一个/最后一个 concrete definition 增删时原子激活或休眠；空集合法，但包含非字符串或空字符串的 catalog 仍属于 source contract 错误。
- Dynamic definition 只能由显式注册到 `LATEventDefinitionRegistry` 的 `LATEventDefinitionProvider` 创建和持久化。Provider identifier、creation templates、catalog/configuration payload 必须稳定且 property-list-safe；existing-event configuration 与 provider-level creation configuration 必须分开表达。
- 一个 provider 同时只能附着一个 definition registry；composition delegate 必须在首个 provider 注册前设置，并在 provider catalog 非空期间保持稳定。
- Provider mutation 必须先临时发布 authoritative immutable snapshot，再由 definition registry 预检并注册新增 definition、暂存 registry mutation、通过 composition delegate 更新 source mapping；delegate 窗口必须禁止 registry 重入，返回后必须复核 provider immutable contract 与实际 owner。成功后完成 owner-safe ownership/index 清理，最后递增 generation 并发布 change，失败时恢复旧 provider/source/registry 状态，成功后才持久化。
- Definition mutation 必须使用 `LAActivator` 私有 event-registry mutation scope 合并事务内的 owner/public availability notifications；observer 只能看到完成提交或完成回滚后的 definition/provider/acquisition 状态。Retained foreign-owned declaration 保持 declared/inactive，不得阻塞同 provider 的无关 mutation。
- Definition provider 与 acquisition source 不得互相持有；需要同步 dynamic definition 与 acquisition mapping 时，由同一 module result 声明稳定 binding，再由 composition loader 在 definition-registry delegate 事务内应用。Provider unregister、source unregister 及任一 registry invalidate 都不能隐式决定另一层对象的生命周期。
- `libactivator.dylib` 是 dispatch / assignment owner，并只持有 dispatch 所需的 runtime snapshot；SpringBoard hook、Darwin notification、runtime reducer、触摸状态机和私有系统能力调用属于 `ActivatorTweak.dylib` 的 acquisition/capability layer。
- 当前这些 acquisition 职责由 tweak-side `LATRuntimeStateSource` 承接，并写入 SpringBoard-side `LAActivator` 持有的 hidden `LARuntimeContext`。普通 client facade 不应创建本地 runtime cache。
- 前台 App、主屏幕、App Switcher、锁屏、screen blank 等状态源应来自 SpringBoard 自身 hook 和已验证信号；不要引入 `BKSApplicationStateMonitor` 这类偏重全局观察者来观察 SpringBoard 自身。
- `_accessibilityFrontMostApplication` 只能由 tweak-side runtime acquisition source 读取。业务代码不能把 raw foreground display identifier 直接当作“当前前台 App”；只有 runtime 已确认当前 mode 为 `application` 时才可信。
- 业务代码应读取 `displayIdentifierForCurrentApplication` 这类已按 runtime mode 过滤后的值，或者先显式判断非锁屏 / 非 SpringBoard UI 前提。
- `requires-no-touch-events` 是 listener-level deferral：触摸活跃时原 event 立即标记 handled，延迟事件冻结 listener name 和 event mode，触摸结束后直接投递给原 listener，不重新跑 blacklist/mode/compat 过滤。
- `needs-powered-display` 是 listener-level dispatch gate：只有当前缓存 screen-on 状态为真才进入正常 dispatch；熄屏状态下跳过该 listener，不由具体 action listener 重复判断。
- `unlock-to-send` 当前只实现 callback 兼容路径，不实现 passcode submit 或完整主动解锁流程。
- 需要操作 SpringBoard / CoverSheet UI 层级的 SPI 必须在主队列执行；服务类 SPI 需要避开主队列时，不得把 UI 控制器方法也放到后台队列。
- tweak-side synthetic HID 必须通过 `LATHIDEventSender` 统一发送，并用高位 `senderID` 标记；HID event source 在解析物理按键前应过滤该标记，避免 action 发出的 HID 被 built-in event source 回流识别。
- `otherListenerDidHandleEvent:` 是全局 handled-edge notification：事件从未处理变成已处理时发送一次，通知除当前处理者以外的已注册 listener；不从当前待分发列表中移除后续 listener。
- `LAEvent.handled` 表示事件已被 listener 消费，不表示 action 最终执行成功。built-in action 的消费时机必须按 1.9.13 selector 返回值、资源 metadata、旧源码或已接受的现代差异逐项确定；不能把 allowlist 内的合法 listener name 默认等同于消费事件。执行失败是否回滚 handled 也按该 listener 的已落盘语义决定。不得为了对齐 handled 语义而改变已经选定的现代实现方案；只能在方案不变的前提下对齐可对齐的返回值。旧实现和现代实现差异较大时，应从旧实现总结 handled 策略，制定当前方案的现代 handled 准则，例如 request-submission 或 synchronous-gate，并按该准则实施；仍无法决定的分支才记录为 `partial` 或待决策差异。

## CLI 与 Settings UI

- `/usr/bin/activator` 是 production compatibility tool，不是测试入口；不得为了端到端测试增加 1.9.13 不存在的子命令。
- CLI 的 `get` / `set` 语义通过 libactivator 私有 preference compatibility bridge 进入 SpringBoard authoritative backend；不要在 CLI 内解析或直接写 preference 文件。
- `postinst` 是隐藏安装后入口；当前只允许执行 shell maintainer script 不适合表达的安装后修复，例如为 `jbroot(/usr/libexec/activator/user-reboot)` 设置 root:wheel 与 setuid/setgid mode。其他现代 rootless/rootless-era 安装逻辑仍优先放在 shell maintainer script。
- Settings UI 真实逻辑属于独立动态库 `libactivatorsettings.dylib`，PreferenceBundle、Activator.app 和第三方越狱 App 都只是 host。
- `libactivator.dylib` 只保留 public settings class compatibility shims，让旧第三方代码能链接和解析类名。
- `LASettingsShims.m` 是占位兼容例外，不得作为后续 UI 或 runtime 实现的文件组织范式。

## 停下来问 owner

- 现代 SPI 名称、调用时机、线程要求或行为语义不明确。
- 某个旧能力在 iOS 15+ 上可能需要用户 App 注入。
- 某个内置 event/listener/action 的现代实现方式没有可靠证据。
- 旧实现、1.9.13 package、现有 rewrite 行为之间出现非显然冲突。
