# 测试

本文件定义了本项目测试框架的分类、切入点及边界。测试代码中的日志、测试套件名称、测试用例名称及失败原因必须使用英文；本文件可使用中文。

## 执行责任

测试逻辑的执行基于被测行为的所有权。

由运行器拥有的测试会在 `libactivator-tests` 进程内执行断言。 这些测试用于验证非 SpringBoard 客户端视角，例如命令行入口点、IPC 可达性测试、结果聚合、退出代码，以及常规进程中的 `LAActivator` 门面是否通过 IPC 转发至 SpringBoard，以及服务器不可用时的客户端回退行为。 运行器拥有的测试不得直接创建或修改 SpringBoard 的权威运行时状态；当需要 SpringBoard 状态时，必须通过正式的 IPC 或测试 IPC 固定装置进行准备。

由 SpringBoard 拥有的测试会通过隐藏的测试 IPC 在 SpringBoard 进程内执行断言。 任何依赖于 SpringBoard 权威后端、真实监听器对象、事件数据源、内置监听器/操作、分发回调、持久化写入、运行时状态提供者、SpringBoard SPI、主队列设备操作或真实钩子的测试，都必须放置在 SpringBoard 自有测试中。 与 `registerListener:forName:` 和 `registerEventDataSource:forEventName:` 相关的测试也属于此类别。

监视器仅负责观察 SpringBoard 的运行时状态；它们不会执行断言，也不会产生通过/失败的结果。监视器的输出不能作为自动化测试结果使用；它仅用于辅助在实际场景中手动评估状态变化。

默认情况下，稳定测试可能包含由测试运行器管理的测试和由 SpringBoard 管理的测试，但这些测试必须保持稳定且可重现，并且不得破坏真实用户的配置或持久化运行时状态。运行时输入和运行时设备属于特殊类别，不得包含在默认提交阈值中。

## 稳定版测试

默认入口点：

```sh
. scripts/roothide.sh
scripts/run-tests.sh
```

设备端运行器的默认执行方式：

```sh
/usr/libexec/libactivator/libactivator-tests run
```

稳定测试构成了提交门槛，仅涵盖那些稳定、可重复且不会污染 SpringBoard 运行时状态的测试：

- `ClientFacade`
- `LAEvent`
- `持久性`
- `SpringBoardCore`
- `Dispatch`
- `BuiltInActions`

`ClientFacade` 在运行器进程内运行，从普通进程的角度验证公共 API 门面、IPC 转发、远程监听器代理、分配/黑名单/配置文件的往返过程，以及分发处理程序的回调。其他默认的稳定测试套件则通过 SpringBoard 专用的测试 IPC 运行。

稳定版测试不得调用 `la_noteHomeScreenVisible:`、`la_noteLockScreenVisible:`、`la_noteScreenBlanked:` 或任何其他运行时状态注入入口点。若测试失败，则表明核心模型、IPC、分派或已实现的内置操作中存在回归问题。

## 运行时输入测试

命令行入口点：

```sh
/usr/libexec/libactivator/libactivator-tests run-runtime-input
```

运行时输入测试仅验证 `LAActivatorRuntimeStateProvider` 的输入源集合和手动输入语义。 这些测试允许调用 `la_noteHomeScreenVisible:`、`la_noteLockScreenVisible:` 和 `la_noteScreenBlanked:`，但在测试套件开始前和结束后，必须清除运行时输入状态。

运行时输入测试不得执行任何设备自动化操作，例如打开应用、返回主屏幕、锁定屏幕或解锁设备。测试失败表明提供商的输入模型或仅回调的运行时语义存在问题。

## 运行时设备测试

入口：

```sh
/usr/libexec/libactivator/libactivator-tests run-device-runtime
```

运行时设备测试用于验证真实的 SpringBoard 挂钩和设备状态。这些测试仅允许由设备操作和真实的 SpringBoard 状态驱动；禁止调用任何 `la_note*` 运行时状态注入入口点。

运行时设备测试不计入默认提交阈值。测试失败仅表明设备自动化工作流、当前设备状态或实际挂钩场景需要单独调查；这不会阻止核心操作或内置操作的提交。

## 运行时监视器

监视器入口点：

```sh
. scripts/roothide.sh
scripts/watch-runtime-state.sh
```

“观察器”仅输出当前 SpringBoard 运行时状态供手动观察，并非自动化的通过/失败测试。
