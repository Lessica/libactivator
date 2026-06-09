# Testing

This document defines the categories, entry points, and boundaries of this project’s test harness. Logs, suite names, case names, and failure reasons in the test code must be in English; this document may be in Chinese.

## Execution Ownership

Test logic is executed based on the ownership of the behavior under test.

Runner-owned tests execute assertions within the `libactivator-tests` process. They are used to verify non-SpringBoard client perspectives, such as command-line entry points, testing IPC reachability, result aggregation, exit codes, whether the `LAActivator` facade in a regular process is forwarded to SpringBoard via IPC, and client fallback behavior when the server is unavailable. Runner-owned tests must not directly create or modify SpringBoard’s authoritative runtime state; when SpringBoard state is required, it must be prepared via formal IPC or testing IPC fixtures.

SpringBoard-owned tests execute assertions within the SpringBoard process via hidden testing IPC. Any tests that depend on the SpringBoard authoritative backend, real listener objects, event data sources, built-in listeners/actions, dispatch callbacks, persistence writes, runtime state providers, SpringBoard SPI, main queue device actions, or real hooks must be placed in SpringBoard-owned tests. Tests related to `registerListener:forName:` and `registerEventDataSource:forEventName:` also fall into this category.

Watchers are responsible only for observing the SpringBoard runtime state; they do not execute assertions and do not produce pass/fail results. Watcher output cannot be used as automated test results; it serves only to assist manual assessment of state changes in real-world scenarios.

By default, stable tests may include runner-owned tests and SpringBoard-owned tests, but they must remain stable and reproducible, and must not corrupt real user configurations or persist runtime state. Runtime input and runtime device are specialized categories and must not be included in the default submission threshold.

## Stable Tests

Default entry points:

```sh
. scripts/roothide.sh
scripts/run-tests.sh
```

Default execution on the device-side runner:

```sh
/usr/libexec/libactivator/libactivator-tests run
```

Stable tests constitute the commit threshold and cover only tests that are stable, repeatable, and do not pollute the SpringBoard runtime state:

- `ClientFacade`
- `LAEvent`
- `Persistence`
- `SpringBoardCore`
- `Dispatch`
- `BuiltInActions`

`ClientFacade` runs within the runner process, verifying the Public API facade, IPC forwarding, remote listener proxy, assignment/blacklist/profile round-trips, and dispatch handler callbacks from the perspective of a regular process. Other default stable suites run via SpringBoard-owned testing IPC.

Stable tests must not call `la_noteHomeScreenVisible:`, `la_noteLockScreenVisible:`, `la_noteScreenBlanked:`, or any other runtime state injection entry points. A failure indicates a regression in the core model, IPC, dispatch, or implemented built-in actions.

## Runtime Input Tests

Command-line entry point:

```sh
/usr/libexec/libactivator/libactivator-tests run-runtime-input
```

Runtime input tests verify only the set of input sources and manual input semantics of `LAActivatorRuntimeStateProvider`. They allow calls to `la_noteHomeScreenVisible:`, `la_noteLockScreenVisible:`, and `la_noteScreenBlanked:`, but the runtime input state must be cleared before and after the suite.

Runtime input tests must not perform device automation actions such as opening an app, returning to the home screen, locking the screen, or unlocking the device. A failure indicates an issue with the provider’s input model or callback-only runtime semantics.

## Runtime Device Tests

Entry point:

```sh
/usr/libexec/libactivator/libactivator-tests run-device-runtime
```

Runtime device tests verify real SpringBoard hooks and device state. They only allow tests driven by device actions and real SpringBoard state; invoking any `la_note*` runtime state injection entry points is prohibited.

Runtime device tests are not part of the default submission threshold. A failure merely indicates that the device automation workflow, current device state, or real hook scenario requires separate investigation; it does not block the submission of core or built-in actions.

## Runtime Watcher

Watcher entry points:

```sh
. scripts/roothide.sh
scripts/watch-runtime-state.sh
```

The Watcher only outputs the current SpringBoard runtime state for manual observation. It is not an automated pass/fail test.
