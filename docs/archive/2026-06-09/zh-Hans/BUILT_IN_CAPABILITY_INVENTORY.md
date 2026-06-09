# 内置功能清单

本文档将旧版 `master` 的内置功能作为事实记录下来 清单。这并非实施计划，也不代表任何内置功能。 重写中实现的事件、监听器或操作。

## 证据摘要

- 事件元数据资源：位于下的 61 个 `Info.plist` 资源包 `references/master/layout/Library/Activator/Events`。
- 静态监听器/操作元数据资源：位于下的 59 个 `Info.plist` 资源包 `references/master/layout/Library/Activator/Listeners`。
- 分阶段的监听器/操作元数据资源：58 个 `Info.plist` 资源包。该 旧版 `libactivator.twitter.compose-tweet` 资源是故意 被排除在外，因为该现代项目不会实现该Twitter特有的 操作。
- 静态监听器/操作注册：59 次 `registerListener:` 调用 `references/master/LASimpleListener.x`。
- 事件元数据注册：`references/master/LADefaultEventDataSource.m` 扫描 `/Library/Activator/Events` 并注册每个软件包名称。
- 动态监听器注册：
- 应用程序：`references/master/LAApplicationListener.x`。
- 菜单：`references/master/LAMenuListener.m`。
- SBSettings 开关：`references/master/LAToggleListener.m`。

现代地位价值观：

- `resource-only`：无需实现运行时行为即可分阶段部署元数据。
- `可实现的`：该行为在无需所有者提供SPI的情况下似乎可行 该决定已作出，但仍需落实和验证。
- `needs-owner-reference`：现代 SPI 或行为尚不明确；请咨询项目负责人 在实施前需征得所有者同意。
- `已废弃`：该旧版功能没有直接对应的现代等效功能，或者依赖于 已移除框架。
- `defer-to-settings-ui`：该项属于“设置”界面，而非运行时。

当一行中列出了多个旧名称时，该行中的每个字段均适用于每个 列出的名称。

## 内置事件源

以下每个事件的资源路径均为 `references/master/layout/Library/Activator/Events/<旧名称>/Info.plist`。 该资源本身属于 `resource-only` 类型；其获取状态由 运行时依赖项列。

| 旧名称 | 组 | 模式 / 标志 | 旧版源代码 | 运行时依赖项或 SPI 家族 | 当前状况 | 首次验证 |
| --- | --- | --- | --- | --- | --- | --- |
| `libactivator.headset-button.hold.short`、`libactivator.headset-button.press.single`、`libactivator.headset.connected`、`libactivator.headset.disconnected` | 耳机 | 所有模式 | `Events.x`、`LADefaultEventDataSource.m` | 通过 SpringBoard / `AVSystemController` 时代的 SPI 实现耳机按钮挂钩和音频路由通知。 | `需要所有者引用` | 由车主协助进行SPI检测，随后使用roothide手动检查清单。 |
| `libactivator.menu.press.single`、`libactivator.menu.press.double`、`libactivator.menu.press.triple`、`libactivator.menu.hold.short`、`libactivator.menu.hold.long` | 主页按钮 | 所有模式 | `Events.x`、`LADefaultEventDataSource.m` | SpringBoard 菜单/主屏幕按钮的钩子及状态切换时机。 | `需要所有者引用` | 由车主协助进行SPI检测，随后使用roothide手动检查清单。 |
| `libactivator.lock.press.double`, `libactivator.lock.hold.short` | 睡眠按钮 | 所有模式 | `Events.x`、`LADefaultEventDataSource.m` | SpringBoard 锁定按钮钩子、锁定计时器、状态栏锁定状态的副作用。 | `需要所有者引用` | 由车主协助进行SPI检测，随后使用roothide手动检查清单。 |
| `libactivator.volume.up.press`, `libactivator.volume.down.press`, `libactivator.volume.up.hold.short`, `libactivator.volume.down.hold.short`, `libactivator.volume.up-down`, `libactivator.volume.down-up`、`libactivator.volume.both.press`、`libactivator.volume.toggle-mute-twice`、`libactivator.volume.display-tap` | 音量按钮 | 所有模式 | `Events.x`、`LADefaultEventDataSource.m` | SpringBoard 音量/铃声挂钩、`VolumeControl`、提醒/铃声静音，以及音量 HUD 的触摸处理。 | `需要所有者引用` | 由车主协助进行SPI检测，随后使用roothide手动检查清单。 |
| `libactivator.motion.shake` | 动议 | 所有模式 | `Events.x`、`LADefaultEventDataSource.m` | SpringBoard 动作处理钩子。 | `需要所有者引用` | 由所有者协助的SPI探针。 |
| `libactivator.power.connected`, `libactivator.power.disconnected` | 电源 | 所有模式 | `Events.x`、`LADefaultEventDataSource.m` | SpringBoard 交流电源状态回调。 | 在现代通知/源探针之后`implementable` | Roothide 手动检查清单。 |
| `libactivator.statusbar.tap.single`, `libactivator.statusbar.tap.double`, `libactivator.statusbar.hold`, `libactivator.statusbar.swipe.left`, `libactivator.statusbar.swipe.right`、`libactivator.statusbar.swipe.down`、`libactivator.statusbar.tap.single.left`、`libactivator.statusbar.tap.single.right`、`libactivator.statusbar.tap.double.left`、`libactivator.statusbar.tap.double.right`、`libactivator.statusbar.hold.left`、`libactivator.statusbar.hold.right` | 状态栏 | 所有模式 | `Events.x`、`LADefaultEventDataSource.m` | 关于 SpringBoard 状态栏触摸操作的观察。项目负责人指出，现代应用内的状态栏触摸操作无需注入用户应用，但具体的实现仍需留待后续功能任务完成。 | `需要所有者引用` | 由车主协助进行SPI检测，随后使用roothide手动检查清单。 |
| `libactivator.slide-in.bottom-left`, `libactivator.slide-in.bottom`, `libactivator.slide-in.bottom-right`, `libactivator.slide-in.top-left`, `libactivator.slide-in.top-right`, `libactivator.slide-in.左上角`、`libactivator.slide-in.left`、`libactivator.slide-in.左下角`、`libactivator.slide-in.右上角`、`libactivator.slide-in.右侧`、`libactivator.slide-in.右下角` | 滑入手势 | 所有模式；左/右、上/下变体均隐藏在资源中 | `SlideEvents.x`、`LADefaultEventDataSource.m` | 边缘手势窗口和SpringBoard触控处理。 | `需要所有者引用` | Roothide 手动检查清单（含交互场景）。 |
| `libactivator.two-finger-slide-in.bottom-left`, `libactivator.two-finger-slide-in.bottom`, `libactivator.two-finger-slide-in.bottom-right`, `libactivator.two-finger-slide-in.top-left`, `libactivator.two-finger-slide-in.top`、`libactivator.two-finger-slide-in.top-right`、`libactivator.two-finger-slide-in.left-top`、`libactivator.two-finger-slide-in.left`、`libactivator.two-finger-slide-in.left-bottom`、`libactivator.two-finger-slide-in.right-top`、`libactivator.two-finger-slide-in.right`、`libactivator.two-finger-slide-in.right-bottom` | 双指滑入手势 | 所有模式；左/右、上/下变体均隐藏在资源中 | `SlideEvents.x`、`LADefaultEventDataSource.m` | 边缘手势窗口和双指触控追踪。 | `需要所有者引用` | Roothide 手动检查清单（含交互场景）。 |
| `libactivator.springboard.pinch`, `libactivator.springboard.spread` | SpringBoard | 仅限`springboard` | `Events.x`、`LADefaultEventDataSource.m` | SpringBoard 图标滚动视图 / 图标触摸手势钩子。 | `需要所有者引用` | 主屏幕上的 Roothide 手动检查清单。 |
| `libactivator.lockscreen.clock.double-tap` | 锁屏 | 仅限`lockscreen` | `Events.x`、`LADefaultEventDataSource.m` | 锁屏时钟视图的触控钩。 | `需要所有者引用` | 锁屏界面上的 Roothide 手动检查清单。 |

## 内置监听器和操作

以下每个静态监听器/操作的资源路径均为 `references/master/layout/Library/Activator/Listeners/<旧名称>/Info.plist`。 该资源中的传统选择器或 URL 会被读取，并由 `LASimpleListener.x`.

| 旧名称 | 组 | 选择器 / 行为来源 | 模式 / 特殊元数据 | 运行时依赖项或 SPI 家族 | 当前状况 | 首次验证 |
| --- | --- | --- | --- | --- | --- | --- |
| `libactivator.system.nothing` | 系统操作 | `doNothing` | 所有模式；与锁定/菜单按键事件不兼容 | 无 | `已实现` | SpringBoard 测试 IPC 分发测试。 |
| `libactivator.system.homebutton`, `libactivator.system.sleepbutton` | 系统操作 | `homeButton`、`sleepButton` | 所有模式；“主页”模式要求无触控操作；两者均存在不兼容的硬件按键事件 | HID 事件生成或 SpringBoard 按钮模拟。 | `需要所有者引用` | 由车主协助进行SPI检测，随后使用roothide手动检查清单。 |
| `libactivator.system.respring`、`libactivator.system.reboot`、`libactivator.system.powerdown` | 系统操作 | `respring`、`reboot`、`powerDown` | 所有模式 | SpringBoard 生命周期 / 电源 SPI。 | `需要所有者引用` | Roothide 手动检查清单。 |
| `libactivator.system.safemode` | 系统操作 | `safeMode` 资源选择器，但在 `LASimpleListener.x` 中，旧版方法的主体已被注释掉。 | 所有模式 | 加载器/安全模式的行为决策。 | `需要所有者引用` | 实施前需经业主决定。 |
| `libactivator.system.spotlight`, `libactivator.system.first-springboard-page`, `libactivator.system.activate-switcher`, `libactivator.system.show-now-playing-bar`, `libactivator.audio.show-volume-bar`, `libactivator.system.activate-notification-center` | 系统操作 / 音频 | `spotlight`、`firstSpringBoardPage`、`activateSwitcher`、`showNowPlayingBar`、`showVolumeBar`、`activateNotificationCenter` | 对大多数应用而言，需使用“启动器”；“聚光灯”和“首页”无需手动操作；“通知中心”和“应用切换器”的事件列表不兼容 | SpringBoard 界面控制器、切换器、搜索功能、公告/列表界面、音量条界面。 | `需要所有者引用` | 由车主协助进行SPI检测，随后使用roothide手动检查清单。 |
| `libactivator.system.take-screenshot` | 系统操作 | `takeScreenshot` | 所有模式 | SpringBoard 截图服务。 | `需要所有者引用` | Roothide 手动检查清单。 |
| `libactivator.system.voice-control`、`libactivator.system.virtual-assistant`、`libactivator.settings.virtual-assistant` | 系统操作 / 设置 | `voiceControl`、`activateVirtualAssistant`、设置 URL 操作 | 系统操作的所有模式；设置 URL 的 Springboard/应用程序 | 语音控制/语音助手 SPI 及设置 URL 的处理。 | `需要所有者引用` | 由所有者协助的SPI探针。 |
| `libactivator.twitter.compose-tweet` | 系统操作 | `composeTweet` | 跳板/应用程序 | 旧版 `TWTweetComposeViewController` 流程。 | `已废弃`；未部署 | 未实现；当前产品目录中暂无替代方案。 |
| `libactivator.lockscreen.dismiss`、`libactivator.lockscreen.show`、`libactivator.lockscreen.toggle` | 锁屏 | `dismissLockScreen`、`showLockScreen`、`toggleLockScreen` | “关闭”仅限锁屏界面；“显示”指主屏幕/应用程序；“切换”适用于所有模式 | SpringBoard 锁定服务 / CoverSheet SPI。 | `需要所有者引用` | Roothide 手动检查清单。 |
| `libactivator.ipod.toggle-playback`、`libactivator.ipod.pause-playback`、`libactivator.ipod.resume-playback`、`libactivator.ipod.previous-track`、`libactivator.ipod.下一首曲目`、``libactivator.ipod.音乐控制` | 音频 | `togglePlayback`、`pauseMedia`、`playMedia`、`previousTrack`、`nextTrack`、`musicControls` | 所有模式 | 媒体播放控制器 / 当前播放界面 SPI。 | `需要所有者引用` | 由所有者协助的SPI探针。 |
| `libactivator.phone.favorites`、`libactivator.phone.contacts`、`libactivator.phone.keypad`、`libactivator.phone.recents`、`libactivator.phone.voicemail` | 电话 | `LASimpleListener.x` 中的手机 URL 操作 | 跳板/应用程序 | SpringBoard URL 的打开功能以及现代手机 URL 的可用性。 | URL 验证后为 `implementable` | Roothide 手动检查清单。 |
| `libactivator.settings.about`, `libactivator.settings.accessibility`, `libactivator.settings.auto-lock`, `libactivator.settings.bluetooth`, `libactivator.settings.brightness`, `libactivator.settings.date-time`, `libactivator.settings.equalizer`、`libactivator.settings.facetime`、`libactivator.settings.general`、`libactivator.settings.icloud`、`libactivator.settings.international`、`libactivator.settings.keyboard`、`libactivator.settings.location-services`、`libactivator.settings.music`、`libactivator.settings.network`、`libactivator.settings.notes`、`libactivator.settings.通知`、`libactivator.settings.电话`、`libactivator.settings.照片`、`libactivator.settings.safari`、`libactivator.settings.sounds`、`libactivator.settings.store`、`libactivator.settings.twitter`、`libactivator.settings.usage`、`libactivator.settings.vpn`、`libactivator.settings.wallpaper`、`libactivator.settings.wifi` | 设置 | `openURLWithActivator:event:listenerName:` 以及资源 `url` 键 | 跳板/应用程序 | SpringBoard 链接的打开以及现代版“设置”链接的可用性。 | URL 验证后为 `implementable` | Roothide 手动检查清单。 |

## 动态监听器家族

| 旧版命名规则 | 类别 / 组 | 旧版源代码 | 资源路径 | 运行时依赖项或 SPI 家族 | 当前状况 | 首次验证 |
| --- | --- | --- | --- | --- | --- | --- |
| 应用程序包显示标识符，不包括被忽略的旧版系统标识符 | 系统应用程序、用户应用程序、网页剪辑 | `LAApplicationListener.x` | 没有固定资源；元数据来自 SpringBoard 应用对象 | SpringBoard 应用程序模型、应用程序激活、应用程序图标、锁屏相机特例。 | `需要所有者引用` | Roothide 手动检查清单，包含应用启动/暂停场景。 |
| 来自 `LAMenuSettings` 偏好设置的菜单键 | 菜单 | `LAMenuListener.m` | 无固定资源；菜单标题/项目来自“偏好设置” | 设置界面生成的菜单数据及SpringBoard操作表的呈现方式。 | `defer-to-settings-ui` | 退出菜单编辑器后的设置界面场景测试。 |
| `activatortoggles.<toggle name>` 用于 `/Library/SBSettings/Toggles` 目录下的 SBSettings 开关包 | SBSettings 开关 | `LAToggleListener.m` | 外部 SBSettings 开关包和主题图标 | 通过 `dlopen` 加载的旧版 SBSettings 插件 ABI。 | `已弃用`，除非明确选择了现代兼容性目标 | 由业主决定；不提供样品包。 |

## 资源元数据语义

- 在旧版资源中观察到的事件元数据键：`title`、`description`、 `group`、`compatible-modes` 和 `hidden`。
- 在旧版资源中观察到的监听器元数据键：`title`、`description`、 `group`、`selector`、`url`、`compatible-modes`、`incompatible-events` 以及 `requires-no-touch-events`。
- 旧版事件元数据由 `LADefaultEventDataSource` 从 `/Library/Activator/Events/<event name>/Info.plist`（可选）之后 `CoreFoundationVersion` 检查点。
- 旧版听众元数据是从 `/Library/Activator/Listeners/<监听器名称>/Info.plist` 或从 `Listeners/bundled.plist`。
- 旧版本地化工作由旧版本地化 Makefile 分阶段处理，具体如下： `/Library/Activator`，而 `symlink_localizations.sh` 创建了指向这些 `.lproj` 的符号链接 目录导入到 `Activator.app` 中。随后，运行时本地化使用了 首先是激活器支持包，接着是事件/监听器包。
- 现代资源目录会将 `en.lproj/Localizable.strings` 暂存到 位于 `/Library/Activator` 下的 `zh-Hans.lproj/Localizable.strings`。键为 基于分阶段元数据，使用现有的 `EVENT_*`、`LISTENER_*` 和 `MODE_*` 查找方案。
- 已提交的旧版 `layout/Library/Activator` 资源包含元数据 仅限 plist 文件；应用图标和启动图像位于 `Applications/Activator.app` 目录下。
- 现代实现应通过现有系统分阶段部署元数据 遵循 rootful/rootless/roothide 布局规则，并在运行时使用 `jbroot(...)`。

## 设置界面边界

位于 `references/master/*SettingsController*` 中的旧版设置控制器， `Preferences.m`、`Activator.m` 和 `LASettingsViewControllers.m` 不属于 此内置运行时库存的。它们仍位于“设置”界面中，并且 应通过 `libactivatorsettings.dylib` 实现。
