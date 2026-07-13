# 文档入口

本目录根部只保留日常协作会反复读取的工作文档。历史长文、完整调查过程和已经备份的旧版本放在 `docs/archive/`；如果根目录文档与归档文档冲突，以根目录文档为准。

## 每次开工先读

1. `PROJECT_CONVENTIONS.md`：项目硬边界，先确认当前任务有没有触碰 Public API、注入边界、IPC、持久化、runtime ownership、Settings UI 或必须问 owner 的情况。
2. `DEVICE_WORKFLOW.md`：只要需要真机、SpringBoard、安装、日志、崩溃日志、Frida 或手工观察，就先读。
3. `TESTING.md`：只要改了代码、资源、脚本或测试，就先读对应验证入口和测试分层。
4. `LEGACY_REVERSE_ENGINEERING.md`：只要实现或判断旧 Activator 行为，就先查这里的证据索引，再按需回到 `docs/archive/2026-06-17/LEGACY_REVERSE_ENGINEERING.md` 查完整记录。

## 其他活文档

- `BUILT_IN_ROADMAP.md`：内置 event / listener / action 的阶段路线与模块归属。
- `BUILT_IN_ACTION_TRACKER.md`：内置 listener/action 的逐项状态、依据和首次验证方式。
- `EVENT_SOURCE_ARCHITECTURE.md`：Event definition provider/registry、acquisition source/registry、启动组合、binding、generation、lifecycle、interest 与 configuration 的长期内部边界。

## 更新规则

根目录文档只记录会影响后续实现决策的当前结论。临时调查过程、一次性 probe 输出、过时计划和长证据链不要继续塞回根目录；需要保存时放到 `docs/archive/` 或专门调查记录。

`docs/` 目录下的普通段落不要按固定行宽硬换行。文档正文优先使用简体中文；API 名称、命令、状态值、文件路径、类名、方法名、常量名保持原文。
