# 测试与验证规约

本文件定义项目内测试的分类、执行位置和提交门槛。测试日志、suite 名、case 名、失败原因必须使用英语；本说明文档使用简体中文。

## 默认提交门槛

默认稳定测试入口：

```sh
. scripts/rootless.sh
scripts/run-tests.sh
```

或在 roothide 设备上：

```sh
. scripts/roothide.sh
scripts/run-tests.sh
```

`scripts/run-tests.sh` 的职责是构建并安装 `LA_TESTING=1` testing package，然后通过 SSH 运行设备上已安装的 `/usr/libexec/libactivator/libactivator-tests run`。脚本应报告 SpringBoard pid 前后变化，pid 变化即视为 SpringBoard 重启。

## 执行责任划分

runner-owned tests 在 `libactivator-tests` 进程内执行断言，适合验证非 SpringBoard 客户端视角，例如 CLI 入口、测试 IPC 可达性、结果聚合、退出码、普通进程中的 `LAActivator` facade 是否通过 IPC 转发、server 不可用时的 fallback。

SpringBoard-owned tests 通过隐藏 testing IPC 在 SpringBoard 内执行断言，适合验证 SpringBoard authoritative backend、真实 listener object、event data source、built-in listener/action、dispatch callback、persistence 写入、runtime state provider、SpringBoard SPI、主队列设备动作和真实 hook。

watcher 只负责观察 runtime state，不执行断言，不产生 pass/fail 结果。watcher 输出只能帮助人工判断，不能作为自动化测试通过依据。

## 测试类别

`run` 是默认稳定套件，允许包含 runner-owned tests 和 SpringBoard-owned tests，但必须稳定、可重复、不能污染用户配置或 SpringBoard runtime state。它覆盖 `ClientFacade`、`LAEvent`、`Persistence`、`SpringBoardCore`、`Dispatch`、`Resources`、`TouchActivity`、`BuiltInActions` 等核心能力。

`run-runtime-input` 只测试 `LAActivatorRuntimeStateProvider` 的输入模型，允许调用 `la_noteHomeScreenVisible:`、`la_noteLockScreenVisible:`、`la_noteScreenBlanked:` 等注入入口，但前后必须清空状态，并且不能和真实设备场景连跑。

`run-device-runtime` 只测试真实 SpringBoard hook 和真实设备状态，严禁调用任何 `la_note*` 注入入口。它不属于默认提交门槛，失败说明设备自动化流程、当前设备状态或 hook 场景需要单独调查。

`watch-runtime-state` 只做实时观察，不属于测试。

## 禁止混用

- stable tests 不得调用 `la_noteHomeScreenVisible:`、`la_noteLockScreenVisible:`、`la_noteScreenBlanked:` 或其他 runtime state 注入入口。
- `RuntimeDevice` 不得调用任何 `la_note*` 注入状态。
- 清理逻辑只能恢复为空或安全状态，不能为了“方便测试”制造 `home visible YES`、`lock visible YES` 这类状态。
- 不要把多个 suite 混在一起复用脏状态。需要设备场景、输入模型、核心逻辑时，拆成独立 suite、独立准备、独立清理。
- 不要用 skip 绕过不稳定问题。真实瞬时抖动应通过合理重试、放宽动作后时延或修正自动化流程处理。

## 新增测试放置规则

- 纯模型、序列化、assignment、profile、blacklist、resource manager、cache、IPC codec 这类不依赖 SpringBoard UI 的测试优先放入 stable。
- 需要真实 listener object、data source、dispatch 回调、built-in action 对象、touch tracker drain 的测试，如果行为由 SpringBoard runtime owner 承载，应放入 SpringBoard-owned stable suite。
- 需要打开 App、回主屏幕、锁屏、解锁、App Switcher、强杀 App 的测试默认不进 stable，先放 `run-device-runtime` 或手工观察。
- 为测试而新增 production 入口必须先证明必要性，并用 `LA_TESTING` 宏隔离。普通构建不能包含 testing IPC、testing path 或测试自动化接口。

## API 与静态检查

`scripts/check-public-api.sh` 负责 1.9.13 Public API 的 compile/link/runtime metadata 检查。它不是设备 runtime 测试，但 Public API 或导出符号有变化时必须运行。

静态检查应覆盖：无 Logos、无 direct XPC、无 `CFMessagePort`、无不必要 `libSandy`、无 `ROOT_PATH` 宏族、无用户 App 注入 filter、无直接 `objc_msgSend`、新增代码/注释/日志无中文。

文档-only 改动通常运行 `git diff --check` 即可；代码、资源、脚本改动应按影响范围运行匹配的测试。
