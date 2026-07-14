# 测试与验证规约

本文件定义测试分类、执行位置和提交门槛。测试日志、suite 名、case 名、失败原因必须使用英语；本说明文档使用简体中文。

## 默认提交门槛

rootless 设备默认入口：

```sh
. scripts/rootless.sh
scripts/run-tests.sh
```

roothide 设备默认入口：

```sh
. scripts/roothide.sh
scripts/run-tests.sh
```

`scripts/run-tests.sh` 先执行 `gmake -C subprojects/libactivator clean stage LIBACTIVATOR_TEST_SUPPORT=1`，再构建并安装 `LIBACTIVATOR_TEST_SUPPORT=1` testing package，最后通过 SSH 运行设备上的 `/usr/libexec/libactivator/libactivator-tests run`。必须先 stage 测试版 `libactivator`，因为 tweak 测试代码会链接该 image 中仅测试构建存在的 recorder、fake 和注册接口；直接从干净根目录构建会让 dependent target 先链接到 Theos 中旧的 production library。libactivator 与 tweak 的 testing artifacts 使用独立 `obj-testing` 目录，不能与 production object 混用。脚本应报告 SpringBoard pid 前后变化，pid 变化即视为 SpringBoard 重启。

## 测试分层

- runner-owned tests 在 `libactivator-tests` 进程内执行断言，适合验证 CLI 入口、测试 IPC 可达性、结果聚合、退出码、普通进程中的 `LAActivator` facade 是否通过 IPC 转发、server 不可用时的 fallback。
- SpringBoard-owned tests 通过隐藏 testing IPC 在 SpringBoard 内执行断言，适合验证 SpringBoard authoritative backend、真实 listener object、event data source、built-in listener/action、dispatch callback、persistence 写入、runtime context、SpringBoard SPI、主队列设备动作和真实 hook。
- watcher 只负责观察 runtime state，不执行断言，不产生 pass/fail 结果。watcher 输出只能帮助人工判断，不能作为自动化测试通过依据。

## 测试所有权与执行位置

测试源码的 owner、测试代码的 build image 与断言最终执行的进程是三个不同概念。目录和编译归属按 production 组件划分，执行位置再由 IPC 编排；不能因为某项断言在 SpringBoard 中运行，就把所有 suite 都编进 `libactivator.dylib`。

| 测试目录 | Build image | 负责内容 |
| --- | --- | --- |
| `tests/runner` | `libactivator-tests` | 命令编排、testing IPC client、普通进程 facade、结果打印与退出码 |
| `subprojects/libactivator/tests` | testing `libactivator.dylib` | core model、backend、persistence、resource、IPC codec、dispatch 与 runtime snapshot input |
| `subprojects/tweak/tests` | testing `ActivatorTweak.dylib` | built-in Listener、dynamic application listener、Event Source、definition/source registry、真实 hook 与设备自动化 |

SpringBoard 内仍只有一个 testing IPC server 和一个结果流。`LAActivatorTestSupport` 先运行 libactivator-owned suites，再通过仅测试构建存在的 concrete `LAActivatorTestRegistry` 和 typed blocks 调用 tweak-owned suites；具体 registry class 同时提供跨 image 的链接期版本检查。`LATweakTestSupport` 必须在正常 `LATweakInitialize` 完成 built-in composition 后显式注册，不得使用 `+load`、额外 constructor、runtime class discovery 或字符串查找 test coordinator。

测试代码可以沿 production 依赖方向复用下层 testing support，例如 tweak suites 使用 libactivator 的 recorder 或 core fake；反向依赖禁止。`subprojects/libactivator/Makefile` 不得包含 `../tweak` include path，也不得编译 tweak-owned suite。项目自有 concrete class 在所属测试 image 内必须通过真实 header、真实 protocol 和直接 class reference 使用，不得再声明复制方法表的 `LATest...Contract` / `LATest...Catalog` 影子协议，也不得用 `NSClassFromString` 绕过 target ownership。只有目标系统上确实可能不存在的 Apple 私有 class 才允许弱 runtime 探测。

## Suite 定义

- `run` 是默认稳定套件，允许包含 runner-owned tests 和 SpringBoard-owned tests，但必须稳定、可重复、不能污染用户配置或 SpringBoard runtime state。它覆盖 `ClientFacade`、`LAEvent`、`Persistence`、`SpringBoardCore`、`Dispatch`、`Resources`、built-in Listener composition、Event Source composition/acquisition 与 gesture recognizer 等核心能力。
- `run-runtime-input` 只测试 libactivator core 从 SpringBoard-side `LAActivator` 持有的 hidden `LARuntimeContext` 接收 runtime snapshot 后的 Public API 和 dispatch 条件效果。它不测试 tweak-side `LATRuntimeStateSource` 的内部 source set、reducer、touch drain 或 screen wake 细节。
- `run-device-runtime` 只测试真实 SpringBoard hook 和真实设备状态，严禁调用任何 `la_note*` 注入入口。它不属于默认提交门槛，失败说明设备自动化流程、当前设备状态或 hook 场景需要单独调查。
- `watch-runtime-state` 只做实时观察，不属于测试。

## 覆盖矩阵

| 覆盖对象 | 默认位置 | 允许验证内容 | 不应验证内容 |
| --- | --- | --- | --- |
| Core model / serialization / IPC codec | `run` | `LAEvent` 编解码、property-list-safe payload、malformed payload fallback、结果聚合和退出码 | 真实 SpringBoard UI 状态、真实系统服务副作用 |
| Persistence / assignment / profile / blacklist | `run` | 隔离测试 plist、in-memory 先更新、coalesced flush、compat bridge 的可重复行为 | 用户真实配置文件、安装迁移副作用 |
| Resources / metadata | `run` | bundled catalog 数量、required-capabilities、small-icons、selector/url/urls metadata、obsolete/excluded 项 | 把 metadata presence 当作 runtime behavior implemented |
| Built-in listeners/actions | `run` | 中央 class 清单完整性/唯一性/顺序、统一 initializer、listener name 唯一 owner、allowlist、metadata gate、runtime production instance、unsupported name 不消费事件、无副作用的 dispatch 语义 | 打开 URL、启动 App、发送 HID、弹系统 UI、修改 ringer/audio/call 状态 |
| Event Definition registry/provider | `run` | provider identifier/catalog、property-list generic create/config/remove、generation、atomic diff/rollback、delegate reentrancy/postflight owner replacement、foreign/pre-owned/replacement ownership、committed notification visibility、持久化、metadata-only definition | Settings UI、真实系统调度和外设信号 |
| Event Source construction/registry | `run` | 中央 class 清单完整性/唯一性/顺序、统一 nullable initializer、构造期窄协议注入、前置 source typed dependency、optional provider/binding、失败回滚、typed ingress、source identifier/producer catalog、确定性启动、幂等、invalidate、同 event 多 producer、producer reload、assignment-aware interest | runtime class discovery、definition ownership、真实 HID/手势/外设信号、把 metadata presence 当作 producer |
| Runtime snapshot input | `run-runtime-input` | mode/display/screen-on snapshot 对 Public API、通知、dispatch gate、unlock-to-send callback 的影响 | tweak-side hook/source/reducer 细节、真实设备手势或锁屏流程 |
| Real device runtime | `run-device-runtime` | 真实 SpringBoard hook、锁屏/解锁、前台 App、dynamic application listener 的真实外层行为 | 通过 `la_note*` 或 acquisition 注入入口制造状态 |
| Manual checklist / probes | 手工记录或 probe 脚本 | power/headset/media route、URL/HID/system UI 等需要硬件或人工确认的效果 | 作为自动化 pass/fail 结果替代 stable/device-runtime |

## 禁止混用

- stable tests 不得调用 tweak-side acquisition source 的 `noteHomeScreenVisible:`、`noteLockScreenVisible:`、`noteScreenBlanked:` 或其他 acquisition 注入入口；需要验证 lib dispatch core 时，只能通过核心 snapshot testing 入口注入最小状态。
- `run-device-runtime` 不得调用任何 `la_note*` 注入状态。
- 清理逻辑只能恢复为空或安全状态，不能为了“方便测试”制造 `home visible YES`、`lock visible YES` 这类状态。
- 不要把多个 suite 混在一起复用脏状态。需要设备场景、输入模型、核心逻辑时，拆成独立 suite、独立准备、独立清理。
- 不要用 skip 绕过不稳定问题。真实瞬时抖动应通过合理重试、放宽动作后时延或修正自动化流程处理。
- stable tests 不得为了验证 built-in action 效果，在 production listener 内增加 fake opener、fake HID sender、fake ringer controller、fake now-playing launcher、last-action recorder 或类似 `setTesting...` 执行替身。

## 新增测试放置规则

- 新测试首先按被测 production 组件确定物理目录和 build image，再按是否需要权威 backend、真实对象或设备状态确定执行进程；“SpringBoard-owned”不是把 tweak 测试放入 `subprojects/libactivator/tests` 的理由。
- 每个 suite 必须显式导入其 production 类型、recorder 和 fake。`LATestEnvironment` / `LATweakTestEnvironment` 只提供环境准备、清理和同步能力，不得成为隐式导入所有 test/production 类型的 umbrella header。
- Fake 实现真实 production protocol 时属于合理测试替身；复制 concrete class 私有方法集合、仅为了跨 image 消息发送而存在的测试协议不属于 contract，应改为直接使用真实类型。确实需要测试 implementation-private selector 时，优先验证可观察行为；仍有必要时只能在测试实现文件内为真实 concrete class 声明窄 testing category。
- 测试可以直接清理自身命名空间下的 event、listener 与 assignment；临时修改既有 production event 的 assignment、当前 profile、blacklist 或 legacy preference 时，必须先保存原值，并在测试步骤结束后的统一出口显式精确恢复。修改 production 状态后不得提前返回，也不得依赖 Objective-C exception handling 保证清理；通用 cleanup 不得用强制切回 `Default`、清空 production assignment 或覆盖 blacklist 的方式兜底。
- 纯模型、序列化、assignment、profile、blacklist、resource manager、cache、IPC codec 这类不依赖 SpringBoard UI 的测试优先放入 stable。
- 需要真实 listener object、data source、dispatch 回调、built-in action 对象、touch drain 的测试，如果行为由 SpringBoard runtime owner 承载，应放入 SpringBoard-owned stable suite，并优先验证外层 dispatch 行为。
- built-in action stable suite 只覆盖代码 allowlist、metadata/selector gate、runtime registration、obsolete/unsupported name 不注册，以及不产生设备副作用的纯 dispatch 语义。
- 新增或重做 built-in listener/action 的 handled 语义必须先有旧实现依据或明确的现代差异准则；stable tests 可以覆盖无副作用 handled 断言，但不能为了证明真实动作效果而给 production path 增加 fake。
- Static built-in listener construction 的 stable tests 必须把 `LATBuiltInRegistry +builtInListenerClasses` 与独立的 exact ordered class-name baseline 比较，覆盖数量、顺序、重复 class、`LATBuiltInListenerRegistrant` conformance、统一 `initWithBuiltInListenerContext:`、context 不暴露完整 registry、窄 instance provider contract、每个 class 至少一个 supported name，以及跨 class 的 listener name 唯一 ownership。所有 supported name 对 bundled metadata 必须通过 gate，对缺失 metadata 必须拒绝；family suite 应从 `LAActivator -listenerForName:` 取得生产已注册实例，不得用默认 `init` 绕过统一构造入口或创建半初始化对象。
- Event Source construction 的 stable tests 必须把 `LATBuiltInRegistry +builtInEventSourceClasses` 与独立的 exact ordered class-name baseline 比较，覆盖数量、顺序、重复 class、`LATEventSource` conformance 和统一 `initWithEventSourceContext:`。还应覆盖 initializer 返回 `nil` 的安全跳过、context 只能解析已成功构造的前置 source、source/provider 注册失败完整回滚，以及中央 typed protocol query；不得为了测试恢复 runtime discovery、`+load` 或 constructor 自注册。
- 纯动态 source 测试必须从空 producer catalog 注册，覆盖首个 definition 激活 mapping、最后一个 definition 删除后回到 dormant、source object/registry lifecycle 保持不变，以及非法非空 catalog 不被静默归一化成空集。
- 新增 Event Source 必须在 stable 中覆盖统一 `initWithEventSourceContext:` 对窄依赖的提取、source 自声明 catalog、start/invalidate 和 interest 失效；dispatch 测试必须使用显式 adapter/fake，不能允许 source 回退到 `LASharedActivator`。同一 event 的多 producer 是合法关系，重复 source identifier 才应拒绝。
- Source-provided dynamic definition provider 与 registry-owned binding 必须复用 Dynamic provider 的 atomic diff/rollback suite，继续覆盖 definition 先于新增 mapping 可见、移除 mapping 先于 definition 注销、delegate reentrancy/postflight、失败后 provider/source/registry/persistence 全状态恢复；启动组合方式不能削弱既有事务语义。
- Dynamic provider tests 必须覆盖 duplicate identifier、single-registry attachment、property-list catalog/create/config/remove、generation、added/removed/unchanged atomic diff、mapping failure rollback、delegate reentrancy、delegate-side owner replacement postflight、retained foreign-owned inactive declaration、pre-existing same-owner definition 不被 registry 接管、foreign/replacement owner reconciliation、notification observer 只能看到 committed state 和已推进 generation、provider teardown 不影响 source lifecycle、磁盘恢复，以及 metadata-only definition 不被误判为 runtime producer。
- 会打开 URL、启动 App、投递 HID、显示系统 UI、修改 ringer/audio 状态的行为不进入 stable fake path；应通过 Frida probe、`run-device-runtime` 或手工真机清单验证。
- 需要打开 App、回主屏幕、锁屏、解锁、App Switcher、强杀 App 的测试默认不进 stable，先放 `run-device-runtime` 或手工观察。
- 为自动化测试新增的 production 入口必须先证明必要性，并用 `LIBACTIVATOR_TEST_SUPPORT` 宏隔离。Owner 明确要求的命令行手工诊断能力可以用 `DEBUG` 隔离，但 release image 不得包含对应命令、IPC、计数采集或 Usage 文本；普通构建不能包含 testing IPC、testing path 或测试自动化接口。

## DEBUG CLI 手工测试

DEBUG build 的 `activator debug` 提供 assignments 的 `list/get/set/add/remove/clear/reset` 与 dispatch/abort statistics 的 summary、明细、单项查询和 reset；完整参数以 CLI 的 `DEBUG only commands` Usage 为准。Assignment 查询直接读取 SpringBoard 当前 profile 的 authoritative snapshot，不得使用会过滤不兼容或暂时不可用绑定的 Public query 结果冒充原始状态；`debug assignments reset` 只清空当前 profile，`debug stats reset` 只清空进程内 dispatch/abort counters。

## 当前专项清单

`run-device-runtime` 当前可以覆盖真实 home/application/lock/unlock mode、前台 App blacklist、真实 `device locked/unlocked` event dispatch，以及 `com.apple.Preferences` dynamic application listener 的真实启动路径。该入口允许因为自动化不可用而 skip；一旦自动化动作已经执行，目标状态或事件没有到达必须 fail。

power connected/disconnected、headset connected/disconnected、media route / now playing、URL actions、HID-backed actions、system UI actions、ringer/audio/call state actions 暂不进 stable，也不通过 production fake 验证。它们需要硬件、系统 UI 或 SPI 行为确认时，先记录手工真机步骤、Frida probe 证据或后续专门 device-runtime 自动化条件，再决定是否纳入自动化。

## API 与静态检查

- `scripts/check-public-api.sh` 负责 1.9.13 Public API 的 compile/link/runtime metadata 检查，并逐个生产架构校验 `scripts/public-api-abi-manifest.json` 中独立冻结的 binary-only 导出符号及其绑定值。它不是设备 runtime 测试，但 Public API、导出符号或 ABI/value manifest 有变化时必须运行。
- 静态检查应覆盖：无 Logos、无 Objective-C exception handling、无 direct XPC、无 `CFMessagePort`、无不必要 `libSandy`、无 `ROOT_PATH` 宏族、无用户 App 注入 filter、无直接 `objc_msgSend`、新增代码/注释/日志无中文；`subprojects/tweak/events` 的 concrete sources 无 `LASharedActivator`；Event Source 路径无 runtime class enumeration、module/loader/factory 残留和 `+load` / constructor 自注册；concrete source import 与中央 class 清单只出现在 `LATBuiltInRegistry`，其构造循环没有逐类型 initializer 或 capability 分支；static built-in listener 路径没有 factory configuration dictionary、`MissingMetadataReason`、逐类型 initializer 分支、完整 `LATBuiltInRegistry` 依赖或绕过中央 class 清单的单独注册；`subprojects/libactivator/Makefile` 无 tweak include/source，tweak-owned suite 只由 testing `ActivatorTweak` 编译，测试目录无项目自有 class 的 `NSClassFromString` 和复制 concrete 方法表的影子协议。
- 文档-only 改动通常运行 `git diff --check` 即可；代码、资源、脚本改动应按影响范围运行匹配的测试。
