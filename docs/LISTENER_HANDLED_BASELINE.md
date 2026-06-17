# Listener 语义基准

本文是下一阶段全量 listener 测试和 `event.handled` 语义级对齐的工作基准。它只记录当前推进口径；旧实现证据仍查 `LEGACY_REVERSE_ENGINEERING.md` 和 `docs/archive/`。

## 范围

当前 staged listener catalog 共 119 项。除 `libactivator.watch.haptic.tap` 仍因 Watch 能力和设备差异保留为 metadata-only 外，其余 staged static listener/action 均应存在 runtime listener object、metadata gate 和 SpringBoard stable suite 覆盖。5 个 obsolete social/settings action 已从 staged resource 移除，不恢复。

本阶段不处理未实现 event family、Settings UI、menu listener provider，也不设计 handled-default interception。`event.handled` 复核只回答 listener 收到事件后是否消费该事件；是否吞掉系统默认行为属于独立拦截层设计。

## 当前语义矩阵

| Family | 支持范围 | 当前 handled 基线 | 首轮测试口径 |
| --- | --- | --- | --- |
| Nothing | `libactivator.system.nothing` | 合法 name 立即 `handled = YES`。 | stable 已直接发送并断言 handled。 |
| URL actions | Clock、Settings、Phone URL action | unsupported name 不消费；合法 name 在 URL 解析和打开前先消费，URL 缺失、无效或打开失败不回滚 handled。 | stable 覆盖 allowlist、metadata、URL 解析和 unsupported unhandled；不在 stable 打开真实 URL。 |
| Hardware actions | Media key、volume、brightness、Home/Sleep、screenshot、Spotlight、vibrate、keyboard | unsupported name 不消费；合法 command 在 metadata recheck 和 HID/vibrate 副作用前先消费。 | stable 覆盖 allowlist、selector metadata 和 unsupported unhandled；真实 HID/vibrate 走手工或 device-runtime。 |
| System actions | Modal/system UI、lock、ringer、power、orientation、haptic、back、switcher 等 | unsupported name 不消费；多数合法 command 先消费再提交动作。`system.previous-app` 和 `system.back` 当前按 controller 结果回写 handled，是首轮 1.9.13 对齐重点。 | stable 覆盖 allowlist、selector metadata、特殊 metadata 和 unsupported unhandled；副作用动作不在 stable 直接触发。 |
| Camera action | `libactivator.camera.invoke-shutter` | unsupported name 不消费；合法 name 先消费，再异步执行 shutter/open camera 流程。 | stable 覆盖 allowlist、selector metadata 和 unsupported unhandled；真实相机效果走手工或 device-runtime。 |
| Compose actions | Mail、SMS、Notes compose | unsupported name 不消费；合法 command 在 metadata recheck 和 presenter 副作用前先消费。 | stable 覆盖 allowlist、selector metadata 和 unsupported unhandled；真实 compose UI 不进 stable。 |
| Telephony actions | Answer、disconnect call | unsupported name 不消费；合法 command 在 metadata recheck 和 CoreTelephony 副作用前先消费。 | stable 覆盖 allowlist、selector metadata 和 unsupported unhandled；真实来电场景走手工或 device-runtime。 |
| Dynamic application listeners | SpringBoard 可见应用 listener | 未注册 descriptor 不消费；已注册 application listener 先消费，再提交 app launch 或 lock screen camera path。 | stable 覆盖 descriptor 分类、provider、注册和一个真实可控 dynamic listener dispatch；更广泛 app launch 走 device-runtime。 |

## 推进顺序

1. 对每个 family 查 1.9.13 / old master 证据，确认合法 name、unsupported name、metadata mismatch、动作提交失败和 toggle/deactivate 分支的 handled 语义。
2. 先补无副作用 stable tests：allowlist 全量计数、metadata gate、unsupported unhandled、已确认不会触发系统副作用的 handled 断言。
3. 对会打开 UI、启动 App、发送 HID、修改电话/电源/音频状态的路径，只记录手工 checklist 或 device-runtime 条件，不为了 stable test 增加 production fake。
4. 每完成一个 family，把本文件的“当前 handled 基线”从当前实现描述更新为已对齐结论，并在对应 suite 增加覆盖。

## 验收

每轮 listener 语义审计至少运行 `scripts/run-tests.sh` 和 `git diff --check`。如果修改了真实系统副作用路径，还需要记录对应真机 checklist；stable 通过不能替代 UI/HID/电话/电源类副作用验收。
