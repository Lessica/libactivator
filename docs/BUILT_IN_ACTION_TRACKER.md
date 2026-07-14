# 内置能力跟踪表

本表只跟踪 built-in listeners/actions 与 built-in events 的剩余欠账、移除项和遗留复核点。已明确完成的能力不再在根目录重复列明；需要完整历史清单时查 `docs/archive/2026-06-17/BUILT_IN_ACTION_TRACKER.md`。

## 规则

- `listener` 在 Activator 语义里通常就是 action executor：它是被 assignment 选中的响应器，也是实际完成动作的主体。
- 同一个 listener class 可以注册到多个 listener name。name 决定 metadata、标题、分组、URL 或 selector；class 决定 runtime 行为。
- Metadata presence 不等于 runtime behavior implemented。只有注册了真实 `LAListener` object 的 name 才能进入 `availableListenerNames` 并处理事件；只有存在 event source hook/adapter 的 event name 才能被真实触发。
- 1.9.13 资源 catalog 是当前内置能力范围的主要依据；旧 master 只用于证明历史承载方式和语义，不用于照搬实现。
- 状态值：`candidate` 表示可作为后续实现候选；`metadata-only` 表示当前只保留资源；`partial` 表示已有部分基础能力但语义未完整兑现；`implemented` 表示 runtime 已实现但可能仍待最终设备验收；`blocked` 表示需要 owner、SPI、设备或架构决策；`obsolete` 表示不计划恢复。

## 资源基线

| Catalog | 1.9.13 资源 | 当前 staged | 当前剩余关注点 |
| --- | ---: | ---: | --- |
| Events | 121 | 123 | 2 个 2.x additive now-playing 状态事件已加入；1.9.13 event 中仍有 13 个尚未完成验收。 |
| Static listeners/actions | 117 | 119 | 5 个 obsolete 旧项已移除，7 个 2.x additive name 曾加入；除 `libactivator.watch.haptic.tap` 因设备能力保持 metadata-only 外，当前静态 listener/action 的 handled 语义审计已收口。 |

当前 listener staged 移除项：`libactivator.settings.facebook`、`libactivator.settings.twitter`、`libactivator.twitter.compose-tweet`、`libactivator.facebook.compose-post`、`libactivator.weibo.compose-post`。

当前 2.x additive listener/action name：`libactivator.audio.mute-ringer`、`libactivator.audio.unmute-ringer`、`libactivator.audio.toggle-ringer-mute`、`libactivator.audio.toggle-output-mute`、`libactivator.keyboard.toggle-on-screen-keyboard`、`libactivator.system.hard-respring`、`libactivator.system.soft-reboot`。`libactivator.system.soft-reboot` 由 `jbroot(/usr/libexec/activator/user-reboot)` setuid/setgid helper 执行 `reboot3(RB2_USERREBOOT)`，SpringBoard listener 只通过 `posix_spawn` 提交执行。

## Metadata key 剩余欠账

大多数 resource metadata key 已由 resource/core/dispatch layer 或 Settings UI 未来边界覆盖。根目录只保留仍会影响后续实现决策的 key。

### Events keys

| Key | staged 覆盖 | 当前状态 | 剩余问题 |
| --- | ---: | --- | --- |
| `is-unprotected` | 12 | `partial` | Metadata/API 已暴露，但旧版 API protection prompt 与 unprotected 豁免体系尚未实现。 |
| `supports-unlocking-device` | 8 | `partial` | 当前只有 callback-only unlock-to-send compatibility，不实现 passcode submit 或完整主动解锁流程；仍需确认 1.9.13 是否是“默认允许、key=0 排除”的语义。 |
| `settings-view-controller-*` | 44 / 20 | `partial` | Existing-event core descriptor、property-list get/save IPC 与本进程 configuration controller factory 已实现；dynamic provider registry/generation/generic create 已在 SpringBoard 内部实现，但跨进程 provider catalog/create bridge、实际 Settings host 导航和 creation UI 仍待实现。 |

### Listeners keys

| Key | staged 覆盖 | 当前状态 | 剩余问题 |
| --- | ---: | --- | --- |
| `selector` | 118 | `implemented-by-name` | 已实现 listener family 会校验 selector metadata；`libactivator.watch.haptic.tap` 仍按 metadata-only 跟踪。 |
| `exclusive-assignment-groups` | 111 | `implemented-api` | core 查询已存在；阻止 UI 中选择冲突 action 属于后续 Settings UI。 |
| `previews` | 5 | `partial` | core preview dispatch API 已存在，但 built-in `system.vibrate` preview 和 watch haptic preview 尚未作为实际动作支持。 |
| `apply-rounded-corners` | 72 | `settings-ui-only` | 旧 UI 图标展示 hint，后续由 Settings UI 决定是否消费。 |

## Listeners/actions 剩余交叉比对

### 当前 staged 但未注册 runtime listener

这些 name 仍保留 metadata，或因兼容展示、历史资源完整性而保留在 staged resource 中；没有真实 runtime listener object 注册时，不应出现在 `availableListenerNames`。

| 分类 | Listener names | 当前状态 | 下一步 |
| --- | --- | --- | --- |
| Watch haptics | `libactivator.watch.haptic.tap` | `blocked` | 涉及 Watch 能力与设备差异；需要设备能力判断和目标 App 行为验证，不作为默认 listener 主线。 |

### 已从 staged 移除且不恢复

| 分类 | Listener names | 当前状态 | 说明 |
| --- | --- | --- | --- |
| obsolete URL 或旧服务 | `libactivator.settings.facebook`、`libactivator.settings.twitter`、`libactivator.facebook.compose-post`、`libactivator.twitter.compose-tweet`、`libactivator.weibo.compose-post` | `obsolete` | 旧 Settings URL 经真机验证失效、重复或打开错误页面；旧 social compose 服务不作为内置 action 恢复。 |

## Events 未完成交叉比对

1.9.13 event 资源共 121 个。当前尚未完成验收的 1.9.13 event name 共 13 个。

| Family | Event names | 当前状态 | 下一步 |
| --- | --- | --- | --- |
| Icon flick gestures | `libactivator.icon.flick.up`、`libactivator.icon.flick.down`、`libactivator.icon.flick.left`、`libactivator.icon.flick.right` | `blocked` | 确认并接入现代 `SBIconView` 的四向 flick 手势点位。 |
| Lock screen clock gestures | `libactivator.lockscreen.clock.double-tap`、`libactivator.lockscreen.clock.tap-hold`、`libactivator.lockscreen.clock.swipe-left`、`libactivator.lockscreen.clock.swipe-right`、`libactivator.lockscreen.clock.swipe-down` | `implemented` | iOS 15 RootHide 与 iOS 16 rootless 均已完成视图结构 probe 和五种手势交互校验；待 owner 完成 assignment 端到端验收。 |
| Car / watch / smart cover | `libactivator.car.connected`、`libactivator.car.disconnected`、`libactivator.watch.connected`、`libactivator.watch.disconnected`、`libactivator.clamshell.open`、`libactivator.clamshell.close` | `metadata-only` | 依赖外设、设备能力或私有服务；先保留资源，不用 metadata presence 推断可用性。 |

## 遗留问题

- Handled-default interception 尚未设计。当前 hardware button、status bar、edge gesture、force touch、multi-touch 都只负责识别和 dispatch，不根据 `event.handled` 吞掉系统默认行为。后续如果恢复拦截，应单独设计 hook 返回值、原始事件转发、fallback 重发和 `event.handled` 回传路径。
- 物理按键与 status bar scroll-to-top 是当前最明确可能需要拦截层的 family；edge gesture / force touch / multi-touch 当前继续保持 no-intercept 语义。
- `libactivator.system.local-back` 会在需要时持久打开 application accessibility；后续 Settings UI 需要显式提供用户可见的启停开关，底层复用 `LAActivator` 私有 application accessibility 接口或其公开化后的等价接口。
- Fingerprint sensor 遗留 1.9.13 changelog 项：“Suppress Touch ID events while showing an auth alert in Touch ID-enabled apps”。当前尚未识别现代 LocalAuthentication / biometric auth UI 状态，不做该 suppression。
- `LAEventNameSlideInFromTop` 只是 public alias 到 `LAEventNameStatusBarSwipeDown`；不要新增独立 `libactivator.slide-in.top` 资源或 runtime name。
- 高成本触摸 family 应使用 assignment-aware runtime gate；当前已接入 `EdgeGesture`、`ForceTouch`、`StatusBar`、`MultiTouch`。这些 source 继续保持 no-intercept 语义，不根据 `event.handled` 吞掉系统默认行为。
