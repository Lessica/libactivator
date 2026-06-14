// Usage:
//   frida -U -n SpringBoard -l scripts/probes/probe-springboard-hid-swipe-frida.js
//
// Purpose:
//   Inspect raw IOHIDEvent values delivered to SpringBoard -__handleHIDEvent*
//   and check whether digitizer swipe masks survive on that path.
//
// Notes:
//   This is a diagnostic probe, not a test. On the current target observed
//   during development, -__handleHIDEvent:withUIEvent: received keyboard,
//   force, and other non-digitizer event types, but did not receive digitizer
//   touch events.

const maxLogs = 120;
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

function eventTypeSummary(event, label) {
  if (event.isNull()) {
    return `${label}=null`;
  }

  const type = IOHIDEventGetType(event);
  const parts = [`${label}=${event}`, `type=${type}`];
  const children = IOHIDEventGetChildren(event);
  if (children.isNull()) {
    parts.push("children=null");
    return parts.join(" ");
  }

  const count = CFArrayGetCount(children);
  parts.push(`children=${count}`);
  for (let i = 0; i < count; i++) {
    const child = CFArrayGetValueAtIndex(children, i);
    if (child.isNull()) {
      continue;
    }
    const childType = IOHIDEventGetType(child);
    if (childType === eventTypeDigitizer) {
      appendDigitizerFields(parts, child, `child${i}`);
    } else {
      parts.push(`child${i}{type=${childType}}`);
    }
  }
  return parts.join(" ");
}

function appendDigitizerFields(parts, event, name) {
  const digitizerType = IOHIDEventGetIntegerValue(event, fieldDigitizerType);
  const index = IOHIDEventGetIntegerValue(event, fieldDigitizerIndex);
  const touch = IOHIDEventGetIntegerValue(event, fieldDigitizerTouch);
  const range = IOHIDEventGetIntegerValue(event, fieldDigitizerRange);
  const x = IOHIDEventGetFloatValue(event, fieldDigitizerX);
  const y = IOHIDEventGetFloatValue(event, fieldDigitizerY);
  const eventMask = IOHIDEventGetIntegerValue(event, fieldDigitizerEventMask) >>> 0;
  const swipeMask = (eventMask & swipeMaskValue) >>> 16;
  parts.push(
    `${name}{digType=${digitizerType},idx=${index},touch=${touch},range=${range},x=${x.toFixed(4)},y=${y.toFixed(4)},emsk=0x${eventMask.toString(16)},smsk=0x${swipeMask.toString(16)}}`
  );
}

function attachMethod(selectorName, label) {
  const cls = ObjC.classes.SpringBoard;
  if (!cls || !cls[selectorName]) {
    console.log(`[probe] missing SpringBoard ${selectorName}`);
    return;
  }

  Interceptor.attach(cls[selectorName].implementation, {
    onEnter(args) {
      if (logs >= maxLogs) {
        return;
      }

      const event = args[2];
      if (event.isNull()) {
        return;
      }

      console.log(`[probe:${label}] ${eventTypeSummary(event, "hid")}`);
      logs++;
    },
  });
  console.log(`[probe] attached SpringBoard ${selectorName}`);
}

if (!ObjC.available) {
  throw new Error("ObjC runtime is not available");
}

attachMethod("- __handleHIDEvent:", "one");
attachMethod("- __handleHIDEvent:withUIEvent:", "two");

setTimeout(() => {
  console.log("[probe] done");
}, 25000);
