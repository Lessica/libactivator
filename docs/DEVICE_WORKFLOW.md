# 真机交互规约

本文件只管真机、SpringBoard、安装、日志、崩溃日志、Frida 和手工观察。普通代码风格与架构边界查 `PROJECT_CONVENTIONS.md`，测试分层查 `TESTING.md`。

## 开始前

- 先确认设备类型，再 source 对应脚本：rootless 用 `. scripts/rootless.sh`，roothide 用 `. scripts/roothide.sh`。
- 不要混跑默认 rootful scheme 来验证 rootless/roothide 设备。构建、安装、测试命令必须跟当前设备 scheme 一致。
- 不要在命令中自行兜底定义 `$THEOS`。本项目假设调用环境已经提供正确的 `$THEOS`。
- 不要引入无意义的 `THEOS_DEVICE_USER`、`TARGET_INSTALL_REMOTE`、额外 `rm -rf .theos/_` 或大量 `>/dev/null`。脚本应薄、直接、可读。

## 构建与安装

- rootless/rootful/roothide 的包布局由 Theos 和对应环境脚本处理；实现代码只关心运行时路径转换。
- 测试构建必须用 `LIBACTIVATOR_TEST_SUPPORT=1` 显式开启 testing IPC、test runner、测试持久化路径和测试自动化入口。普通 debug build 不能因为 Theos 默认 `DEBUG` schema 而包含测试能力。
- 新增或修改 `libactivator.dylib` public symbols 后，如果 tweak target 链接阶段出现这些新符号 undefined，先执行 `gmake -C subprojects/libactivator stage`；需要测试支持符号时使用 `gmake -C subprojects/libactivator stage LIBACTIVATOR_TEST_SUPPORT=1`。
- 安装后需要重启 SpringBoard，尤其是 IPC server、tweak hook 和 dylib ABI 发生变化时。
- 判断 SpringBoard 是否崩溃或重启，第一信号是 SpringBoard pid 是否变化；crash report 用于随后定位栈。

## 日志与崩溃

- 使用 `scripts/device-console.sh` 抓取设备日志。
- 使用 `scripts/device-crashlogs.sh list` 查看 SpringBoard crash report，使用 `pull` 拉取，使用 `clean` 清理旧日志以便复现。
- SpringBoard 卡死、watchdog timeout 或软重启后，先清理问题构建并重装稳定构建，确保设备能进桌面，再继续调查。
- 诊断日志必须使用英语，避免中文进入运行时日志。

## Frida 使用边界

- Frida 只用于诊断、探针和临时 hook，不算自动化测试，也不要写进测试通过结论。
- 只允许 USB Frida，不允许 remote Frida。
- Codex 环境访问 USB Frida 需要提权执行。看到 `Waiting for USB device to appear...` 时，第一步是用正确的 Frida CLI 和 `sandbox_permissions: "require_escalated"` 重跑，不要先归因于 usbmux、transport 或脚本行为。
- 默认使用系统 `frida`，它对应 Frida 17.x。只有 owner 明确指定、任务明确需要低版本 Frida，或某个 probe 已确认只能在旧 runtime 下运行时，才使用 `.venv/bin/frida` 或 `.venv-16/bin/frida`。
- 附加 SpringBoard 使用 `frida -U -n SpringBoard -l <script>`。不要使用 `frida -U SpringBoard -l ...`，该形式可能被 CLI 解析为 spawn 而不是 attach。
- 交互式 Frida CLI probe 需要 PTY 保持 stdin 打开，但 PTY 不能替代 USB 访问提权。
- 不要使用 `frida -q` 做交互或长时间观察；当前 Frida CLI 的 `-q` 会 quiet 并在 `-l` 或 `-e` 后退出，容易误判。
- 探针脚本如果需要保留，应放在项目内可读位置；不要放到 `/tmp` 后让 owner 看不到实际执行内容。
- 涉及 UIKit/SpringBoard UI 状态的 probe 必须切到 SpringBoard 主队列。`AXElement.systemApplication`、`currentApplications`、`visibleElements`、`press` 等 ObjC 调用默认放到 `ObjC.mainQueue`。
- 预期自行结束的 probe 脚本应在完成后 `send({ event: "done" })`；如果脚本需要保持附加用于观察，脚本输出和调用说明必须明确写出来。
- 避免把 Frida 动态创建的 ObjC object 长期注册进 SpringBoard registry。优先使用临时 hook 或短生命周期调用，并在结束前清理。

## Frida 版本约定

- 连接 Frida server `16.1.4` 的设备时，项目内 `.venv-16` 应固定安装 `frida==16.1.4` 和 `frida-tools==12.3.0`。安装命令使用 `.venv-16/bin/python -m pip install 'frida==16.1.4' 'frida-tools==12.3.0'`。
- 保存到仓库的 probe 必须同时支持 Frida 16.x 和 17.x runtime。涉及导出符号查找时，优先尝试 Frida 17 的 `Module.getGlobalExportByName(name)` / module object `getExportByName()`，再回退 Frida 16 的 `Module.findGlobalExportByName(name)` / module object `findExportByName()`。
- 新 probe 使用现代返回数组 API，例如 `for (const module of Process.enumerateModules()) { ... }`，不要使用旧 callback-style enumeration API。
- 新 probe 不要使用旧的 `Memory.read*` / `Memory.write*` API；应使用 `NativePointer` 方法，例如 `ptrValue.readU32()`、`ptrValue.writeU32(value)`。
- 一次性 CLI / REPL probe 可以依赖当前 frida-tools 提供的 bridge；需要长期保存或复用的 agent 应按 Frida 17 的 ESM/`frida-compile` 工作流显式处理 bridge 依赖。

## 手工场景观察

- `scripts/watch-runtime-state.sh` 用于实时观察 runtime state，它不是 pass/fail 测试。
- 手工观察时应明确当前操作步骤，例如从主屏幕打开 App、App-to-App 切换、打开 App Switcher、锁屏下拉、锁屏底下是 App 或主屏幕、强杀 App。
- 观察到的状态差异不要立刻归因于 runtime bug；先确认测试流程是否等价于真实手工路径，尤其是自动化打开 App 与用户手势路径可能触发不同 SpringBoard lifecycle。
- iOS 版本差异要单独记录。iOS 15 与 iOS 16 的 SpringBoard 类名和 hook 点可能不同，不能只针对一台设备做死。
