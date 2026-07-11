# Event Definition 与 Event Source 架构

本文定义动态 Event Definition、Acquisition Source 及两者组合的长期内部边界。逐项能力状态仍以 `BUILT_IN_ROADMAP.md` 和 `BUILT_IN_ACTION_TRACKER.md` 为准。

## 三层能力

三层分别回答三个不同问题：系统认识哪些固定事件；用户能否创建、配置或删除某个动态事件实例；事件什么时候真的发生。

| 职责 | 1.9.13 | 当前 rewrite |
| --- | --- | --- |
| 静态 definition | `LADefaultEventDataSource` | `LADefaultEventDataSource` + `Events/bundled.plist` |
| 动态 provider catalog 与创建 | `_LAActivator` emitter registry + `LAEventEmitter` | `LATEventDefinitionRegistry` + `LATEventDefinitionProvider` |
| Concrete definition 的 metadata/configuration | `LAMetaEventDataSource` / family data source | provider 暴露的 `LAEventDataSource` facet |
| Acquisition | 分散的 hook、observer、recognizer | 实现 `LATEventSource` 的 adapter + `LATEventSourceRegistry` |

`LAActivator` 是三层之外的核心总线，保存 definition/listener mapping、assignment，并负责 configuration bridge 与最终 dispatch。`LATEventDefinitionRegistry` 不发送事件；`LATEventSourceRegistry` 不注册、拥有或删除 definition。

## 1.9.13 证据与现代取舍

1.9.13 解混淆产物 `ActivatorSpringBoard.arm64.decrypted.i64` 证明旧版已经区分三类能力：`LADefaultEventDataSource` 提供静态 catalog；私有 `LAMetaEventDataSource` 通过 `activator:supportsEventName:` / `activator:addAvailableEventNamesToArray:` 暴露 concrete dynamic definitions；私有 `LAEventEmitter` 通过 configuration controller 和 `eventEmitterWithName:shouldAddNewEventWithConfiguration:` 创建新 event。`_LAActivator` 另有 emitter registry、通用创建入口和 existing-event configuration get/save。

Network、Application、Mail、Notification、Scheduled、Battery Level data source 使用了这些动态能力。当前 rewrite 借鉴其一等 provider catalog、创建与 concrete definition 分层，不恢复旧 runtime class scan、固定数组、全局 UIKit 注入或旧对象布局。

## Dynamic Definition Provider

`LATEventDefinitionProvider` 表达一个可独立注册的动态事件 family。Provider 必须提供稳定 identifier、authoritative concrete event-name snapshot、`LAEventDataSource` facet、property-list-safe creation templates，以及通用 `createEventWithTemplateIdentifier:configuration:`。

- Provider 管理 family 规则、stable event-name 生成、immutable in-memory configuration snapshot 和持久化。
- `eventDataSource` 可以返回 provider 自身，也可以返回独立 metadata/configuration object；协议角色不能因此混为一层。
- Creation configuration 用于从 template 创建新 event；existing-event configuration 继续使用 `LAEventDataSource` 的 descriptor/get/save，两者不是同一种 configuration。
- Registry 提供统一的 existing-event configuration 路由与 generation 校验，但具体 provider 只有在其 `LAEventDataSource` facet 实现相应 optional callbacks 时才支持读取或保存；Network 当前只实现 creation/removal，不提供 per-event configuration。
- Provider 必须先临时发布新内存 snapshot，再调用 definition registry reload；registry 失败时恢复旧 snapshot，成功后才持久化。
- Provider 不持有 acquisition source 或 source registry，不直接修改 producer index。

## Event Definition Registry

`LATEventDefinitionRegistry` 在 SpringBoard main queue 上显式维护 ordered provider catalog、`providerIdentifier -> provider`、`eventName -> active provider`、provider declared/active snapshots、registry 实际创建的 definition ownership 和单调递增 generation。

- 注册时拒绝重复 provider identifier、同一 provider 同时附着多个 registry、非法 template descriptor 和 bundled/foreign owner 冲突；composition delegate 必须在首个 provider 注册前设置，并在 provider catalog 非空期间保持稳定。
- `eventCreationCatalog` 返回 generation-bound property list；通用 create、existing-event configuration read/save 和 remove 都要求 expected generation。
- Registry 只回收自己实际创建、且仍由原 data source 持有的 definition；同一 data source 预先注册的 definition 不会被接管。
- Public API replacement 改变同名 definition owner 时，registry 通过进程内 event-registry notification 立即撤销 active provider mapping，并由 composition 撤销 exact producer mapping；provider 的持久 declared snapshot 保留。Foreign owner 移除后，registry 会重新发布仍声明的 definition。
- 已声明但被 foreign owner 接管的 name 保持 declared/inactive，不会阻塞同一 provider 新增或删除其他 name；只有本次新增的 declaration 遇到 foreign owner 才拒绝整个 mutation。
- Provider unregister 或 definition registry invalidate 不会 invalidate acquisition source；source 生命周期与 definition 生命周期相互独立。

一次 provider mutation 必须先预检目标集合并 owner-safe 注册新增 definitions，再暂存 registry mutation、由 composition delegate 同步最终 acquisition mapping；所有 delegate 窗口都处于禁止 registry 重入的 mutation guard 内，delegate 返回后还要复核 provider immutable contract 与每个 active name 的实际 owner。成功后完成 ownership/index 清理，最后递增 generation 并发布 change；失败时把 acquisition mapping 和新增 definitions owner-safe 回滚，provider 随即恢复旧 snapshot，旧 registry/source/persistence 状态保持不变。

`LAActivator` 的私有 event-registry mutation scope 会合并事务内部的 owner-change 与 `LAActivatorAvailableEventsChangedNotification`，等 definition ownership、provider index 和 acquisition mapping 都提交或回滚后再通知 observer，避免把半完成 catalog 暴露给同步回调。

## Acquisition Source

`LATEventSource` 只声明稳定 `eventSourceIdentifier`、当前实例确实能够产生的 `eventNames`、interest policy、幂等 `start` 和终止型 `invalidate`。可选 `interestEventNames` 只表达采集依赖，不产生 definition ownership。

- `LATEventSourceInterestPolicyAlways` 用于低成本或系统状态类 source。
- `LATEventSourceInterestPolicyAssignedInCurrentMode` 用于高成本手势或触摸 source；interest 由当前 mode 下仍有兼容 listener 的 assignment 决定。
- Source 只消费 composition 提供的 immutable acquisition mapping，不写 provider preference，不实现 creation protocol。
- 同一个 event name 可以有多个 ordered producers；metadata-only definition 也可以没有 producer。
- `invalidate` 必须撤销 observer、monitor、timer、recognizer target 或 pending recognition state。已 invalidated 的 source object 不得重新注册。
- Assignment-aware source 在 mode 或 interested-name snapshot 改变时必须清理在途识别状态。

`LATEventSourceRegistry` 只维护 source order、producer/interest snapshots、`eventName -> ordered producers`、start/invalidate 与 assignment-aware interest。Source unregister 和 registry invalidate 永远不得删除 definition。

## Composition 与启动顺序

`LATBuiltInRegistry` 是显式 composition root。它构造两个 registry、provider 和 source，并实现 definition-registry delegate，把 provider 的最终 active event-name snapshot 应用到对应 source 后调用 source-registry producer reload。Definition registry 不认识具体 source，provider 也不认识 source。

启动顺序固定为：初始化 `LAActivator` 和 bundled definitions；构造 source registry 与 sources；先注册基础 acquisition source；构造 definition registry/providers；注册 provider 并通过 delegate 恢复 exact acquisition mapping；安装 CaptainHook；SpringBoard 完成启动后启动 runtime state 和 source registry；最后开放 IPC server。Definition provider 没有 acquisition `start`。

Hook 只把输入转发给 composition root 持有的 source。Registry/source 尚未 started、已 invalidated 或当前无 interest 时，ingress 必须无副作用早退。

## Network 垂直切片

`LATNetworkEventDataSource` 是首个 `LATEventDefinitionProvider`。它从 `LANetworkStatusEvents` 恢复显式配置的 `joined-wifi.SSID` / `left-wifi.SSID`，提供 joined/left creation templates、stable exact name、metadata、removal 和持久化；它不再持有 `LATNetworkEventSource` 或 `LATEventSourceRegistry`。

`LATBuiltInRegistry` 将 provider active snapshot 显式同步给 `LATNetworkEventSource`。Source 只把该 snapshot 视作能够产生的 exact-name mapping；没有 active exact definition 时直接发送 base event，有 exact definition 时先发送 exact event，未 handled 再 fallback 到 base event。删除时先从 producer mapping 移除 exact name，再注销 definition；base Network producer 始终保留。

## 接入清单

新增 dynamic provider 时：

1. 实现 `LATEventDefinitionProvider`，定义 stable identifier、creation templates、authoritative snapshot、data-source facet 和通用 create。
2. 所有 catalog/configuration payload 保持 property-list-safe；provider 先更新内存 snapshot，registry 成功后再持久化。
3. 在 composition root 显式注册 provider，并为需要 acquisition 的 family 实现 delegate mapping；metadata-only provider 可以没有 mapping。
4. 覆盖 duplicate/single-registry registration、foreign conflict、atomic diff/rollback、delegate reentrancy/postflight、pre-owned/replacement owner、generation/notification ordering、teardown 和磁盘恢复测试。

新增 acquisition source 时：

1. 先确认现代 iOS signal、进程、线程和 capability gate。
2. 实现 `LATEventSource`，准确声明 producer/interest catalog 与 start/invalidate。
3. 在 composition root 显式注册 source；不得通过 source 注册 definition。
4. 覆盖启动幂等、terminal invalidate、多 producer、producer reload、interest 变化和 metadata-only 不等于 producer。

## 尚未完成

- Settings host 尚未接入跨进程 provider catalog/create bridge 和 creation UI；当前 generation-bound catalog/create API 只存在于 SpringBoard 内部 registry。
- Existing-event descriptor/get/save 已有 IPC，但 Settings controller 长时间存活时仍需把 definition-registry generation 作为 opaque token 带过 IPC 并在保存时校验。
- Handled-default interception 仍是独立设计任务。
- 当前未实现的 22 个 1.9.13 event 仍逐 family 评估，不因本次架构拆分改变状态。
