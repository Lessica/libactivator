# Testing

本文档定义本项目测试 harness 的类别、入口和边界。测试代码中的日志、suite 名称、case 名称和失败原因必须使用英语；本文档可以使用中文。

## Execution Ownership

测试逻辑按被测行为的所有权划分执行位置。

Runner-owned tests 在 `libactivator-tests` 进程中执行断言。它们用于验证非 SpringBoard 客户端视角，例如命令行入口、testing IPC 可达性、结果汇总、退出码、普通进程中的 `LAActivator` facade 是否通过 IPC 转发到 SpringBoard，以及 server 不可用时的客户端 fallback 行为。Runner-owned tests 不得直接创建或修改 SpringBoard authoritative runtime state；需要 SpringBoard 状态时，只能通过正式 IPC 或 testing IPC 准备 fixture。

SpringBoard-owned tests 在 SpringBoard 进程中通过 hidden testing IPC 执行断言。凡是依赖 SpringBoard authoritative backend、真实 listener object、event data source、built-in listener/action、dispatch callback、persistence 写入、runtime state provider、SpringBoard SPI、主队列设备动作或真实 hook 的测试，都必须放在 SpringBoard-owned tests 中。`registerListener:forName:` 和 `registerEventDataSource:forEventName:` 相关测试也属于这一类。

Watcher 只负责观察 SpringBoard runtime state，不执行断言，不产生 pass/fail 结果。Watcher 输出不能作为自动测试结果，只能辅助人工判断真实场景中的状态变化。

默认 stable tests 可以包含 runner-owned tests 和 SpringBoard-owned tests，但必须保持稳定、可重复，并且不得污染真实用户配置或持久 runtime state。Runtime input 和 runtime device 是专项类别，不得混入默认提交门槛。

## Stable Tests

默认入口：

```sh
. scripts/roothide.sh
scripts/run-tests.sh
```

设备端 runner 默认执行：

```sh
/usr/libexec/libactivator/libactivator-tests run
```

Stable tests 是提交门槛，只覆盖稳定、可重复、不会污染 SpringBoard runtime state 的测试：

- `ClientFacade`
- `LAEvent`
- `Persistence`
- `SpringBoardCore`
- `Dispatch`
- `BuiltInActions`

`ClientFacade` 在 runner 进程中执行，用普通进程视角验证 Public API facade、IPC 转发、远程 listener proxy、assignment/blacklist/profile round-trip 和 dispatch handled 回写。其它默认 stable suites 通过 SpringBoard-owned testing IPC 执行。

Stable tests 禁止调用 `la_noteHomeScreenVisible:`、`la_noteLockScreenVisible:`、`la_noteScreenBlanked:` 或其它 runtime state 注入入口。失败表示核心模型、IPC、dispatch 或已实现 built-in action 出现回归。

## Runtime Input Tests

专项入口：

```sh
/usr/libexec/libactivator/libactivator-tests run-runtime-input
```

Runtime input tests 只验证 `LAActivatorRuntimeStateProvider` 的输入源集合和人工输入语义。它允许调用 `la_noteHomeScreenVisible:`、`la_noteLockScreenVisible:` 和 `la_noteScreenBlanked:`，但必须在 suite 前后清空 runtime input state。

Runtime input tests 不得执行打开 App、回主屏、锁屏、解锁等设备自动化动作。失败表示 provider 输入模型或 callback-only runtime 语义出现问题。

## Runtime Device Tests

专项入口：

```sh
/usr/libexec/libactivator/libactivator-tests run-device-runtime
```

Runtime device tests 验证真实 SpringBoard hook 与设备状态。它只允许通过设备动作和真实 SpringBoard 状态驱动测试，禁止调用任何 `la_note*` runtime state 注入入口。

Runtime device tests 不属于默认提交门槛。失败只说明设备自动化流程、当前设备状态或真实 hook 场景需要单独调查，不阻塞核心或 built-in action 提交。

## Runtime Watcher

观察入口：

```sh
. scripts/roothide.sh
scripts/watch-runtime-state.sh
```

Watcher 只输出当前 SpringBoard runtime state，用于手工场景观察。它不是 pass/fail 自动测试。
