// Usage:
//   frida -U -n SpringBoard -l scripts/probes/probe-uievent-hid-frida.js
//
// Purpose:
//   Inspect the private UIEvent -_hidEvent payload observed by
//   _UISystemGestureWindow -sendEvent: and print digitizer child event masks.
//
// Notes:
//   This is a diagnostic probe, not a test. It only logs the first maxLogs
//   events and then remains loaded until Frida exits.

const maxLogs = 80;
let logs = 0;

const eventTypeDigitizer = 11;
const digitizerBase = eventTypeDigitizer << 16;
const fieldDigitizerX = digitizerBase;
const fieldDigitizerY = digitizerBase + 1;
const fieldDigitizerType = digitizerBase + 4;
const fieldDigitizerIndex = digitizerBase + 5;
const fieldDigitizerEventMask = digitizerBase + 7;
const fieldDigitizerRange = digitizerBase + 8;
const fieldDigitizerTouch = digitizerBase + 9;
const swipeMaskValue = 0xff000000;

function findExport(name) {
  const p = Module.findGlobalExportByName(name);
  if (p === null) {
    throw new Error(`missing export ${name}`);
  }
  return p;
}

const IOHIDEventGetType = new NativeFunction(findExport("IOHIDEventGetType"), "uint32", ["pointer"]);
const IOHIDEventGetChildren = new NativeFunction(findExport("IOHIDEventGetChildren"), "pointer", ["pointer"]);
const IOHIDEventGetIntegerValue = new NativeFunction(findExport("IOHIDEventGetIntegerValue"), "long", [
  "pointer",
  "uint32",
]);
const IOHIDEventGetFloatValue = new NativeFunction(findExport("IOHIDEventGetFloatValue"), "double", [
  "pointer",
  "uint32",
]);
const CFArrayGetCount = new NativeFunction(findExport("CFArrayGetCount"), "long", ["pointer"]);
const CFArrayGetValueAtIndex = new NativeFunction(findExport("CFArrayGetValueAtIndex"), "pointer", [
  "pointer",
  "long",
]);

function parseHIDEvent(hidEvent) {
  if (hidEvent.isNull()) {
    return "hid=null";
  }

  const type = IOHIDEventGetType(hidEvent);
  const children = IOHIDEventGetChildren(hidEvent);
  const parts = [`hid=${hidEvent}`, `type=${type}`];
  if (children.isNull()) {
    return `${parts.join(" ")} children=null`;
  }

  const count = CFArrayGetCount(children);
  parts.push(`children=${count}`);
  for (let i = 0; i < count; i++) {
    const child = CFArrayGetValueAtIndex(children, i);
    if (child.isNull()) {
      continue;
    }

    const childType = IOHIDEventGetType(child);
    const digitizerType = IOHIDEventGetIntegerValue(child, fieldDigitizerType);
    const index = IOHIDEventGetIntegerValue(child, fieldDigitizerIndex);
    const touch = IOHIDEventGetIntegerValue(child, fieldDigitizerTouch);
    const range = IOHIDEventGetIntegerValue(child, fieldDigitizerRange);
    const x = IOHIDEventGetFloatValue(child, fieldDigitizerX);
    const y = IOHIDEventGetFloatValue(child, fieldDigitizerY);
    const eventMask = IOHIDEventGetIntegerValue(child, fieldDigitizerEventMask) >>> 0;
    const swipeMask = (eventMask & swipeMaskValue) >>> 16;
    parts.push(
      `child${i}{type=${childType},digType=${digitizerType},idx=${index},touch=${touch},range=${range},x=${x.toFixed(4)},y=${y.toFixed(4)},emsk=0x${eventMask.toString(16)},smsk=0x${swipeMask.toString(16)}}`
    );
  }
  return parts.join(" ");
}

if (!ObjC.available) {
  throw new Error("ObjC runtime is not available");
}

const cls = ObjC.classes._UISystemGestureWindow;
if (!cls) {
  throw new Error("_UISystemGestureWindow not found");
}

const impl = cls["- sendEvent:"].implementation;
Interceptor.attach(impl, {
  onEnter(args) {
    if (logs >= maxLogs) {
      return;
    }

    const event = new ObjC.Object(args[2]);
    const responds = event.respondsToSelector_(ObjC.selector("_hidEvent"));
    if (!responds) {
      console.log(`[probe] UIEvent ${event} does not respond to _hidEvent`);
      logs++;
      return;
    }

    try {
      const hidEvent = event["- _hidEvent"]();
      console.log(`[probe] ${parseHIDEvent(hidEvent)}`);
    } catch (e) {
      console.log(`[probe] _hidEvent failed: ${e}`);
    }
    logs++;
  },
});

console.log("[probe] attached to _UISystemGestureWindow -sendEvent:");
setTimeout(() => {
  console.log("[probe] done");
}, 20000);
