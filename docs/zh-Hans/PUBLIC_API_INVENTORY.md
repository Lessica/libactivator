# 公共 API 目录

此清单记录了从 Activator 1.9 继承的公共 API 接口，以及 重写基金会引入的兼容性导入路径。它并非 一份实施方案；这是针对下一次公测的兼容性检查清单 API 框架开发。

## 基线

- 权威的旧版 API 来源：`references/headers`。
- 当前的公共头文件源：`include/Activator` 和 `include/ActivatorSettings`。
- 当前的兼容性入口点：
- `#import <libactivator.h>`
- `#import <Activator/Activator.h>`
- `@import Activator`
- 来自 `references/headers` 的当前标头差异：
- `include/Activator/Activator.h` 是一个新的框架总头文件。
- `layout/usr/include/libactivator.h` 是平铺兼容性的总括文件，并且 导入 `<Activator/Activator.h>`。
- 复制的 1.9 头文件在 API 上基本等同，只是删除了 末尾的空行。

## 实施状态图例

- `必须实现`：源代码或二进制兼容性所必需。
- `优先使用安全存根`：初始时可能返回保守的空值或默认值， 但必须具备稳定的符号和不会崩溃的行为。
- `Runtime-backed`：需要 IPC、SpringBoard 状态、私有适配器，或 在变得有意义之前，仅限于设备层面的行为。
- `Settings-backed`：属于设置 UI 库，并负责加载主机。
- `基于功能限制`：必须在注册前于现代 iOS 系统上进行评估，否则 该行为已启用。
- `需决策`：在修改公共内容前，需经项目负责人批准 表面行为或旧有行为。

## 标题

| 页眉 | 公共区域 | 初始状态 | 注释 |
| --- | --- | --- | --- |
| `Activator/Activator.h` | Activator 模块的框架架构。 | 必须实现 | 导入所有 1.9 Activator 的公共头文件。 |
| Activator.h 库 | 平顶复古伞。 | 必须实现 | 安装在 `/usr/include/libactivator.h`；导入 `<Activator/Activator.h>`。 |
| `LAActivatorVersion.h` | `LAActivatorVersion` 枚举和 `LA_PRIVATE_IVARS`。 | 必须实现 | 版本值是兼容性常量。请添加 `LAActivatorVersion_2_0 = 2000000`，并在 2.0 版本重写时报告此信息。 |
| `LAActivator.h` | 主界面、任务、元数据、模式、黑名单、配置文件、本地化、常量、通知。 | 必须实现 | API 框架应在 IPC 或 SpringBoard 运行时之前就位。 |
| `LAEvent.h` | `LAEvent` 模型及内置的 event/userInfo 常量。 | 必须实现 | 事件常量是兼容性符号；实际的事件获取取决于功能支持情况。 |
| `LAListener.h` | `LAListener` 协议，用于事件回调、元数据、图标、移除和配置。 | 必须实现 | 分发行为由运行时支持；元数据查询可以先作为安全的占位实现。 |
| `LAEventDataSource.h` | 用于事件元数据、移除和配置的 `LAEventDataSource` 协议。 | 必须实现 | 注册和元数据路由可以先采用安全存根。 |
| `LASettingsViewController.h` | 设置控制器类族和配置控制器。 | 基于设置的 | Header 仍是 Activator 公共 API 的一部分。`libactivator` 必须保留类兼容性适配层；真正的 UI 实现位于 `libactivatorsettings.dylib` 中。 |
| `UIImageView+Activator.h` | 监听器图像类别的属性。 | 基于设置的 | 通常与相关对象一起实现；加载行为可以延迟。 |

## LAActivator 界面

### 辛格尔顿与州

| 符号 | 状态 | 注释 |
| --- | --- | --- |
| `+sharedInstance` | 必须实现 | 必须返回与 `LASharedActivator` 相同的对象。 |
| `LASharedActivator` | 必须实现 | 全局兼容性变量。 |
| `版本` | 必须实现 | 应为 2.0 版本的重写报告 `LAActivatorVersion_2_0`。 |
| `runningInsideSpringBoard` | 由运行时支持 | 可在本地检测到；该行为会限制仅限 SpringBoard 的方法。 |
| `dangerousToSendEvents` | 已弃用的兼容性 | 已废弃的 Cydia/安装保护机制；在 2.x 版本中始终返回 `NO`。 |

### 监听器查找与分发

| 符号 | 状态 | 注释 |
| --- | --- | --- |
| `listenerForEvent:` | 由运行时支持 | 赋值解析以及监听器注册表查询。 |
| `sendEventToListener:` | 由运行时支持 | 发送给指定的收听者。 |
| `sendEvent:toListenerWithName:` | 由运行时支持 | 直接分派监听器。 |
| `sendEvent:toListenersWithNames:` | 由运行时支持 | 多监听器分发。 |
| `sendAbortToListener:` | 由运行时支持 | 赋值解析及中断分发。 |
| `sendAbortEvent:toListenerWithName:` | 由运行时支持 | 直接中止调度。 |
| `sendAbortEvent:toListenersWithNames:` | 由运行时支持 | 多监听器中止分发。 |
| `sendPreviewEventToListenerWithName:` | 由运行时支持 | 设置预览行为；可能在本地或通过IPC进行分发。 |
| `sendDeactivateEventToListeners:` | 由运行时支持 | 需要现代化的菜单/停用语义功能。 |
| `listenerForName:` | 必须实现 | 注册表查询；安全存根可能返回 `nil`。 |
| `hasListenerWithName:` | 必须实现 | 注册表查询；安全存根可能返回 `NO`。 |
| `registerListener:forName:` | 由运行时支持 | SpringBoard 权威注册；旧版非 SpringBoard 实现会拒绝此调用。 |
| `unregisterListenerWithName:` | 由运行时支持 | SpringBoard 授权的注销操作；旧版非 SpringBoard 实现会拒绝此调用。 |
| `hasSeenListenerWithName:` | 必须实现 | 保存了 SpringBoard 的监听器注册历史记录。 |

### 作业

| 符号 | 状态 | 注释 |
| --- | --- | --- |
| `assignEvent:toListenerWithName:` | 必须实现 | 核心模型/存储 API。 |
| `assignEvent:toListenersWithNames:` | 必须实现 | 多监听器赋值的兼容性。 |
| `addListenerAssignment:toEvent:` | 必须实现 | 增量指派更新。 |
| `removeListenerAssignment:fromEvent:` | 必须实现 | 逐步移除赋值。 |
| `unassignEvent:` | 必须实现 | 清除该事件的所有监听器。 |
| `assignedListenerNameForEvent:` | 必须实现 | 旧版单听众兼容视图。 |
| `assignedListenerNamesForEvent:` | 必须实现 | 典型的多监听器查询。 |
| `eventsAssignedToListenerWithName:` | 必须实现 | 反向查询。 |

### 事件注册表与元数据

| 符号 | 状态 | 注释 |
| --- | --- | --- |
| `availableEventNames` | 必须实现 | 在内置函数生效之前，允许使用空数组。 |
| 有一个同名的活动 | 必须实现 | 注册表查询。 |
| 名称为“隐藏”的事件： | 先写安全存根 | 基于数据源的元数据。 |
| `eventWithNameRequiresAssignment:` | 先写安全存根 | 基于数据源的元数据。 |
| `compatibleModesForEventWithName:` | 先写安全存根 | 可能来自数据源；默认值应取保守值。 |
| `eventWithName:isCompatibleWithMode:` | 先写安全存根 | 兼容性查询。 |
| `eventWithNameSupportsUnlockingDeviceToSend:` | 由运行时支持 | 锁屏功能。 |
| `eventWithNameSupportsRemoval:` | 先写安全存根 | 基于数据源的元数据。 |
| `removeEventWithName:` | 由运行时支持 | 调用数据源或内置删除路径。 |
| `registerEventDataSource:forEventName:` | 必须实现 | SpringBoard——权威事件注册表；旧版非SpringBoard实现拒绝了此调用。 |
| `unregisterEventDataSourceWithEventName:` | 必须实现 | SpringBoard——权威事件注册表；旧版非SpringBoard实现拒绝了此调用。 |
| `eventWithNameSupportsConfiguration:` | 基于设置的 | 这取决于配置控制器元数据。 |
| `configurationViewControllerForEventWithName:` | 基于设置的 | 必须通过设置兼容性适配层进行解析，并加载及与 `libactivatorsettings.dylib` 进行协调。 |

### 收听者元数据

| 符号 | 状态 | 注释 |
| --- | --- | --- |
| `availableListenerNames` | 必须实现 | 在内置函数生效之前，允许使用空数组。 |
| `infoDictionaryValueOfKey:forListenerWithName:` | 先写安全存根 | 收听者元数据查询。 |
| `listenerWithNameRequiresAssignment:` | 先写安全存根 | 收听者元数据查询。 |
| `compatibleEventModesForListenerWithName:` | 先写安全存根 | 收听者元数据查询。 |
| `listenerWithName:isCompatibleWithMode:` | 先写安全存根 | 收听者元数据查询。 |
| `listenerWithName:isCompatibleWithEventName:` | 先写安全存根 | 需要对事件和监听器进行兼容性检查。 |
| `listenerWithNameNeedsPoweredDisplay:` | 先写安全存根 | 收听者元数据查询。 |
| `exclusiveAssignmentGroupsForListenerName:` | 先写安全存根 | 这是为了确保与多监听器赋值兼容。 |
| `listenerNamesAreMutuallyCompatible:` | 必须实现 | 核心任务兼容性逻辑。 |
| `iconForListenerName:` | 基于设置的 | 可能会向听众元数据提供商查询。 |
| `smallIconForListenerName:` | 基于设置的 | 可能会向听众元数据提供商进行查询。 |
| `imageForListenerName:usingTemplate:` | 基于设置的 | 基于模板的旧版映像行为。 |
| `listenerWithNameSupportsRemoval:` | 先写安全存根 | 收听者元数据查询。 |
| `requestRemovalForListenerWithName:` | 由运行时支持 | 调用监听器移除钩子。 |
| `listenerWithNameSupportsConfiguration:` | 基于设置的 | 关于监听器配置的支持咨询。 |
| `configurationViewControllerForListenerWithName:` | 基于设置的 | 必须通过设置兼容性适配层进行解析，并加载及与 `libactivatorsettings.dylib` 进行协调。 |

### 模式、黑名单、配置文件、本地化

| 符号 | 状态 | 注释 |
| --- | --- | --- |
| `availableEventModes` | 必须实现 | 即使在运行时尚未完成之前，也应包含兼容模式。 |
| `currentEventMode` | 由运行时支持 | 这取决于前台应用、SpringBoard 以及锁屏状态。 |
| `currentEventModeUnderneathLockScreen` | 由运行时支持 | 需要锁屏状态适配器。 |
| `支持解锁设备以发送事件` | 由运行时支持 | 锁屏功能。 |
| `displayIdentifierForCurrentApplication` | 由运行时支持 | 需要现代的前台应用程序查找功能。 |
| `applicationWithDisplayIdentifierIsBlacklisted:` | 必须实现 | 核心黑名单存储/查询。 |
| `setApplicationWithDisplayIdentifier:isBlacklisted:` | 必须实现 | 核心黑名单的存储/更新。 |
| `availableProfileNames` | 必须实现 | 必须定义空/默认配置文件的行为。 |
| `currentProfileName` | 必须实现 | 剖析时序功能已推迟至核心兼容性稳定后再实施。 |
| `localizedStringForKey:value:` | 必须实现 | 支持激活器捆绑，并提供值/键回退机制。 |
| `localizedTitleForEventMode:` | 必须实现 | 使用传统模式的本地化键和备用字符串。 |
| `localizedTitleForEventName:` | 必须实现 | 基于数据源和事件资源，通过IPC在SpringBoard外部进行路由。 |
| `localizedTitleForListenerName:` | 必须实现 | 基于监听器对象和资源，并在 SpringBoard 外部通过 IPC 进行路由。 |
| `localizedTitleForListenerNames:` | 先写安全存根 | 应确定性地将本地化的监听器名称进行拼接。 |
| `localizedGroupForEventName:` | 必须实现 | 基于数据源和事件资源，通过IPC在SpringBoard外部进行路由。 |
| `localizedGroupForListenerName:` | 必须实现 | 基于监听器对象和资源，并在 SpringBoard 外部通过进程间通信（IPC）进行路由。 |
| `localizedDescriptionForEventMode:` | 必须实现 | 使用传统模式的本地化键和备用字符串。 |
| `localizedDescriptionForEventName:` | 必须实现 | 基于数据源和事件资源，通过IPC在SpringBoard外部进行路由。 |
| `localizedDescriptionForListenerName:` | 必须实现 | 基于监听器对象和资源，并在 SpringBoard 外部通过 IPC 进行路由。 |

## LAEvent 模型

| 符号 | 状态 | 注释 |
| --- | --- | --- |
| 名称为： | 必须实现 | 恢复默认/当前模式。 |
| 名称和模式的事件 | 必须实现 | 默认模式的工厂。 |
| `-initWithName:` | 必须实现 | 指定初始化器或便捷初始化器。 |
| `-initWithName:mode:` | 必须实现 | 必须存储不可变的名称/模式。 |
| `name` | 必须实现 | 只读。 |
| `模式` | 必须实现 | 只读。 |
| `已处理` | 必须实现 | 可变的分派标志。 |
| `userInfo` | 必须实现 | 复制语义。 |
| 非原子属性的编码 | 必须实现 | 向后兼容性。可单独考虑附加的 `NSSecureCoding`。 |

## 协议

### LAListener

监听器协议仅包含可选方法。实现必须检查 在调用任何监听器回调之前，先调用 `respondsToSelector:`。

| 组 | 方法 | 状态 |
| --- | --- | --- |
| 模式切换 | `didChangeToEventMode:` | 由运行时支持 |
| 活动发布 | `receiveEvent:forListenerName:`、`abortEvent:forListenerName:`、`receiveUnlockingDeviceEvent:forListenerName:`、`receiveDeactivateEvent:`、`otherListenerDidHandleEvent:`、`receivePreviewEventForListenerName:` | 由运行时支持 |
| 简易事件发布 | `receiveEvent:`、`abortEvent:` | 由运行时支持 |
| 文本元数据 | 本地化标题、描述、组 | 必须实现 |
| 兼容性元数据 | 需要赋值、兼容模式、兼容事件、专属组、信息字典、带背光显示屏 | 必须实现 |
| 图标元数据 | 图标 PNG 数据、小型图标 PNG 数据、图标图像、小型图标图像、字形描述符 | 已部分实施 |
| 卸载与配置 | 支持移除、移除请求、配置控制器类、配置加载/保存 | 由运行时支持和由设置支持 |

### LAEventDataSource

| 组 | 方法 | 状态 |
| --- | --- | --- |
| 必需的元数据 | 本地化标题、组、描述 | 必须实现对数据源的分发 |
| 可见性与分配 | 隐藏、需分配、兼容模式、支持解锁后发送 | 先写安全存根 |
| 移除 | 支持移除，移除事件 | 由运行时支持 |
| 配置 | 配置控制器类，配置加载/保存 | 基于设置的 |

## 设置 公共区域

| 符号 | 状态 | 注释 |
| --- | --- | --- |
| `LASettingsViewController` | 基于设置的 | 基础设置控制器。类标识必须来自 `libactivator`；实际行为位于 `libactivatorsettings.dylib` 中。 |
| `LARootSettingsController` | 基于设置的 | 根设置界面。类标识必须来自 `libactivator`；实际行为位于 `libactivatorsettings.dylib` 中。 |
| `LAModeSettingsController` | 基于设置的 | 模式特定设置界面。类标识必须来自 `libactivator`；实际行为位于 `libactivatorsettings.dylib` 中。 |
| `LAEventSettingsController` | 基于设置的 | 事件分配界面。类标识必须来自 `libactivator`；实际行为位于 `libactivatorsettings.dylib` 中。 |
| `LAListenerSettingsViewController` | 基于设置的 | 监听器详细信息界面。类标识必须来自 `libactivator`；实际行为位于 `libactivatorsettings.dylib` 中。 |
| `LAEventConfigurationViewController` | 基于设置的 | 事件配置基类。该类的标识必须可在 `libactivator` 中获取；实际行为位于 `libactivatorsettings.dylib` 中。 |
| `LAListenerConfigurationViewController` | 基于设置的 | 监听器配置基类。该类的标识必须可在 `libactivator` 中获取；其实际行为位于 `libactivatorsettings.dylib` 中。 |
| `LA_SETTINGS_CONTROLLER(超类)` | 需要做出决定 | 该宏用于支持旧式的 PreferenceLoader 风格的超类替换。保持头文件兼容性；实现时应避免依赖于旧版主程序的假设。 |
| `UIImageView (Activator)` | 基于设置的 | 分类存储可以尽早实现；图像加载功能可以稍后再处理。 |

## 常量

### 常量版本

`LAActivatorVersion` 保留了 1.3 至 1.9.0 版本的旧版本值。 添加 `LAActivatorVersion_2_0 = 2000000`，并将 `-[LAActivator version]` 将其提交至 2.0 重写版本，同时保留旧版枚举值作为 ABI/源代码 常量。

### 事件模式常量

- `LAEventModeSpringBoard`
- `LAEventModeApplication`
- `LAEventModeLockScreen`

这些常量是核心兼容性符号。模式检测是 由运行时支持，但这些字符串必须立即存在于公共动态库中。

### 通知

- `LAActivatorAvailableListenersChangedNotification`
- `LAActivatorAvailableEventsChangedNotification`
- `LAActivatorAssignmentsChangedNotification`

通知是公共的进程本地名称。跨进程状态传播 属于 IPC，那么每个进程都可以重新发布本地通知。

### 内置事件名称常量

即使对应的现代版本已不再使用，公共 API 仍会暴露旧版事件名称 iOS 的获取功能尚未实现。常量必须存在；注册和 实际交付取决于能力限制。

| 事件家族 | 常量 |
| --- | --- |
| 菜单按钮 | `LAEventNameMenuPressSingle`、`LAEventNameMenuPressDouble`、`LAEventNameMenuPressTriple`、`LAEventNameMenuHoldShort`、`LAEventNameMenuHoldLong` |
| 锁定按钮 | `LAEventNameLockHoldShort`、`LAEventNameLockHoldLong`、`LAEventNameLockPressDouble`、`LAEventNameLockPressWithMenu` |
| SpringBoard 手势 | `LAEventNameSpringBoardPinch`, `LAEventNameSpringBoardSpread` |
| 状态栏 | `LAEventNameStatusBarSwipeRight`, `LAEventNameStatusBarSwipeLeft`, `LAEventNameStatusBarTapDouble`, `LAEventNameStatusBarTapDoubleLeft`, `LAEventNameStatusBarTapDoubleRight`, `LAEventNameStatusBarTapSingle`, `LAEventNameStatusBarTapSingleLeft`、`LAEventNameStatusBarTapSingleRight`、`LAEventNameStatusBarHold`、`LAEventNameStatusBarHoldLeft`、`LAEventNameStatusBarHoldRight` |
| 卷 | `LAEventNameVolumeDownUp`, `LAEventNameVolumeUpDown`, `LAEventNameVolumeDisplayTap`, `LAEventNameVolumeToggleMuteTwice`, `LAEventNameVolumeDownHoldShort`, `LAEventNameVolumeUpHoldShort`, `LAEventNameVolumeDownPress`, `LAEventNameVolumeUpPress`, `LAEventNameVolumeBothPress` |
| 边缘滑动 | `LAEventNameSlideInFromBottom`, `LAEventNameSlideInFromBottomLeft`, `LAEventNameSlideInFromBottomRight`, `LAEventNameSlideInFromLeft`, `LAEventNameSlideInFromRight`, `LAEventNameStatusBarSwipeDown`、`LAEventNameSlideInFromTop`、`LAEventNameSlideInFromTopLeft`、`LAEventNameSlideInFromTopRight` |
| 双指边缘滑动 | `LAEventNameTwoFingerSlideInFromBottom`, `LAEventNameTwoFingerSlideInFromBottomLeft`, `LAEventNameTwoFingerSlideInFromBottomRight`, `LAEventNameTwoFingerSlideInFromLeft`, `LAEventNameTwoFingerSlideInFromRight`, `LAEventNameTwoFingerSlideInFromTop`、`LAEventNameTwoFingerSlideInFromTopLeft`、`LAEventNameTwoFingerSlideInFromTopRight` |
| 拖出屏幕 | `LAEventNameDragOffBottom`、`LAEventNameDragOffLeft`、`LAEventNameDragOffRight`、`LAEventNameDragOffTop` |
| 屏幕边缘滑动 | `LAEventScreenBottomSwipeLeft`、`LAEventScreenBottomSwipeRight`、`LAEventScreenLeftSwipeDown`、`LAEventScreenLeftSwipeUp`、`LAEventScreenRightSwipeDown`、`LAEventScreenRightSwipeUp` |
| 动议 | `LAEventNameMotionShake` |
| 耳机 | `LAEventNameHeadsetButtonPressSingle`、`LAEventNameHeadsetButtonHoldShort`、`LAEventNameHeadsetConnected`、`LAEventNameHeadsetDisconnected` |
| 锁屏时钟 | `LAEventNameLockScreenClockDoubleTap`、`LAEventNameLockScreenClockTapHold`、`LAEventNameLockScreenClockSwipeLeft`、`LAEventNameLockScreenClockSwipeRight`、`LAEventNameLockScreenClockSwipeDown` |
| 电源 | `LAEventNamePowerConnected`, `LAEventNamePowerDisconnected` |
| 多点触控 | `LAEventNameThreeFingerTap`、`LAEventNameThreeFingerPinch`、`LAEventNameThreeFingerSpread`、`LAEventNameFourFingerTap`、`LAEventNameFourFingerPinch`、`LAEventNameFourFingerSpread`、 `LAEventNameFiveFingerTap`、`LAEventNameFiveFingerPinch`、`LAEventNameFiveFingerSpread` |
| 翻盖式 | `LAEventNameClamshellOpen`、`LAEventNameClamshellClose` |
| SpringBoard 图标手势 | `LAEventNameSpringBoardIconFlickUp`、`LAEventNameSpringBoardIconFlickDown`、`LAEventNameSpringBoardIconFlickLeft`、`LAEventNameSpringBoardIconFlickRight` |
| 设备状态 | `LAEventNameDeviceLocked`, `LAEventNameDeviceUnlocked` |
| 网络 | `LAEventNameNetworkJoinedWiFi`、`LAEventNameNetworkLeftWiFi` |
| 指纹传感器 | `LAEventNameFingerprintSensorPressSingle` |

`LAEventNameSlideInFromTop` 是以下内容的宏别名： `LAEventNameStatusBarSwipeDown`，因此没有单独导出的符号 该别名。

### 事件用户信息常量

- `LAEventUserInfoDisplayIdentifier`
- `LAEventUserInfoIconView`
- `LAEventUserInfoUnlockedDeviceToSendEvent`

## 实施前需解决的兼容性问题

1. `LAActivator.h` 目前导入了 `<libkern/OSAtomic.h>`，但其公共 API surface 并未暴露 OSAtomic 类型。请从 重写了公共头文件。
2. `LASettingsViewController.h` 是 Activator 公共头文件集的一部分，并且 某些第三方越狱应用会动态链接 `libactivator.dylib` 到 当前的“设置”界面。因此，`libactivator` 必须保留兼容性适配层 用于公共设置类，而真正的设置界面实现位于 位于 `libactivatorsettings.dylib` 中。
3. `LAEvent` 声明了 `NSCoding`，而非 `NSSecureCoding`。请实现 `NSCoding` 出于兼容性考虑；对加法安全编码的支持需另行批准。
4. `LA_SETTINGS_CONTROLLER(superclass)` 体现了旧版设置的主机灵活性。 保留该宏以确保源代码兼容性，但不要让它主导现代 在没有明确需求的情况下，不采用主机架构。
5. 旧版内置事件常量并不意味着会立即进行事件注册。 每个事件家族在发布前仍需进行一次现代 iOS 功能评估 将出现在 `availableEventNames` 中。

## 推荐的下一个实现切片

1. 在 `libactivator` 中定义所有公共常量和 `LASharedActivator`。
2. 添加 `LAActivatorVersion_2_0 = 2000000` 并删除已废弃的 导入 `<libkern/OSAtomic.h>`。
3. 实现 `LAEvent`，其中 `name`/`mode`、`handled`、`userInfo` 为不可变，并且 对象的编码
4. 实现具有安全空注册表且不会崩溃的 `LAActivator` 单例 所有公共选择器的行为。
5. 在 `libactivator` 中为公共设置类添加兼容性补丁，具体如下： “设置”界面的实际行为已委托给 `libactivatorsettings.dylib`。
6. 添加编译/链接检查，以引用每个导出的常量，并进行实例化 `LAEvent`，调用代表性的 `LAActivator` 选择器，并通过 所有受支持的入口点。
7. 在添加 IPC 或 SpringBoard 运行时之前，请记录所有安全存根的行为。
