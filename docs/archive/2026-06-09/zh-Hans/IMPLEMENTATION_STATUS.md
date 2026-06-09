# 实施情况

本文档是重写项目的当前实现跟踪记录。请更新此文档 每当一个实现切片开始、经过验证、被阻塞或 已完成。

## 进展状态

- `未启动`：仅供参考。
- `进行中`：已实现，但尚未完成或未经验证。
- `已完成`：已实现切片所列出的验收标准，并已涵盖 编译/链接或包验证。这并不意味着每个运行时 同一公共选择器家族背后行为的实现已完成。
- `被阻止`：需要项目所有者做出决定，或缺乏运行时信息。

## 当前 `LAActivator` 运行时存在的缺陷

这些差距是特意与 ABI/源代码兼容性分开跟踪的。 切勿将其误认为是已完成的运行时行为。

| 区域 | 当前状态 | 需跟进 |
| --- | --- | --- |
| 活动发布 | SpringBoard 分发引擎支持事件、中止、预览、停用、监听器兼容性过滤、黑名单过滤、无交互延迟分发、解锁后发送回调兼容性以及已处理状态的传播。非 SpringBoard 分发会通过 IPC 转发至 SpringBoard。 | 请分别实现内置事件源。 |
| 跨进程的监听器对象查找 | 非 SpringBoard 的 `listenerForName:` 方法在 SpringBoard 报告监听器存在时，会返回一个私有远程代理。该代理会通过 IPC 转发事件、中止、元数据、图标和移除请求。 | 确保对象注册以 SpringBoard 为权威来源；不要创建孤立的客户端本地运行时状态。 |
| 监听器和事件数据源的注册 | 注册功能仅在权威的进程内后端中有效；非SpringBoard调用不会创建运行时状态。这与旧版`master`的行为一致；无效的非SpringBoard调用会生成详细的运行时日志。 | 确保公共注册由 SpringBoard 负责。 |
| 配置控制器 | `eventWithNameSupportsConfiguration:` 和 `listenerWithNameSupportsConfiguration:` 返回 `NO`；相应的控制器工厂方法返回 `nil`。 | 在“设置”界面阶段，通过 `libactivatorsettings.dylib` 实现设置界面的加载。 |
| 听众图片 | `iconForListenerName:`、`smallIconForListenerName:` 和 `imageForListenerName:usingTemplate:` 会查询监听器对象、监听器资源包、远程监听器代理以及小型应用图标提供程序。 | 在添加内置资源时，请遵循传统的 `master` 资源命名规范。 |
| 运行时模式和前台应用状态 | `LAActivatorRuntimeStateProvider` 通过 SpringBoard 状态钩子、锁屏状态、屏幕熄灭、主屏幕可见性以及 `_accessibilityFrontMostApplication` 来判断当前处于 SpringBoard、应用程序还是锁屏模式。非 SpringBoard 客户端通过 IPC 向 SpringBoard 发起查询。 | iOS 15.0 的 roothide 行为已得到验证；更高版本的 iOS 仍需进行设备验证。 |
| 解锁支持 | `supportsUnlockingDeviceToSendEvents` 使用 SpringBoard 的私有功能检测机制，当事件元数据允许时，锁屏分发器可以为不兼容的监听器调用 `receiveUnlockingDeviceEvent:forListenerName:`。 | 当前的要求是仅支持回调。密码提交和完整的主动解锁流程不属于旧版核心行为。 |
| 移除监听器 | `requestRemovalForListenerWithName:` 会调用 SpringBoard 中的进程内监听器对象，并将非 SpringBoard 调用通过远程监听器代理进行路由。 | “真实设置”界面中的移除操作提示仍然是独立的。 |
| `hasSeenListenerWithName:` | SpringBoard 在监听器注册时记录其名称，并将这些名称持久化存储在 v2 运行时 plist 中；非 SpringBoard 客户端则通过 IPC 进行查询。 | 旧版私有 `ignoreHasSeen:` 注册变体不属于 1.9 公共 API 的一部分，且未被实现。 |
| 本地化资源 | 已实现激活器支持包本地化、事件包本地化、监听器包本地化以及稳定的备用字符串。 | 在设置界面开发工作中添加完整的本地化资源。 |
| 状态/配置 IPC 验证 | 已在 iPhone XR 的 iOS 15.0 roothide 环境中验证了 SpringBoard 服务器的启动以及非 SpringBoard 的 `com.apple.Preferences` 门面层的往返通信。处于沙盒环境中的 `Activator.app` 在其权限未被定义之前无法访问该服务器。 | 继续分别跟踪事件传递和内置功能。 |
| 运行时状态验证 | 已在 iPhone XR 的 iOS 15.0 roothide 系统上验证了运行时状态、无触控分发以及解锁后发送回调代码。 | 请在更高版本的 iOS 上重新验证。 |
| 自动化设备测试 | `scripts/run-tests.sh`、测试包、隐藏的测试 IPC、设备运行器、隔离的测试 plist 以及稳定的 SpringBoard/core 测试套件正在按类别进行拆分。`docs/TESTING.md` 定义了稳定版、运行时输入、运行时设备和监视器的边界。 | 确保默认的稳定性测试不包含运行时状态注入；在设备运行时场景的自动化流程被证实可靠之前，将其作为独立的诊断项处理。 |
| 内置能力清单 | 旧版 `master` 内置事件、监听器/操作、动态监听器家族以及资源元数据已在 `docs/BUILT_IN_CAPABILITY_INVENTORY.md` 中进行了盘点。 | 在实施每项内置行为之前，请利用资源清单选择仅需资源且风险较低的功能。 |
| 内置资源目录 | 61 个事件元数据包、58 个监听器/操作元数据包，以及英语和简体中文的本地化支持文件均已部署在 `/Library/Activator` 目录下。`libactivator.twitter.compose-tweet` 已被有意排除在外；`libactivator.system.safemode` 的元数据则予以保留。 | 元数据的存在并不意味着事件已被捕获或操作已被执行，除非已确认某个特定的内置监听器/操作已被实现。 |

## 追踪器

| 切片 | 进展 | API 类别 | 所有者目标 | 取决于 | 验收标准 |
| --- | --- | --- | --- | --- | --- |
| 公共常量定义 | ✅ | 必须实现 | libactivator.dylib | 无 | 客户端二进制文件中的每个 `extern NSString * const` 和 `LASharedActivator` 链接。 |
| 版本兼容性更新 | ✅ | 必须实现 | `include/Activator`, `libactivator.dylib` | 无 | `LAActivatorVersion_2_0 = 2000000` 存在，且 `-[LAActivator version]` 会返回该值。 |
| 标题现代化 | ✅ | 必须实现 | `include/Activator` | 版本兼容性更新 | 已移除过时的 `<libkern/OSAtomic.h>` 导入，所有受支持的导入仍可编译。 |
| `LAEvent` 模型 | ✅ | 必须实现 | libactivator.dylib | 公共常量定义 | 工厂、初始化器、属性、复制语义以及 `NSCoding` 均可在不依赖运行时服务的情况下正常工作。 |
| `LAActivator` 单例和全局变量 | ✅ | 必须实现 | libactivator.dylib | 公共常量定义 | `+sharedInstance` 和 `LASharedActivator` 功能稳定且完全一致。 |
| 运行时后端与前端的分离 | ✅ | 由运行时支持 | libactivator.dylib | `LAActivator` 单例和全局变量 | `LAActivator` 将状态处理工作转发给私有后端/持久化类型；非 SpringBoard 客户端不会创建持久的隔离状态。 |
| 内存中事件注册表 | ✅ | 必须实现 | libactivator.dylib | `LAActivator` 单例和全局变量 | 事件数据源可以像步骤 2 模型那样进行注册/注销，并在运行过程中驱动元数据查询；在完成 IPC/运行时处理后，SpringBoard 将成为权威数据源。 |
| 内存中监听器注册表 | ✅ | 必须实现 | libactivator.dylib | `LAActivator` 单例和全局变量 | 听众可以像步骤 2 模型那样进行注册/注销，并在运行过程中发起元数据查询；在完成 IPC/运行时相关工作后，SpringBoard 将成为权威数据源。 |
| 任务模型 | ✅ | 必须实现 | libactivator.dylib | `LAEvent` 模型 | 赋值、取消赋值、多监听器、反向查找以及传统的 nil 模式赋值语义在内存中遵循“步骤 2”模型；持久化和基于 IPC 的权限管理则属于独立的切片。 |
| 任务持久化 | ✅ | 必须实现 | libactivator.dylib | 赋值模型，运行时后端/前端分离 | SpringBoard 权威后端会将任务持久化存储至 `jbroot(@"/var/mobile/Library/Preferences/libactivator.plist")`，并进行模式验证和原子写入；无效的 plist 数据将被忽略。 |
| 向后兼容性模型 | ✅ | 必须实现 | libactivator.dylib | 内存中监听器注册表、分配模型 | `listenerNamesAreMutuallyCompatible:` 以及排他性组的行为具有确定性。 |
| 已查看听众追踪 | ✅ | 必须实现 | libactivator.dylib | 内存中监听器注册表、持久化、IPC 服务器 | `hasSeenListenerWithName:` 返回已持久化的 SpringBoard 监听器注册历史记录，而非 SpringBoard 客户端则通过 IPC 进行查询。 |
| 黑名单模型 | ✅ | 必须实现 | libactivator.dylib | 无 | 在第 2 步中，黑名单的查询/更新操作在内存中进行；最终对客户端可见的状态必须由 SpringBoard/IPC 提供支持。 |
| Profile 模型 | ✅ | 必须实现 | libactivator.dylib | 任务模型 | 默认/当前 profile 切换行为是确定的，并已由 SpringBoard/IPC 提供支持；不存在的 profile 当前会创建为空 assignment 命名空间，其语义作为 1.9.x 兼容性问题跟踪。 |
| 黑名单的持久化 | ✅ | 必须实现 | libactivator.dylib | 任务持久化 | SpringBoard 权威后端会将列入黑名单的显示标识符持久化存储在 v2 运行时首选项 plist 中。 |
| 配置文件持久化 | ✅ | 必须实现 | libactivator.dylib | 任务持久化 | SpringBoard 的权威后端会将当前配置文件以及每个配置文件的分配信息保存在 v2 运行时首选项 plist 中。 |
| 本地化资源查询 | ✅ | 必须实现 | libactivator.dylib | 公共常量定义、资源解析器 | 本地化方法会查询 Activator 支持包、事件/监听器包以及确定性备用方案。 |
| 事件数据源注册 | ✅ | 必须实现 | libactivator.dylib | 内存中事件注册表 | 正在处理注册/注销以及向 `LAEventDataSource` 分发元数据。 |
| 默认事件元数据资源 | ✅ | 必须实现 | libactivator.dylib | 资源解析器，事件数据源注册 | 当存在资源时，SpringBoard 会从 `/Library/Activator/Events/<name>/Info.plist` 中注册事件元数据；具体的资源内容则通过内置的 events/resources 进行添加。 |
| 监听器元数据分发 | ✅ | 必须实现 | libactivator.dylib | 内存中监听器注册表、资源解析器、IPC 服务器 | 可选的 `LAListener` 元数据选择器通过 `respondsToSelector:` 进行查询，并回退到监听器资源元数据。 |
| 监听器图标处理流程 | ✅ | 基于设置的 | libactivator.dylib | 监听器元数据分发，IPC 服务器 | 监听器图像 API 用于查询本地监听器对象、资源包中的 PNG 备用图像以及远程代理 IPC。 |
| 远程监听代理 | ✅ | 由运行时支持 | libactivator.dylib | IPC 客户端/服务器，事件分发引擎 | 当 SpringBoard 拥有监听器时，非 SpringBoard 客户端会通过 `listenerForName:` 获取一个私有代理；该代理会将调用转发给 SpringBoard。 |
| 事件分发引擎 | ✅ | 由运行时支持 | libactivator.dylib | 赋值模型、监听器注册表、IPC服务器 | SpringBoard 事件、中止、预览和停用分发调用会注册监听器对象，并支持兼容性过滤和已处理状态的传播；非 SpringBoard 分发调用将通过 `CPDistributedMessagingCenter` 转发至 SpringBoard，并接收已处理状态的回复。 |
| 运行时状态提供程序 | ✅ | 由运行时支持 | `libactivator.dylib`、`ActivatorTweak.dylib` | SpringBoard IPC 服务器 | 运行时模式和当前前台显示标识符由SpringBoard决定，非SpringBoard客户端可通过IPC访问这些信息。 |
| 模式更改通知 | ✅ | 由运行时支持 | `libactivator.dylib`、`ActivatorTweak.dylib` | 运行时状态提供程序 | 当计算事件模式发生变化时，已注册的 SpringBoard 监听器会收到 `didChangeToEventMode:` 事件。 |
| 延迟无接触派送 | ✅ | 由运行时支持 | `libactivator.dylib`、`ActivatorTweak.dylib` | 事件分发引擎 | 常规事件分发会遵守 `requires-no-touch-events` 设置，通过将原始事件标记为已处理，并推迟事件分发直至当前触摸操作结束。 |
| “解锁后发送”回调兼容性 | ✅ | 由运行时支持 | libactivator.dylib | 运行时状态提供程序、事件分发引擎 | 当事件元数据支持“解锁以发送”功能时，锁屏调度器可以为不兼容的监听器调用 `receiveUnlockingDeviceEvent:forListenerName:`。 |
| 公共设置类的封装层 | ✅ | 基于设置的 | libactivator.dylib | 标题现代化 | 当第三方应用仅链接 `libactivator.dylib` 时，公共设置类会解析成功。 |
| 设置界面实现 | 尚未开始 | 基于设置的 | libactivatorsettings.dylib | 公共设置类的模拟层 | Real Settings 的 UI 行为是在设置库中实现的，而不是在 `libactivator.dylib` 中。 |
| `UIImageView (Activator)` 存储 | ✅ | 基于设置的 | libactivator.dylib | 公共设置类的模拟层 | 类别属性可在不加载图片的情况下存储和检索值。 |
| IPC 客户端接口 | ✅ | 由运行时支持 | libactivator.dylib | 安全的占位 API | 当 SpringBoard 不可用时，State/config、dispatch、metadata、remote listener、icon 和 removal 等公共调用将通过 `CPDistributedMessagingCenter` 进行路由，并采用安全的默认值。 |
| SpringBoard IPC 服务器 | ✅ | 由运行时支持 | `libactivator.dylib`、`ActivatorTweak.dylib` | IPC 架构、注册表模型、事件分发引擎 | SpringBoard 会启动 `libactivator.springboard` 消息中心，并处理针对权威后端的状态/配置、分发、元数据、远程监听器、图标以及移除请求，且无需应用注入。 |
| SpringBoard 事件运行时 | 尚未开始 | 由运行时支持 | `ActivatorTweak.dylib` | IPC 状态/配置服务器 | SpringBoard 可以在无需应用注入的情况下获取运行时事件、注册内置功能并分发监听器回调。 |
| 内置事件功能清单 | ✅ | 基于能力的门控 | 文件 | SpringBoard 事件运行时 | 旧版事件名称、资源路径、源文件、SPI 家族、临时现代状态以及首次验证方法均已记录在案，但未实现事件钩子。 |
| 内置监听器/操作列表 | ✅ | 基于能力的门控 | 文件 | SpringBoard 事件运行时 | 旧版静态和动态监听器/操作家族、资源路径、源文件、SPI 家族、现代状态（暂定）以及首次验证方法均已记录在案，但未实现相关操作。 |
| 内置资源目录 | ✅ | 基于能力的门控 | 布局资源 | 内置事件功能库，内置监听器/动作库 | 静态事件和监听器/操作元数据，以及英语和简体中文本地化资源已部署到预发布环境。 |
| 内置事件实现 | 尚未开始 | 基于能力的门控 | 运行时适配器 | 内置事件功能清单 | 每个活动系列在注册前都会进行现代 iOS 功能评估和验证。 |
| 内置监听器/操作实现 | 进行中 | 基于能力的门控 | 运行时适配器 | 内置监听器/操作列表 | `libactivator.system.nothing` 已由 SpringBoard 测试 IPC 套件实现并覆盖；每个新增的内置监听器/操作在注册前，都需要经过现代 iOS 功能评估并获得验证结果。 |
| API 兼容性测试客户端 | ✅ | 必须实现 | 测试/检查脚本 | 公共常量、`LAEvent`、`LAActivator` 骨架 | 编译/链接/运行时元数据检查会导入所有入口点，并验证来自 1.9 头文件的公共符号、选择器、属性和协议。 |
| 设备集成测试框架 | 进行中 | 由运行时支持 | `subprojects/tests`，测试进程间通信（IPC） | IPC 服务器，运行时后端 | `scripts/run-tests.sh` 仅运行稳定版测试。运行时输入、运行时设备和监视器属于不同类别，相关说明详见 `docs/TESTING.md`。 |
| 包/导入验证 | ✅ | 必须实现 | Theos 软件包 | 基础框架 | 已构建 rootful/rootless/roothide 包；支持的导入样式已编译。 |
