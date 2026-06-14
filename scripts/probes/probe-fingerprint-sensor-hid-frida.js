// Usage:
//   .venv/bin/frida -U SpringBoard -l scripts/probes/probe-fingerprint-sensor-hid-frida.js
//   frida -U SpringBoard -l scripts/probes/probe-fingerprint-sensor-hid-frida.js
//
// Purpose:
//   Inspect raw IOHIDEvent values delivered to SpringBoard -__handleHIDEvent*
//   while interacting with a Touch ID / fingerprint sensor.
//
// Notes:
//   Keep the Frida session interactive. Do not pass -q.
//   This is a diagnostic probe, not a test.

"use strict";

if (!ObjC.available) {
    throw new Error("Objective-C runtime is unavailable");
}

const probeName = "[fingerprint-hid-probe]";
const startedAt = Date.now();
const maxLogs = 260;
let logCount = 0;
const hookedImplementations = {};
let sensorIsDown = false;
let lastSensorDownTime = 0;
let lastSensorUpTime = 0;

const kIOHIDEventTypeKeyboard = 3;
const kIOHIDEventTypeDigitizer = 11;
const kIOHIDEventTypeBiometric = 14;
const kIOHIDEventTypeVendorDefined = 1;
const kIOHIDEventTypeForce = 32;

const kIOHIDEventFieldKeyboardUsagePage = kIOHIDEventTypeKeyboard << 16;
const kIOHIDEventFieldKeyboardUsage = kIOHIDEventFieldKeyboardUsagePage + 1;
const kIOHIDEventFieldKeyboardDown = kIOHIDEventFieldKeyboardUsagePage + 2;

const kHIDPageConsumer = 0x0c;
const kHIDPageSensor = 0x20;
const kHIDUsageConsumerMenu = 0x40;
const kHIDUsageConsumerMenuPick = 0x41;
const kHIDUsageSensorBiometric = 0x10;
const kHIDUsageSensorBiometricHumanTouch = 0x13;

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
const IOHIDEventGetSenderID = createNativeFunction("IOHIDEventGetSenderID", "uint64", ["pointer"]);
const CFArrayGetCount = createNativeFunction("CFArrayGetCount", "long", ["pointer"]);
const CFArrayGetValueAtIndex = createNativeFunction("CFArrayGetValueAtIndex", "pointer", ["pointer", "long"]);

function pointerString(value) {
    if (value === null || value === undefined) {
        return "nil";
    }
    return value.toString();
}

function hex(value) {
    try {
        const numberValue = normalizeNumber(value);
        return "0x" + numberValue.toString(16);
    } catch (_) {
        return String(value);
    }
}

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

function optionalNumber(value) {
    if (value === null || value === undefined) {
        return null;
    }
    const numberValue = normalizeNumber(value);
    return Number.isFinite(numberValue) ? numberValue : null;
}

function eventTypeName(type) {
    switch (type) {
    case kIOHIDEventTypeVendorDefined:
        return "vendor";
    case kIOHIDEventTypeKeyboard:
        return "keyboard";
    case kIOHIDEventTypeDigitizer:
        return "digitizer";
    case kIOHIDEventTypeBiometric:
        return "biometric?";
    case kIOHIDEventTypeForce:
        return "force";
    case 29:
        return "touch-id";
    default:
        return "type" + type;
    }
}

function integerField(event, type, offset) {
    if (!IOHIDEventGetIntegerValue || !event || event.isNull()) {
        return 0;
    }
    try {
        return normalizeNumber(IOHIDEventGetIntegerValue(event, (type << 16) + offset));
    } catch (_) {
        return 0;
    }
}

function nonZeroFields(event, type, maxOffset) {
    const fields = [];
    for (let offset = 0; offset <= maxOffset; offset++) {
        const value = integerField(event, type, offset);
        if (value !== 0) {
            fields.push("f" + offset + "=" + value + "/" + hex(value));
        }
    }
    return fields.join(",");
}

function describeKeyboard(event) {
    const usagePage = integerField(event, kIOHIDEventTypeKeyboard, 0);
    const usage = integerField(event, kIOHIDEventTypeKeyboard, 1);
    const down = integerField(event, kIOHIDEventTypeKeyboard, 2) !== 0;
    let name = "";
    if (usagePage === kHIDPageConsumer && usage === kHIDUsageConsumerMenu) {
        name = " consumer.menu";
    } else if (usagePage === kHIDPageConsumer && usage === kHIDUsageConsumerMenuPick) {
        name = " consumer.menu-pick";
    } else if (usagePage === kHIDPageSensor && usage === kHIDUsageSensorBiometric) {
        name = " sensor.biometric";
    } else if (usagePage === kHIDPageSensor && usage === kHIDUsageSensorBiometricHumanTouch) {
        name = " sensor.biometric-human-touch";
    }
    return "keyboard page=" + hex(usagePage) + " usage=" + hex(usage) + " down=" + down + name;
}

function describeEvent(event, depth) {
    if (!IOHIDEventGetType || !event || event.isNull()) {
        return "event=nil";
    }

    const type = IOHIDEventGetType(event);
    const parts = ["ptr=" + pointerString(event), "type=" + type + "(" + eventTypeName(type) + ")"];
    if (IOHIDEventGetSenderID) {
        try {
            const senderID = IOHIDEventGetSenderID(event);
            parts.push("senderID=" + hex(senderID));
        } catch (_) {}
    }

    if (type === kIOHIDEventTypeKeyboard) {
        parts.push(describeKeyboard(event));
    }

    const fields = nonZeroFields(event, type, 18);
    if (fields.length > 0) {
        parts.push("fields{" + fields + "}");
    }

    if (depth <= 0 || !IOHIDEventGetChildren || !CFArrayGetCount || !CFArrayGetValueAtIndex) {
        return parts.join(" ");
    }

    const children = IOHIDEventGetChildren(event);
    if (!children || children.isNull()) {
        return parts.join(" ") + " children=0";
    }

    const count = CFArrayGetCount(children);
    parts.push("children=" + count);
    for (let index = 0; index < count; index++) {
        const child = CFArrayGetValueAtIndex(children, index);
        parts.push("child" + index + "{" + describeEvent(child, depth - 1) + "}");
    }
    return parts.join(" ");
}

function summarizeTouchIDEvent(event) {
    const type = IOHIDEventGetType(event);
    if (type !== 29) {
        return null;
    }

    const down = integerField(event, type, 1) !== 0;
    const sequenceState = integerField(event, type, 4);
    const changedAt = Date.now();
    if (down) {
        sensorIsDown = true;
        lastSensorDownTime = changedAt;
    } else {
        sensorIsDown = false;
        lastSensorUpTime = changedAt;
    }

    return "TouchID " + (down ? "DOWN" : "UP") + " sequenceState=" + sequenceState;
}

function attachObjCMethod(className, selector, label) {
    const klass = ObjC.classes[className];
    if (!klass || !klass[selector] || !klass[selector].implementation) {
        log("missing " + className + " " + selector);
        return false;
    }

    const implementation = klass[selector].implementation;
    const key = implementation.toString();
    if (hookedImplementations[key]) {
        log("already hooked " + className + " " + selector + " as " + hookedImplementations[key]);
        return true;
    }

    hookedImplementations[key] = label;
    Interceptor.attach(implementation, {
        onEnter(args) {
            if (logCount >= maxLogs) {
                return;
            }

            const event = args[2];
            if (!event || event.isNull()) {
                return;
            }

            const touchIDSummary = summarizeTouchIDEvent(event);
            if (touchIDSummary) {
                log(label + " " + touchIDSummary + " raw{" + describeEvent(event, 1) + "}");
            } else {
                log(label + " " + describeEvent(event, 1));
            }
            logCount++;
        },
    });
    log("attached " + label);
    return true;
}

function shouldLogSystemGestureTouches() {
    const nowMs = Date.now();
    return sensorIsDown || nowMs - lastSensorDownTime < 1200 || nowMs - lastSensorUpTime < 1200;
}

function touchSummaryFromEvent(windowValue, eventValue) {
    let windowObject;
    let eventObject;
    try {
        windowObject = new ObjC.Object(windowValue);
        eventObject = new ObjC.Object(eventValue);
    } catch (_) {
        return null;
    }

    if (!eventObject["- allTouches"]) {
        return null;
    }

    const touches = eventObject.allTouches();
    if (!touches || touches.isNull()) {
        return null;
    }

    const allObjects = touches.allObjects();
    const count = Number(allObjects.count());
    const parts = [];
    for (let index = 0; index < count; index++) {
        const touch = allObjects.objectAtIndex_(index);
        const location = touch.locationInView_(windowObject);
        const phase = Number(touch.phase());
        const x = optionalNumber(location.x);
        const y = optionalNumber(location.y);
        if (x === null || y === null) {
            parts.push("phase=" + phase + " loc=<unavailable>");
        } else {
            parts.push("phase=" + phase + " loc={" + x.toFixed(1) + "," + y.toFixed(1) + "}");
        }
    }
    const bounds = windowObject.bounds();
    const width = optionalNumber(bounds.size ? bounds.size.width : null);
    const height = optionalNumber(bounds.size ? bounds.size.height : null);
    const boundsSummary = width === null || height === null ? "bounds=<unavailable>" :
        "bounds=" + width.toFixed(1) + "x" + height.toFixed(1);
    return "touches=" + count + " " + boundsSummary + " [" + parts.join("; ") + "]";
}

function attachSystemGestureWindowHook() {
    const klass = ObjC.classes._UISystemGestureWindow;
    if (!klass || !klass["- sendEvent:"] || !klass["- sendEvent:"].implementation) {
        log("missing _UISystemGestureWindow -sendEvent:");
        return false;
    }

    Interceptor.attach(klass["- sendEvent:"].implementation, {
        onEnter(args) {
            if (logCount >= maxLogs || !shouldLogSystemGestureTouches()) {
                return;
            }

            const summary = touchSummaryFromEvent(args[0], args[2]);
            if (!summary) {
                return;
            }

            log("_UISystemGestureWindow -sendEvent: near-touch-id " + summary);
            logCount++;
        },
    });
    log("attached _UISystemGestureWindow -sendEvent:");
    return true;
}

attachObjCMethod("SpringBoard", "- __handleHIDEvent:withUIEvent:", "SpringBoard -__handleHIDEvent:withUIEvent:");
attachObjCMethod("SpringBoard", "- __handleHIDEvent:", "SpringBoard -__handleHIDEvent:");
attachSystemGestureWindowHook();

log("ready: perform fingerprint sensor single touch, double touch, short hold, long hold, touch-and-slide-in, and touch-then-hold");

setTimeout(function () {
    log("done");
}, 60000);
