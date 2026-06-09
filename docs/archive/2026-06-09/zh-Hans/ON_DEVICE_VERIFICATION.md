# 设备端验证

本文档记录了需要越狱设备才能完成的手动验证步骤。 在完成相关检查清单之前，请勿将运行时支持的切片标记为“已完全验证” 在设备上运行。

## 自动化设备测试

### 命令

- 首先找到相应的越狱方案，例如 `. scripts/roothide.sh`。
- 运行 `scripts/run-tests.sh`。

### 行为

- 该脚本执行 `gmake do LA_TESTING=1`。
- 测试版本使用 `jbroot(@"/var/mobile/Library/Preferences/libactivator.tests.plist")`。
- 该测试版本仅在以下情况下暴露隐藏的 SpringBoard 测试 IPC： 已定义 `LA_TESTING`。
- 该设备运行程序仅安装在以下路径下的测试包中： `/usr/libexec/libactivator/`。
- 该脚本通过 SSH 运行已安装的设备运行程序。
- 该脚本会在运行程序前后记录 SpringBoard 的 PID，并返回失败 如果 SpringBoard 在测试过程中重启。

### 报道范围

- 核心事件模型、持久化、注册表、分配、配置文件、黑名单， 分发、无接触延迟、解锁后发送回调、状态/配置 IPC，以及 基本运行时模式自动化。
- 设备自动化目前使用 SpringBoard 端的测试 IPC 进行锁定， 解锁、重置主屏幕、打开 `com.apple.Preferences`、休眠以及将应用置于最前 查询。
- 在 iPhone XR 运行 iOS 15.0 并使用 Dopamine 隐藏 root 状态的情况下，当前测试结果为 33 通过 0 个，未通过 0 个，跳过 0 个。

### 诊断

- 使用 `scripts/device-console.sh stream` 来流式传输 SpringBoard 的 USB syslog， backboardd 以及测试运行器。
- 使用 `scripts/device-crashlogs.sh list` 来复制并列出 SpringBoard 崩溃日志 在不从设备中删除报告的情况下。
- 在有针对性地重现崩溃之前，请运行 `scripts/device-crashlogs.sh clean`； 此操作将现有的 SpringBoard 崩溃报告移至 `logs/device-crashlogs/cleared`。
- 使用 `scripts/device-crashlogs.sh pull` 将 SpringBoard 崩溃报告复制到 `logs/device-crashlogs`，且无需从设备中删除这些日志。
- 将 SpringBoard 的 PID 变化作为 SpringBoard 重启的首个触发信号。 在检测到重启后，崩溃报告将用于堆栈诊断。
- 在 SpringBoard 上运行 UIKit、SpringBoard 和 FrontBoard 的私有 API 探测 主队列。
- 请勿将 Frida `-q` 用于交互式或长时间运行的验证。在 已安装 Frida CLI，`-q` 表示静默模式，不显示提示符，并在完成后退出 `-l` 或 `-e`，因此需要处理回调的脚本必须在不带 安静
- 请避免将由 Frida 创建的长期存在的 Objective-C 对象注册到 SpringBoard 注册表。建议优先使用临时方法挂钩进行观察，或者 在结束 Frida 会话之前，请务必显式注销。

## 状态/配置 IPC

### 先决条件

- 在设备上构建并安装当前软件包。
- 安装完成后，请重新启动 SpringBoard。
- 请确认 `ActivatorTweak.dylib` 仅加载到 SpringBoard 中。
- 确认 `libactivator.dylib` 已在 SpringBoard 中加载。

### SpringBoard 服务器

- 使用 `frida -U SpringBoard` 连接到 SpringBoard。
- 确认已调用 `+[CPDistributedMessagingCenter centerNamed:]`，并传入 `libactivator.springboard`。
- 确认已调用 `-[CPDistributedMessagingCenter runServerOnCurrentThread]` 在 Activator 服务器上执行一次。在 iOS 15.0 中，不存在 `-runServer` 选项。
- 请确认 `ActivatorTweak` 并非通过 `com.apple.UIKit` 过滤器进行注入。

### iPhone XR iOS 15.0 Dopamine 越狱 笔记

- 请在执行 Frida 命令时使用项目的虚拟环境。已测试的设备 使用的是 Frida 16.1.4，因此主机工具必须与该主版本/次版本号一致。
- 请仅使用 USB Frida。请勿使用远程 Frida 服务器或转发过的 Frida 此项目的端口。
- 运行 roothide 安装验证，命令为 `. scripts/roothide.sh && gmake do`。
- `ActivatorTweak.dylib` 和 `libactivator.dylib` 在 SpringBoard 中加载后 安装包并重启 SpringBoard。
- `CPDistributedMessagingCenter` 提供了 `-runServerOnCurrentThread` 方法，而不是 在被测设备上运行 `-runServer`。
- `doesServerExist` 对于 `libactivator.springboard` 返回了 true。
- 对 `libactivator.request.available-profile-names` 返回 `Default`。
- SpringBoard内部应用启动自动化应使用 主屏幕上的 `-[SpringBoard launchApplicationWithIdentifier:suspended:]` 队列。`LSApplicationWorkspace` 并非经过验证的 SpringBoard 内部 测试框架的前台激活路径。

### 客户端往返

运行一个链接了 `libactivator.dylib` 的临时客户端进程，并验证：

- `availableProfileNames` 返回的值至少包含 `Default`。
- 在初始状态下，`currentProfileName` 返回 `Default`。
- `assignedListenerNamesForEvent:` 对于未分配的事件会返回一个空数组 活动。
- `assignEvent:toListenersWithNames:` 会更改 SpringBoard 的权威性 任务状态。
- 重复执行相同的赋值操作不会触发本地“assignments-changed”事件 客户端中的通知。
- `unassignEvent:` 仅在存在分配时才会更改状态。
- 重复调用 `unassignEvent:` 不会触发本地赋值变更事件 客户端中的通知。
- `setApplicationWithDisplayIdentifier:isBlacklisted:` 会更改黑名单状态 仅当请求的值与当前值不同时。
- 只有当请求的配置文件是 与当前配置文件不同或有所更新。

### iPhone XR iOS 15.0 Dopamine roothide 客户笔记

- `Activator.app` 目前没有权限。请勿将其用作成功 CPDistributedMessagingCenter 客户端引用，直到其权限被 已定义。
- 处于沙盒环境中的 `Activator.app` 进程无法看到 `libactivator.springboard`；`doesServerExist` 返回 false 且直接 消息返回了 nil。
- 经由 使用 USB Frida 加载已安装的 `libactivator.dylib`。
- 在 `com.apple.Preferences` 中，`availableProfileNames` 返回了 `Default`。
- 在 `com.apple.Preferences` 中，将 `currentProfileName` 更改为 `CodexIPCVerification` 通过门面返回该值，然后恢复 设置为 `默认`。
- 在 `com.apple.Preferences` 中，一个临时黑名单值被修改了，并且 通过外立面进行了修复。
- 在 `com.apple.Preferences` 中，对 `libactivator.ipc-check.event` 已通过门面进行修改并移除。
- 使用临时 SpringBoard 验证了零模式赋值的兼容性 事件数据源。为事件分配模式时，如果未指定模式，则会写入所有兼容的 模式，不指定模式时将使用当前事件模式，取消分配 如果未指定模式，则会移除所有事件模式。
- 已通过临时监听器验证了仅限 SpringBoard 的事件分发。 指定分派、显式分派、兼容性过滤、已处理状态 传播、中止回退、预览、停用广播和黑名单 所有过滤操作均按预期进行。
- 已从一个全新的环境验证了非SpringBoard事件分发IPC `com.apple.Preferences` 进程已加载当前的 roothide 从 SpringBoard 发现 `libactivator.dylib` 路径。已分配分发， 显式分发、中止分发、预览分发、停用广播， 处理后的状态响应以及对属性列表安全的 `UserInfo` 传递均表现正常 不出所料。
- 重新安装 `libactivator.dylib` 后，请重启或重新启动客户端进程； 已经运行的客户端可能仍保留着之前的 dylib 映像。

### 持久性检查

- 在完成分配、加入黑名单或修改配置文件后，请重新启动 SpringBoard。
- 确认状态仍从 `jbroot(@"/var/mobile/Library/Preferences/libactivator.plist")`。
- 确认非 SpringBoard 客户端不会编写自己的运行时首选项 文件。

### 不在承保范围内

- 内置事件分发功能。
- 跨进程监听器对象注册。
- 跨进程事件数据源对象注册。
- 前台应用程序状态。
- 锁屏或主屏幕事件模式。
- 设置 UI 控制器创建。
