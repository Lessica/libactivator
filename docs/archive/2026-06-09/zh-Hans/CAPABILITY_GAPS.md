# 能力差距

此表记录了尚未实现的运行时功能，包括 是否存在现代 iOS 参考资料。请勿通过猜测来填补行为缺失的部分 SPI 行为。

| 能力 | 当前占位符 | 研究进展 | 需跟进 |
| --- | --- | --- | --- |
| SpringBoard 前台应用程序状态 | 在 `LAActivatorRuntimeStateProvider` 中实现；SpringBoard 会按需查询 `_accessibilityFrontMostApplication`。 | 已在 iPhone XR（iOS 15.0）上验证，使用 roothide 且不包含 `BKSApplicationStateMonitor`。 | 在更高版本的 iOS 上重新验证前台显示标识符的行为。 |
| 主屏幕与应用内模式 | 通过 SpringBoard 主屏幕可见性钩子及运行时模式重新计算实现。 | 已在 iPhone XR（iOS 15.0）上通过 roothide 验证，使用无 Logos 钩子。 | 在更高版本的 iOS 上重新验证模式切换。 |
| 锁屏模式 | 通过 `SBLockScreenManager` 的锁屏状态检查、CoverSheet 可见性以及黑屏通知实现。 | 已在 iPhone XR（iOS 15.0）上通过 roothide 验证，并使用了仅限 SpringBoard 的状态钩子。 | 在更高版本的 iOS 上重新验证锁屏可见性及后台模式下的行为。 |
| 事件模式变更通知 | 通过状态提供者的重新计算以及监听器的 `didChangeToEventMode:` 回调实现。 | 已在 iPhone XR（iOS 15.0）上通过 roothide 验证。 | 在更高版本的 iOS 上重新验证回调时机和重复处理抑制机制。 |
| 支持解锁后发送 | 作为仅支持回调的兼容路径实现，并包含私有的 SpringBoard 功能检测。 | “仅回调”行为是作用域兼容性要求；密码提交和完整的主动解锁流程不属于旧版核心行为。 | 在更高版本的 iOS 上重新验证回调行为。 |
| 延迟无接触派送 | 通过 `_UISystemGestureWindow -sendEvent:` 实现触摸跟踪和延迟的法线事件分发。 | 已在 iPhone XR（iOS 15.0）上验证，使用 roothide 并采用旧版“处理于队列中”的语义。 | 在更高版本的 iOS 上重新验证主动触摸跟踪和延迟分发功能。 |
| Profile 创建语义 | `setCurrentProfileName:` 当前会把不存在的 profile 创建为空的 assignment 命名空间。 | 1.9.0 引入 profiles，且 1.9.5 更新日志写明新 profile 会作为当前 profile 的副本创建，但 public setter 行为与 UI action 行为的精确边界尚未逆向确认。 | 在把当前空 profile 行为视为兼容前，先逆向确认 1.9.x 的 profile 创建/切换语义。 |
| 设置 UI 控制器工厂 | 配置支持查询返回 `NO`；工厂方法返回 `nil`。 | `libactivatorsettings.dylib` 主机 API 和控制器工厂契约。 | 在“设置”用户界面阶段进行实现。 |
| 内置事件源 | 尚未注册任何内置事件钩子。 | 针对每个事件的现代能力评估及钩子/源策略。 | Event-family 研究与用户评价。 |
| 内置监听器/操作 | 尚未注册任何内置的监听器/操作实现。 | 采用基于监听器/操作的现代等效方案及包/资源布局；遵循传统的 `master` 资源语义，因为旧版第三方包很可能已不可用。 | 监听器/操作优先级及实现说明。 |
