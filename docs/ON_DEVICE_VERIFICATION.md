# On-Device Verification

This document tracks manual verification steps that require a jailbroken device.
Do not mark runtime-backed slices as fully verified until the relevant checklist
passes on device.

## Automated Device Tests

### Command

- Source the matching jailbreak scheme first, for example `. scripts/roothide.sh`.
- Run `scripts/run-tests.sh`.

### Behavior

- The script runs `gmake do LA_TESTING=1`.
- The testing build uses
  `jbroot(@"/var/mobile/Library/Preferences/libactivator.tests.plist")`.
- The testing build exposes hidden SpringBoard testing IPC only while
  `LA_TESTING` is defined.
- The device runner is installed only in the testing package under
  `/usr/libexec/libactivator/`.
- The script runs the installed device runner over SSH.
- The script records the SpringBoard pid before and after the runner, and fails
  if SpringBoard restarts during tests.

### Coverage

- Core event model, persistence, registries, assignments, profiles, blacklist,
  dispatch, no-touch deferral, unlock-to-send callback, state/config IPC, and
  basic runtime mode automation.
- Device automation currently uses SpringBoard-side testing IPC for lock,
  unlock, reset home, open `com.apple.Preferences`, suspend, and frontmost-app
  queries.
- On iPhone XR iOS 15.0 Dopamine roothide, the current test result is 33
  passed, 0 failed, and 0 skipped.

### Diagnostics

- Use `scripts/device-console.sh stream` to stream USB syslog for SpringBoard,
  backboardd, and the test runner.
- Use `scripts/device-crashlogs.sh list` to copy and list SpringBoard crash
  reports without removing them from the device.
- Use `scripts/device-crashlogs.sh clean` before a focused crash reproduction;
  this moves existing SpringBoard crash reports into
  `logs/device-crashlogs/cleared`.
- Use `scripts/device-crashlogs.sh pull` to copy SpringBoard crash reports into
  `logs/device-crashlogs` without removing them from the device.
- Use SpringBoard pid changes as the first signal for SpringBoard restarts.
  Crash reports are used for stack diagnosis after a restart is detected.
- Run UIKit, SpringBoard, and FrontBoard private API probes on the SpringBoard
  main queue.
- Do not use Frida `-q` for interactive or long-running verification. In the
  installed Frida CLI, `-q` means quiet mode with no prompt and exits after
  `-l` or `-e`, so scripts that need to observe callbacks must be run without
  `-q`.
- Avoid registering long-lived Frida-created Objective-C objects into
  SpringBoard registries. Prefer temporary method hooks for observation, or
  explicitly unregister before ending the Frida session.

## State/Config IPC

### Preconditions

- Build and install the current package on the device.
- Restart SpringBoard after installation.
- Confirm `ActivatorTweak.dylib` is loaded only into SpringBoard.
- Confirm `libactivator.dylib` is loaded in SpringBoard.

### SpringBoard Server

- Attach to SpringBoard with `frida -U SpringBoard`.
- Confirm `+[CPDistributedMessagingCenter centerNamed:]` is called with
  `libactivator.springboard`.
- Confirm `-[CPDistributedMessagingCenter runServerOnCurrentThread]` is called
  once for the Activator server. On iOS 15.0, `-runServer` is not present.
- Confirm `ActivatorTweak` does not inject through a `com.apple.UIKit` filter.

### iPhone XR iOS 15.0 Dopamine roothide Notes

- Use the project virtual environment for Frida commands. The tested device
  uses Frida 16.1.4, so the host tooling must match that major/minor version.
- Use USB Frida only. Do not use a remote Frida server or a forwarded Frida
  port for this project.
- Run roothide install verification with `. scripts/roothide.sh && gmake do`.
- `ActivatorTweak.dylib` and `libactivator.dylib` loaded in SpringBoard after
  package install and SpringBoard restart.
- `CPDistributedMessagingCenter` exposes `-runServerOnCurrentThread`, not
  `-runServer`, on the tested device.
- `doesServerExist` returned true for `libactivator.springboard`.
- A read-only request to
  `libactivator.request.available-profile-names` returned `Default`.
- SpringBoard-internal app launch automation should use
  `-[SpringBoard launchApplicationWithIdentifier:suspended:]` on the main
  queue. `LSApplicationWorkspace` is not the verified SpringBoard-internal
  foreground activation path for the testing harness.

### Client Round Trip

Run a temporary client process linked against `libactivator.dylib` and verify:

- `availableProfileNames` returns at least `Default`.
- `currentProfileName` returns `Default` on a clean state.
- `assignedListenerNamesForEvent:` returns an empty array for an unassigned
  event.
- `assignEvent:toListenersWithNames:` changes the SpringBoard authoritative
  assignment state.
- Repeating the same assignment does not post a local assignments-changed
  notification in the client.
- `unassignEvent:` changes state only when an assignment exists.
- Repeating `unassignEvent:` does not post a local assignments-changed
  notification in the client.
- `setApplicationWithDisplayIdentifier:isBlacklisted:` changes blacklist state
  only when the requested value differs from the current value.
- Setting `currentProfileName` changes state only when the requested profile is
  new or different from the current profile.

### iPhone XR iOS 15.0 Dopamine roothide Client Notes

- `Activator.app` currently has no entitlements. Do not use it as the successful
  CPDistributedMessagingCenter client reference until its entitlements are
  defined.
- A sandboxed `Activator.app` process could not see
  `libactivator.springboard`; `doesServerExist` returned false and direct
  messages returned nil.
- `com.apple.Preferences` was verified as a non-SpringBoard system client by
  loading the installed `libactivator.dylib` with USB Frida.
- In `com.apple.Preferences`, `availableProfileNames` returned `Default`.
- In `com.apple.Preferences`, changing `currentProfileName` to
  `CodexIPCVerification` returned that value through the facade, then restored
  to `Default`.
- In `com.apple.Preferences`, a temporary blacklist value was changed and
  restored through the facade.
- In `com.apple.Preferences`, a temporary assignment for
  `libactivator.ipc-check.event` was changed and removed through the facade.
- Nil-mode assignment compatibility was verified with a temporary SpringBoard
  event data source. Assigning an event without a mode wrote all compatible
  modes, querying without a mode used the current event mode, and unassigning
  without a mode removed all event modes.
- SpringBoard-only event dispatch was verified with temporary listeners.
  Assigned dispatch, explicit dispatch, compatibility filtering, handled-state
  propagation, abort fallback, preview, deactivate broadcast, and blacklist
  filtering all behaved as expected.
- Non-SpringBoard event dispatch IPC was verified from a fresh
  `com.apple.Preferences` process loaded with the current roothide
  `libactivator.dylib` path discovered from SpringBoard. Assigned dispatch,
  explicit dispatch, abort dispatch, preview dispatch, deactivate broadcast,
  handled-state replies, and property-list-safe `UserInfo` delivery all behaved
  as expected.
- Restart or respawn the client process after reinstalling `libactivator.dylib`;
  an already-running client may still hold the previous dylib image.

### Persistence Check

- Restart SpringBoard after assignment, blacklist, and profile changes.
- Confirm the state still loads from
  `jbroot(@"/var/mobile/Library/Preferences/libactivator.plist")`.
- Confirm non-SpringBoard clients do not write their own runtime preference
  file.

### Not Covered

- Built-in event delivery.
- Cross-process listener object registration.
- Cross-process event data-source object registration.
- Foreground application state.
- Lock screen or home screen event mode.
- Settings UI controller creation.
