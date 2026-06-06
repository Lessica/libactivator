# On-Device Verification

This document tracks manual verification steps that require a jailbroken device.
Do not mark runtime-backed slices as fully verified until the relevant checklist
passes on device.

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
- Confirm `-[CPDistributedMessagingCenter runServer]` is called once for the
  Activator server.
- Confirm `ActivatorTweak` does not inject through a `com.apple.UIKit` filter.

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

### Persistence Check

- Restart SpringBoard after assignment, blacklist, and profile changes.
- Confirm the state still loads from
  `jbroot(@"/var/mobile/Library/Preferences/libactivator.plist")`.
- Confirm non-SpringBoard clients do not write their own runtime preference
  file.

### Not Covered

- Event delivery.
- Cross-process listener object registration.
- Cross-process event data-source object registration.
- Foreground application state.
- Lock screen or home screen event mode.
- Settings UI controller creation.
