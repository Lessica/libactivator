# 真机交互规约

本文件记录与真机设备交互时必须遵守的方式。设备验证是为了确认 SpringBoard runtime、越狱布局和私有 API 行为；它不是普通代码风格检查的替代品。

## 环境选择

- 当前连接哪类设备，就先 source 对应脚本，例如 rootless 设备使用 `. scripts/rootless.sh`，roothide 设备使用 `. scripts/roothide.sh`。
- 不要混跑默认 rootful scheme 来验证 rootless/roothide 设备。调试 rootless 或 roothide 真机时，构建安装命令必须跟当前设备 scheme 一致。
- 不要在命令中自行兜底定义 `$THEOS`。本项目假设调用环境已经提供正确的 `$THEOS`。
- 不要引入无意义的 `THEOS_DEVICE_USER`、`TARGET_INSTALL_REMOTE`、额外 `rm -rf .theos/_` 或大量 `>/dev/null`。脚本应薄、直接、可读。

## 构建与安装

- rootless/rootful/roothide 的包布局由 Theos 和对应环境脚本处理；实现代码只关心运行时路径转换。
- 测试构建使用 `DEBUG=1`，普通包不能包含 DEBUG-only testing IPC、test runner、测试持久化路径或测试自动化入口。
- 安装后需要重启 SpringBoard，尤其是 IPC server、tweak hook 和 dylib ABI 发生变化时。
- 判断 SpringBoard 是否崩溃或重启，第一信号是 SpringBoard pid 是否变化；crash report 用于随后定位栈。

## 日志与崩溃

- 使用 `scripts/device-console.sh` 抓取设备日志。
- 使用 `scripts/device-crashlogs.sh list` 查看 SpringBoard crash report，使用 `pull` 拉取，使用 `clean` 清理旧日志以便复现。
- SpringBoard 卡死、watchdog timeout 或软重启后，先清理问题构建并重装稳定构建，确保设备能进桌面，再继续调查。
- 诊断日志必须使用英语，避免中文进入运行时日志。

## Frida 诊断边界

- Frida 只用于诊断、探针和临时 hook，不算自动化测试，也不要写进测试结论。
- 只允许 USB Frida，不允许 remote Frida。
- 需要对 SpringBoard 附加 Frida 时通常要提权执行。
- 不要使用 `frida -q` 做交互或长时间观察；当前 Frida CLI 的 `-q` 会 quiet 并在 `-l` 或 `-e` 后退出，容易误判为“Frida 自己断开”。
- 探针脚本如果需要保留，应放在项目内可读位置；不要放到 `/tmp` 后让 owner 看不到实际执行内容。临时探针完成后如果不再有价值，可以删除。
- 不要在 Frida JS 线程直接查询 UIKit/SpringBoard UI 状态；涉及 UI 状态的 probe 必须切到 SpringBoard 主队列。
- 避免把 Frida 动态创建的 ObjC object 长期注册进 SpringBoard registry。优先使用临时 hook 或短生命周期调用，并在结束前清理。

## Frida 主机工具版本

- 连接 Frida server `16.1.4` 的设备时，项目内 `.venv-16` 应固定安装 `frida==16.1.4` 和 `frida-tools==12.3.0`。安装命令使用 `.venv-16/bin/python -m pip install 'frida==16.1.4' 'frida-tools==12.3.0'`，不要只写 `frida-tools` 或宽泛上界让 pip resolver 在不兼容的新版本上反复回溯。

## Frida 17.x 脚本约定

- Frida 17 不再把 `frida-objc-bridge`、`frida-swift-bridge`、`frida-java-bridge` 打包进 GumJS runtime；一次性 CLI / REPL probe 可以依赖 frida-tools 14.x 提供的 bridge，但需要长期保存或复用的 agent 应按 Frida 17 的 ESM/`frida-compile` 工作流显式处理 bridge 依赖。
- 保存到仓库的 probe 必须同时支持 Frida 16.x 和 17.x 运行时。涉及导出符号查找时应使用兼容 helper：优先尝试 Frida 17 的 `Module.getGlobalExportByName(name)` / module object `getExportByName()`，再回退 Frida 16 的 `Module.findGlobalExportByName(name)` / module object `findExportByName()`，最后才回退旧静态 `Module.findExportByName(moduleNameOrNull, name)`。
- 新 probe 不要使用旧的 callback-style enumeration API，例如 `Process.enumerateModules({ onMatch, onComplete })`；应使用 `for (const module of Process.enumerateModules()) { ... }` 这类返回数组的现代写法。
- 新 probe 不要直接调用已移除或版本差异明显的静态 `Module.*` API，例如 `Module.findExportByName()` / `Module.getExportByName()`；应通过上述兼容 helper 调用，避免脚本只能在某一个 Frida 大版本上运行。
- 新 probe 不要使用旧的 `Memory.read*` / `Memory.write*` API；应使用 `NativePointer` 方法，例如 `ptrValue.readU32()`、`ptrValue.writeU32(value)`。
- 需要兼容用户临时运行环境时，probe 应优先采用 Frida 17.x 现代 API，并为 Frida 16.x 当前设备工具链提供明确 fallback；不要为了照顾旧博客示例退回只支持 legacy API 的写法。给 owner 的脚本示例也必须遵守这个兼容策略。

## 手工场景观察

- `scripts/watch-runtime-state.sh` 用于实时观察 runtime state，它不是 pass/fail 测试。
- 手工观察时应明确当前操作步骤，例如从主屏幕打开 App、App-to-App 切换、打开 App Switcher、锁屏下拉、锁屏底下是 App 或主屏幕、强杀 App。
- 观察到的状态差异不要立刻归因于 runtime bug；先确认测试流程是否等价于真实手工路径，尤其是自动化打开 App 与用户手势路径可能触发不同 SpringBoard lifecycle。
- iOS 版本差异要单独记录。iOS 15 与 iOS 16 的 SpringBoard 类名和 hook 点可能不同，不能只针对一台设备做死。
