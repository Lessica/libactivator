# Listener 语义基准

本文是下一阶段全量 listener 测试和 `event.handled` 语义级对齐的工作基准。它只记录当前推进口径；旧实现证据仍查 `LEGACY_REVERSE_ENGINEERING.md` 和 `docs/archive/`。

## 范围

当前 staged listener catalog 共 119 项。除 `libactivator.watch.haptic.tap` 仍因 Watch 能力和设备差异保留为 metadata-only 外，其余 staged static listener/action 均应存在 runtime listener object、metadata gate 和 SpringBoard stable suite 覆盖。5 个 obsolete social/settings action 已从 staged resource 移除，不恢复。

本阶段不处理未实现 event family、Settings UI、menu listener provider，也不设计 handled-default interception。`event.handled` 复核只回答 listener 收到事件后是否消费该事件；是否吞掉系统默认行为属于独立拦截层设计。

## 证据层级

后续文档中“已对齐”只用于证据足够覆盖当前声明的范围。`selector-aligned` 表示已有 1.9.13 IDA selector 证据覆盖具体返回值；`gate-aligned` 表示只证明了 listener metadata gate、unsupported name 和 selector mismatch 处理；`resource-aligned` 表示只证明了 1.9.13 resource/package metadata；`source-aligned` 表示只有旧 master 源码或旧公开实现可对照；`modern-criterion` 表示旧实现和现代实现差异较大，已从旧实现总结 handled 策略并制定当前实现的 request-submission / synchronous-gate 准则；`device-accepted` 表示现代差异已经通过真机验收或 owner 接受。没有 selector 级 IDA 依据时，不再把一整个 family 写成“按 1.9.13 完整对齐”。

## 当前语义矩阵

| Family | 支持范围 | 当前 handled 基线 | 首轮测试口径 |
| --- | --- | --- | --- |
| Nothing | `libactivator.system.nothing` | 合法 name 立即 `handled = YES`。 | stable 已直接发送并断言 handled。 |
| URL actions | Clock、Settings、Phone URL action | `selector-aligned`：1.9.13 `openURLWithActivator:event:listenerName:` `0x8e10` 证明 metadata-backed URL 只有解析出可提交 URL 后才消费；Phone tab hardcoded URL 由旧 master `showPhone*` 源码和 1.9.13 resource/package 对照支撑，真实打开失败不回滚 handled。 | stable 覆盖 allowlist、metadata、URL 解析、缺失 metadata 不消费、hardcoded Phone URL 可消费和 unsupported unhandled；不在 stable 打开真实 URL。 |
| Hardware actions | Media key、volume、brightness、Home/Sleep、screenshot、Spotlight、vibrate、keyboard | `selector-aligned` + `modern-criterion`：media controls、screenshot、vibrate、Home/Sleep 有 1.9.13 selector 返回证据；volume/brightness/keyboard/Spotlight 等 HID-backed modern path 统一采用 metadata gate + HID request 成功排队才 handled，HID client/event 构造失败不消费。`brightness` 是 1.9.13 resource-only/modern extension，`toggle-output-mute` 和 `toggle-on-screen-keyboard` 是 2.x additive。 | stable 覆盖 allowlist、selector metadata 和 unsupported unhandled；真实 HID/media/screenshot/vibrate 走手工或 device-runtime。 |
| System actions | Modal/system UI、lock、ringer、power、orientation、haptic、back、switcher 等 | `selector-aligned` + `modern-criterion`：`LATSystemActionListener` metadata gate 通过后使用 controller 返回值写 handled。能按 1.9.13 selector 可见分支复刻的 controller 已按旧返回值；旧/现代差异较大的 controller 按当前 request-submission / synchronous-gate 准则消费，无法提交当前方案时不消费，异步 completion 或真实 UI 结果失败只记录诊断。`clear-switcher` 为 device-accepted。 | stable 覆盖 allowlist、selector metadata、特殊 metadata 和 unsupported unhandled；副作用动作不在 stable 直接触发。 |
| Camera action | `libactivator.camera.invoke-shutter` | 已按 1.9.13 IDA 证据对齐旧 `_LASimpleListener`：unsupported name 不消费；selector metadata 缺失或不匹配不消费；selector 返回真才消费。当前现代实现只有当场提交 shutter HID 成功时消费；打开/等待 Camera ready 的 pending 分支不消费原事件，但仍保留后续异步拍摄流程。 | stable 覆盖 allowlist、selector metadata、metadata gate、缺失 metadata 不消费和 unsupported unhandled；真实相机效果走手工或 device-runtime。 |
| Compose actions | Mail、SMS、Notes compose | `selector-aligned` + `modern-criterion`：1.9.13 `composeMail` `0x8510`、`composeText` `0x8524` 均 tail-call 旧 composer object 的 `performAction...` 并由返回值决定 handled；`composeNote` `0x8594` 在已有 compose UI 时关闭并返回 true，否则按 presentation 结果返回。当前现代 presenter 采用相同策略：metadata gate 通过后，只有能关闭已有 compose UI 或提交 Mail/SMS/System Paper presentation request 时才消费。 | stable 覆盖 allowlist、selector metadata、合法 metadata gate、缺失 metadata不消费和 unsupported unhandled；真实 compose UI 不进 stable。 |
| Telephony actions | Answer、disconnect call | `selector-aligned` + `modern-criterion`：1.9.13 `answerCall` `0x88b8`、`disconnectCall` `0x89c8` 都是可用 telephony/call state gate 后才返回 true；1.9.13 resource 曾把 `disconnect-call` 写成 `answerCall`，但 binary 存在 `disconnectCall` selector，当前为现代可测语义规范化为 `disconnectCall`。当前 answer 只有存在 incoming call 且已提交 answer request 时消费，disconnect 只有存在 current calls 且已提交 disconnect-all request 时消费。 | stable 覆盖 allowlist、selector metadata、合法 metadata gate、缺失 metadata 不消费和 unsupported unhandled；真实来电场景走手工或 device-runtime。 |
| Dynamic application listeners | SpringBoard 可见应用 listener | `source-aligned`：按旧 `LAApplicationListener` 可见分支对齐；未注册 descriptor 不消费，application mode 目标为当前 App 不消费，其他有 descriptor 的启动路径消费后异步提交。仍未声明为 1.9.13 IDA 完整对齐。 | stable 覆盖 descriptor 分类、provider、注册、missing descriptor 不消费、当前 App 不消费、不同 App/SpringBoard/lockscreen 路径消费；真实 app launch 走 device-runtime。 |

## 推进顺序

1. 对每个 family 查 1.9.13 / old master 证据，确认合法 name、unsupported name、metadata mismatch、动作提交失败和 toggle/deactivate 分支的 handled 语义。
2. 先补无副作用 stable tests：allowlist 全量计数、metadata gate、unsupported unhandled、已确认不会触发系统副作用的 handled 断言。
3. 对会打开 UI、启动 App、发送 HID、修改电话/电源/音频状态的路径，只记录手工 checklist 或 device-runtime 条件，不为了 stable test 增加 production fake。
4. 每完成一个 family，把本文件的“当前 handled 基线”从当前实现描述更新为已对齐结论，并在对应 suite 增加覆盖。

## 验收

每轮 listener 语义审计至少运行 `scripts/run-tests.sh` 和 `git diff --check`。如果修改了真实系统副作用路径，还需要记录对应真机 checklist；stable 通过不能替代 UI/HID/电话/电源类副作用验收。
