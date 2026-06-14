// Usage:
//   .venv/bin/frida -U SpringBoard -l scripts/probes/probe-force-touch-pressure-frida.js
//   frida -U SpringBoard -l scripts/probes/probe-force-touch-pressure-frida.js
//
// Purpose:
//   Inspect pressure values visible from _UISystemGestureWindow -sendEvent:.
//   This probe logs UIKit UITouch force values alongside the private UIEvent
//   -_hidEvent digitizer pressure fields and force-type HID events.
//
// Notes:
//   Keep the Frida session interactive. Do not pass -q.
//   This is a diagnostic probe, not a test.

"use strict";

if (!ObjC.available) {
    throw new Error("Objective-C runtime is unavailable");
}

const probeName = "[force-touch-pressure-probe]";
const startedAt = Date.now();
const maxLogs = 220;
let logCount = 0;

const kIOHIDEventTypeDigitizer = 11;
const kIOHIDEventTypeForce = 32;

const kIOHIDEventFieldDigitizerX = kIOHIDEventTypeDigitizer << 16;
const kIOHIDEventFieldDigitizerY = kIOHIDEventFieldDigitizerX + 1;
const kIOHIDEventFieldDigitizerZ = kIOHIDEventFieldDigitizerX + 2;
const kIOHIDEventFieldDigitizerType = kIOHIDEventFieldDigitizerX + 4;
const kIOHIDEventFieldDigitizerIndex = kIOHIDEventFieldDigitizerX + 5;
const kIOHIDEventFieldDigitizerIdentity = kIOHIDEventFieldDigitizerX + 6;
const kIOHIDEventFieldDigitizerEventMask = kIOHIDEventFieldDigitizerX + 7;
const kIOHIDEventFieldDigitizerRange = kIOHIDEventFieldDigitizerX + 8;
const kIOHIDEventFieldDigitizerTouch = kIOHIDEventFieldDigitizerX + 9;
const kIOHIDEventFieldDigitizerPressure = kIOHIDEventFieldDigitizerX + 10;
const kIOHIDEventFieldDigitizerMajorRadius = kIOHIDEventFieldDigitizerX + 20;
const kIOHIDEventFieldDigitizerMinorRadius = kIOHIDEventFieldDigitizerX + 21;

function now() {
    const date = new Date();
    return date.toTimeString().split(" ")[0] + "." + String(date.getMilliseconds()).padStart(3, "0");
}

function elapsed() {
    return "+" + String(Date.now() - startedAt).padStart(6, " ") + "ms";
}

function log(message) {
    console.log(probeName + " " + now() + " " + elapsed() + " " + message);
}

function findGlobalExport(name) {
    if (typeof Module.getGlobalExportByName === "function") {
        try {
            return Module.getGlobalExportByName(name);
        } catch (_) {}
    }

    if (typeof Module.findGlobalExportByName === "function") {
        const address = Module.findGlobalExportByName(name);
        if (address) {
            return address;
        }
    }

    if (typeof Module.findExportByName === "function") {
        const address = Module.findExportByName(null, name);
        if (address) {
            return address;
        }
    }

    return null;
}

function createNativeFunction(name, returnType, argumentTypes) {
    const address = findGlobalExport(name);
    if (!address) {
        log("missing export " + name);
        return null;
    }
    log("resolved " + name + " => " + address);
    return new NativeFunction(address, returnType, argumentTypes);
}

const IOHIDEventGetType = createNativeFunction("IOHIDEventGetType", "uint32", ["pointer"]);
const IOHIDEventGetChildren = createNativeFunction("IOHIDEventGetChildren", "pointer", ["pointer"]);
const IOHIDEventGetIntegerValue = createNativeFunction("IOHIDEventGetIntegerValue", "long", ["pointer", "uint32"]);
const IOHIDEventGetFloatValue = createNativeFunction("IOHIDEventGetFloatValue", "double", ["pointer", "uint32"]);
const IOHIDEventGetSenderID = createNativeFunction("IOHIDEventGetSenderID", "uint64", ["pointer"]);
const CFArrayGetCount = createNativeFunction("CFArrayGetCount", "long", ["pointer"]);
const CFArrayGetValueAtIndex = createNativeFunction("CFArrayGetValueAtIndex", "pointer", ["pointer", "long"]);

function normalizeNumber(value) {
    if (value === null || value === undefined) {
        return 0;
    }
    if (typeof value === "number") {
        return value;
    }
    if (typeof value.toNumber === "function") {
        return value.toNumber();
    }
    if (typeof value.toInt32 === "function") {
        return value.toInt32();
    }
    return Number(value);
}

function hex(value) {
    const numberValue = normalizeNumber(value);
    return "0x" + numberValue.toString(16);
}

function safeFloat(event, field) {
    if (!IOHIDEventGetFloatValue || !event || event.isNull()) {
        return 0;
    }
    try {
        return IOHIDEventGetFloatValue(event, field);
    } catch (_) {
        return 0;
    }
}

function safeInteger(event, field) {
    if (!IOHIDEventGetIntegerValue || !event || event.isNull()) {
        return 0;
    }
    try {
        return normalizeNumber(IOHIDEventGetIntegerValue(event, field));
    } catch (_) {
        return 0;
    }
}

function eventTypeName(type) {
    switch (type) {
    case kIOHIDEventTypeDigitizer:
        return "digitizer";
    case kIOHIDEventTypeForce:
        return "force";
    default:
        return "type" + type;
    }
}

function describeDigitizer(event) {
    const eventMask = safeInteger(event, kIOHIDEventFieldDigitizerEventMask) >>> 0;
    return [
        "digitizer",
        "digType=" + safeInteger(event, kIOHIDEventFieldDigitizerType),
        "idx=" + safeInteger(event, kIOHIDEventFieldDigitizerIndex),
        "identity=" + safeInteger(event, kIOHIDEventFieldDigitizerIdentity),
        "touch=" + safeInteger(event, kIOHIDEventFieldDigitizerTouch),
        "range=" + safeInteger(event, kIOHIDEventFieldDigitizerRange),
        "x=" + safeFloat(event, kIOHIDEventFieldDigitizerX).toFixed(4),
        "y=" + safeFloat(event, kIOHIDEventFieldDigitizerY).toFixed(4),
        "z=" + safeFloat(event, kIOHIDEventFieldDigitizerZ).toFixed(4),
        "pressure=" + safeFloat(event, kIOHIDEventFieldDigitizerPressure).toFixed(4),
        "major=" + safeFloat(event, kIOHIDEventFieldDigitizerMajorRadius).toFixed(4),
        "minor=" + safeFloat(event, kIOHIDEventFieldDigitizerMinorRadius).toFixed(4),
        "emsk=0x" + eventMask.toString(16),
    ].join(" ");
}

function describeNonZeroFields(event, type) {
    const parts = [];
    const base = type << 16;
    for (let offset = 0; offset <= 24; offset++) {
        const field = base + offset;
        const integerValue = safeInteger(event, field);
        const floatValue = safeFloat(event, field);
        if (integerValue !== 0 || Math.abs(floatValue) > 0.000001) {
            parts.push("f" + offset + "=" + integerValue + "/" + floatValue.toFixed(4));
        }
    }
    return parts.join(",");
}

function describeHIDEvent(event, depth) {
    if (!IOHIDEventGetType || !event || event.isNull()) {
        return "hid=nil";
    }

    const type = IOHIDEventGetType(event);
    const parts = ["ptr=" + event, "type=" + type + "(" + eventTypeName(type) + ")"];
    if (IOHIDEventGetSenderID) {
        try {
            parts.push("senderID=" + hex(IOHIDEventGetSenderID(event)));
        } catch (_) {}
    }

    if (type === kIOHIDEventTypeDigitizer) {
        parts.push(describeDigitizer(event));
    } else if (type === kIOHIDEventTypeForce) {
        parts.push("forceFields{" + describeNonZeroFields(event, type) + "}");
    }

    if (depth <= 0 || !IOHIDEventGetChildren || !CFArrayGetCount || !CFArrayGetValueAtIndex) {
        return parts.join(" ");
    }

    const children = IOHIDEventGetChildren(event);
    if (!children || children.isNull()) {
        return parts.join(" ");
    }

    const count = normalizeNumber(CFArrayGetCount(children));
    parts.push("children=" + count);
    for (let index = 0; index < count; index++) {
        const child = CFArrayGetValueAtIndex(children, index);
        parts.push("child" + index + "{" + describeHIDEvent(child, depth - 1) + "}");
    }
    return parts.join(" ");
}

function describeTouches(event) {
    let touches;
    try {
        touches = event.allTouches();
    } catch (_) {
        return "touches=unavailable";
    }

    if (!touches || touches.isNull()) {
        return "touches=nil";
    }

    const result = [];
    const enumerator = touches.objectEnumerator();
    let touch;
    while ((touch = enumerator.nextObject()) !== null) {
        const parts = [];
        parts.push("phase=" + touch.phase());
        try {
            const location = touch.locationInView_(touch.view());
            parts.push("location={" + location.x.toFixed(1) + "," + location.y.toFixed(1) + "}");
        } catch (_) {}
        if (touch.respondsToSelector_(ObjC.selector("force"))) {
            try {
                parts.push("force=" + touch.force().toFixed(4));
            } catch (_) {}
        }
        if (touch.respondsToSelector_(ObjC.selector("maximumPossibleForce"))) {
            try {
                parts.push("maxForce=" + touch.maximumPossibleForce().toFixed(4));
            } catch (_) {}
        }
        result.push("[" + parts.join(" ") + "]");
    }
    return "touches=" + result.join(";");
}

function hidEventFromUIEvent(event) {
    if (!event.respondsToSelector_(ObjC.selector("_hidEvent"))) {
        return null;
    }
    try {
        return event["- _hidEvent"]();
    } catch (error) {
        log("_hidEvent failed: " + error);
        return null;
    }
}

const systemGestureWindowClass = ObjC.classes._UISystemGestureWindow;
if (!systemGestureWindowClass || !systemGestureWindowClass["- sendEvent:"]) {
    throw new Error("_UISystemGestureWindow -sendEvent: is unavailable");
}

Interceptor.attach(systemGestureWindowClass["- sendEvent:"].implementation, {
    onEnter(args) {
        if (logCount >= maxLogs) {
            return;
        }

        const event = new ObjC.Object(args[2]);
        const hidEvent = hidEventFromUIEvent(event);
        log(describeTouches(event));
        log(describeHIDEvent(hidEvent, 2));
        logCount++;
    },
});

log("attached to _UISystemGestureWindow -sendEvent:");
setTimeout(() => {
    log("done");
}, 30000);
