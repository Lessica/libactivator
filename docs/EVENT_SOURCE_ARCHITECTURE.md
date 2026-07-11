# Event Source 架构

本文定义 Event Source 的长期内部边界和接入方式。它不跟踪逐项能力状态；未实现 event family 仍以 `BUILT_IN_ROADMAP.md` 和 `BUILT_IN_ACTION_TRACKER.md` 为准。

## 名词与所有权

- Event definition 由 SpringBoard 内的 `LAEventDataSource` 提供。它负责 event name 的 metadata、兼容模式、removal 和 configuration；同一个 event name 只能有一个 definition/configuration owner。
- Acquisition source 由 tweak-local `LATEventSource` 表达。它负责从 HID、通知、SpringBoard hook、手势或系统服务采集信号并发送 `LAEvent`；同一个 event name 可以由多个 acquisition source 产生。
- `availableEventNames` 只表示 definition 已注册，不表示 runtime producer 已存在。Metadata-only event 继续保留在 catalog，但不能被描述为 runtime implemented。
- `LATRuntimeStateSource` 是 runtime snapshot acquisition，不发送 Activator event，不属于 Event Source registry。
- SpringBoard 是 definition、configuration、source lifecycle、assignment-aware interest 和 dispatch 的权威 owner；普通 client 只通过 Public API/IPC 查询 property-list-safe 状态并在本进程创建 configuration controller。

## 一眼看懂 1.9.13 三层与当前实现的对应关系

三层分别回答三个不同问题：第一层回答“系统认识哪些事件”；第二层回答“用户能否创建、配置或删除某个事件实例”；第三层回答“什么时候真的发生了这个事件”。

| 职责 | 1.9.13 | 当前 rewrite | 不负责什么 |
| --- | --- | --- | --- |
| 静态 definition：声明固定 event name、metadata 和兼容模式 | `LADefaultEventDataSource` | `LADefaultEventDataSource` + `Events/bundled.plist` | 不监听硬件或系统状态，不发送事件 |
| 动态 definition/configuration：创建、恢复、配置、删除运行期 event name | `LAMetaEventDataSource` + `LAEventEmitter` + `_LAActivator` emitter registry | provider，例如 `LATNetworkEventDataSource`；definition 注册和 configuration IPC 由 `LAActivator` 提供，ownership diff 由 `LATEventSourceRegistry` 协调 | 不直接采集系统信号，不把 Settings object 跨进程传输 |
| Acquisition：观察系统信号并发送 `LAEvent` | 分散的 hook、observer、recognizer 和 data source 内部逻辑 | 实现 `LATEventSource` 的 acquisition adapter，例如 `LATButtonEventSource`、`LATNetworkEventSource` | 不决定事件如何展示，也不直接写动态配置 |

`LAActivator` 是三层之外的核心总线：它保存 definition/listener 注册关系、assignment，并负责最终 dispatch。`LATEventSourceRegistry` 也不是旧 `LAEventEmitter` 的同名替代物；它主要管理第三层 source 的顺序、生命周期和 interest，同时在动态 source 更新时保证第二层 definition ownership 与第三层 producer catalog 一致。

以固定的按键事件为例：`bundled.plist` 和 `LADefaultEventDataSource` 先让核心认识 event name；`LATButtonEventSource` 再监听按键并发送这个 event；不需要动态 provider。以指定 Wi-Fi 为例：`LATNetworkEventDataSource` 先从配置恢复 `joined-wifi.SSID` definition，`LATEventSourceRegistry` 将该 definition 与 `LATNetworkEventSource` 当前 producer catalog 对齐；网络变化发生后，source 才发送 exact event，并在未 handled 时回退到基础 event。

## 1.9.13 证据与现代取舍

1.9.13 解混淆产物 `ActivatorSpringBoard.arm64.decrypted.i64` 证明旧版已经区分三类能力：`LADefaultEventDataSource` 提供静态 catalog；私有 `LAMetaEventDataSource` 通过 `activator:supportsEventName:` / `activator:addAvailableEventNamesToArray:` 暴露动态 definition；私有 `LAEventEmitter` 通过 configuration controller 和 `eventEmitterWithName:shouldAddNewEventWithConfiguration:` 创建新 event。`_LAActivator` 还维护独立 emitter registry，并提供 `_createNewEventWithConfiguration:forEventEmitterName:`。

旧版 Network、Application、Mail、Notification、Scheduled、Battery Level data source 同时采用动态 definition/configuration 协议；例如 `LAScheduledEventDataSource` 的 `configurationForEventWithName:`、`eventWithName:didSaveNewConfiguration:`、`removeEventWithName:` 会更新持久配置、可用 event 列表和调度状态。这证明“静态 metadata + 动态 definition/configuration + acquisition”是需要补齐的能力分层。

当前 rewrite 不恢复旧 runtime class scan、固定数组、全局 UIKit 注入或旧 emitter 对象模型。现代实现使用显式 composition root、typed protocol、owner-safe registration 和 property-list IPC；IDA 证据只决定能力边界，不决定代码布局。

## Acquisition contract

`LATEventSource` 必须声明稳定的 `eventSourceIdentifier`、当前实例能够产生的 `eventNames`、interest policy、幂等 `start` 和终止型 `invalidate`。可选 `interestEventNames` 只用于表达采集依赖，不会让 source 被索引成这些 event 的 producer；可选 `definitionEventNames` 表示由注入的 dynamic data source 创建的 definition 子集，未声明时才默认与 `eventNames` 相同。

- `LATEventSourceInterestPolicyAlways` 用于低成本或系统状态类 source。
- `LATEventSourceInterestPolicyAssignedInCurrentMode` 用于高成本手势或触摸 source；interest 只由当前 mode 下仍有兼容 listener 的 assignment 决定。
- `invalidate` 必须撤销 observer、monitor、timer、recognizer target 或 pending recognition state，并让后续一次性 hook ingress 安全早退。动态恢复使用新 source 实例，不承诺对 CaptainHook 进行 runtime unhook/re-hook。
- Source 只声明自己当前确实会发送的 event。未来计划中的 name 不得提前进入 source catalog；例如 SpringBoard icon source 在 icon flick 尚未实现时只声明 pinch/spread。
- Composite acquisition 必须区分 producer 与 dependency。例如 fingerprint single-press + slide-in 最终由 fingerprint source 发送，edge source 只把该 name 放入 `interestEventNames`，不能把自己登记成第二个 producer。
- Assignment-aware source 在 mode 改变或 interested-name snapshot 改变时必须清理在途识别状态，即使 source-level interest 仍为 true，避免在旧 mode 开始、向新 mode 派发。

`LATEventSourceRegistry` 在 SpringBoard main queue 上维护 `identifier -> source`、source 的 producer/interest/definition snapshots，以及 `eventName -> ordered producers`。重复 identifier 拒绝注册；event name 的多 producer 合法。Registry 以显式注册顺序启动 source，started 后加入的动态 source 立即启动；移除时先使 registry mapping/interest 失效，再执行终止型 `invalidate`，最后处理 definition ownership。同一个已 invalidated 的 source object 不得重新注册。

## 启动与 hook 边界

启动顺序固定为：初始化 `LAActivator` 及 bundled definitions；构造 `LATRuntimeStateSource`、Event Source registry 和 sources；显式注册 sources；安装 CaptainHook；SpringBoard 完成启动后先启动 runtime state，再启动 Event Source registry，最后开放 IPC server。

Hook 只负责把已声明类型的输入转发给 composition root 持有的 source。Registry/source 尚未 started、已 invalidated 或当前无 interest 时，ingress 必须无副作用早退。需要补抓既有 SpringBoard object 的 source 应在 `start` 或 interest 从空变为非空时扫描，不得在 constructor 期提前修改 UI/recognizer。

## Dynamic definition 与 configuration

动态 provider 负责 configuration/descriptor snapshot、definition registration 和 source diff；acquisition source 不直接写偏好文件，也不同时冒充 metadata registry。

一次动态更新在主队列按以下顺序应用：先验证并发布 immutable in-memory configuration snapshot；再注册新增 definition；再注册或 reload acquisition mapping；从存活 source 删除 name 时，必须先让 reload 后的 producer/interest/definition snapshot 生效，再注销不再引用且仍由该 provider 持有的 definition。只有移除整个 source object 时，registry 才先撤销 mapping/interest、再执行终止型 `invalidate`，最后回收 definition。磁盘写入可以合并，但 Public API/IPC 必须立即看到新的内存状态。

Dynamic provider 不得覆盖 bundled 或 foreign data source。同名 Public API replacement 为兼容行为保留；项目内 provider 必须使用 register-if-absent 与 owner-matching unregister，避免 provider teardown 删除后来者或 bundled fallback。Registry 只回收由自己实际创建的 definition；同一 data source 在 registry 接管前已持有的 definition 不自动转移所有权。

Configuration controller descriptor 只包含 class name 与 bundle path；configuration snapshot 和 save payload 必须是 property-list-safe。UIViewController、NSBundle 或 provider object 不跨 IPC。真实 Settings UI 仍属于 `libactivatorsettings.dylib`，core 只提供查询、descriptor、get/save bridge 和兼容 factory。

当前首个 dynamic provider 是 `LATNetworkEventDataSource`。它从 SpringBoard authoritative preference `LANetworkStatusEvents` 恢复显式配置的 `joined-wifi.SSID` / `left-wifi.SSID`，先更新 immutable snapshot，再通过 registry reload 精确发布 definition 和 producer catalog；删除时先 unassign，再移除 snapshot/definition 并持久化。`LATNetworkEventSource` 只有在 exact name 已配置且 definition 仍可用时才尝试 specific event，未 handled 时 fallback 到 base event。新增 exact event 的 Settings/emitter UI 仍属于后续 Settings 主线。

## 新 Event Source 接入清单

1. 先确认现代 iOS 15+ 的 signal、进程、线程和 capability gate；不确定 SPI 时停止并问 owner。
2. 新建独立 acquisition adapter，实现 `LATEventSource`，准确声明 event catalog、interest policy、start/invalidate 和 pre-start ingress 行为。
3. 如果 event name 来自 bundled catalog，只注册 acquisition source；只有真正动态生成的新 name 才注册新的 `LAEventDataSource` definition。
4. 在 composition root 显式构造、注入依赖并注册；Makefile 继续显式列文件，不使用 runtime class scan 或 wildcard 隐藏接线。
5. Stable tests 至少覆盖 identifier/catalog、启动幂等、invalidate、同 event 多 producer、interest 变化和 metadata-only 不等于 producer。真实 hook、硬件和 UI 副作用按 `TESTING.md` 进入 device-runtime 或手工验收。
6. 更新 roadmap/tracker 的能力状态，但不要因纯架构迁移改变未实现 family 计数。

## 暂不合并的工作

- Handled-default interception 仍是独立设计任务，不进入 Event Source registry 或 interest policy。
- 当前未实现的 22 个 1.9.13 event 仍逐 family 评估，不在一次重构中批量补齐。
- 旧 `LAEventEmitter` 的通用跨进程创建 UI/registry 仍未恢复；当前只落地 Network provider 的 runtime entry 和持久 snapshot，后续 Settings UI 通过明确的 provider bridge 调用，不直接写 plist。
- Event configuration 的 descriptor/get/save 当前是独立 IPC 请求；后续 Settings host 若允许 controller 长时间存活，应给 definition mapping 增加 opaque generation/token，并在 save 时复核，避免 owner 在请求之间替换后把旧 payload 提交给新 provider。
