# 低风险事件源端到端流程

本文记录以 `device locked / unlocked` 为例的端到端流程。图中 participant 只表示真实角色或组件；队列和线程只作为关键动作的执行上下文说明，不作为 participant。

```mermaid
sequenceDiagram
    actor User
    participant CLI as activator CLI
    participant Client as LAActivator client facade
    participant IPC as CPDistributedMessagingCenter
    participant Server as SpringBoard LAIPCServer
    participant Backend as LAServerBackend
    participant Tweak as ActivatorTweak
    participant Source as LATLockStateEventSource
    participant Runtime as LATRuntimeStateSource
    participant Lock as SBLockScreenManager
    participant Activator as LAActivator SpringBoard
    participant Listener as Assigned LAListener

    User->>CLI: set assignment key
    CLI->>Client: _setObject for preference
    Client->>IPC: send plist safe IPC
    IPC->>Server: set preference request
    Server->>Backend: translate legacy key and assign event
    Backend-->>Server: update memory and schedule persistence
    Server-->>Client: OK

    Note over Tweak,Runtime: SpringBoard constructor creates tweak-side runtime source
    Runtime->>Activator: la_updateRuntimeEventMode
    Note over Tweak,Source: Constructor creates Source with Runtime
    Tweak->>Source: start after applicationDidFinishLaunching
    Source->>Lock: seed isUILocked
    Source->>Runtime: noteUILocked
    Runtime->>Activator: la_updateRuntimeEventMode
    Note over Source,Lock: Runs on SpringBoard main queue
    Source->>Source: register lockstate notification

    User->>Tweak: lock or unlock device
    Tweak->>Source: Darwin notification callback
    Note over Tweak,Source: Callback runs on SpringBoard main queue
    Source->>Lock: isUILocked
    Source->>Runtime: noteUILocked
    Note over Runtime: Runtime cache uses internal serial queue
    Runtime->>Activator: la_updateRuntimeEventMode
    Source->>Source: detect lock state edge

    alt lock state changed
        Source->>Activator: sendEventToListener
        Activator->>Backend: assignedListenerNamesForEvent
        Backend-->>Activator: assigned listener names
        Activator->>Activator: apply dispatch gates
        Activator->>Listener: receiveEvent forListenerName
        Listener-->>Activator: mark handled if consumed
    else duplicate notification or unreadable state
        Source-->>Tweak: no event
    end
```

关键约定：event source 可以在来源队列接收系统信号，但读取 SpringBoard/UI 状态和调用 `sendEventToListener:` 的路径应回到 SpringBoard main queue；如果某个 adapter 本身读取 SpringBoard/UI/SPI 状态，它应像 `LATLockStateEventSource` 一样声明为 main-queue confined。
