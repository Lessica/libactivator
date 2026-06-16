// Usage:
//   frida -U SpringBoard -l scripts/probes/probe-lock-button-state-machine-frida.js
//   frida -U SpringBoard -l scripts/probes/probe-lock-button-state-machine-frida.js
//
// Purpose:
//   Observe LATButtonEventSource lock button press recognition without changing
//   behavior. Use this to diagnose lock.press.double / triple timing on a real
//   SpringBoard.
//
// Notes:
//   Keep the Frida session interactive. Do not pass -q.
//   This is a diagnostic probe, not a test.

"use strict";

if (!ObjC.available) {
    throw new Error("Objective-C runtime is unavailable");
}

const probeName = "[lock-button-state-probe]";
const startedAt = Date.now();
const hookedImplementations = {};

const kIOHIDEventTypeKeyboard = 3;
const kIOHIDEventFieldKeyboardUsagePage = kIOHIDEventTypeKeyboard << 16;
const kIOHIDEventFieldKeyboardUsage = kIOHIDEventFieldKeyboardUsagePage + 1;
const kIOHIDEventFieldKeyboardDown = kIOHIDEventFieldKeyboardUsagePage + 2;
const kHIDPageConsumer = 0x0c;
const kHIDUsageConsumerPower = 0x30;

function now() {
    const date = new Date();
    return (
        date.toTimeString().split(" ")[0] +
        "." +
        String(date.getMilliseconds()).padStart(3, "0")
    );
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
const IOHIDEventGetIntegerValue = createNativeFunction("IOHIDEventGetIntegerValue", "long", ["pointer", "uint32"]);
const IOHIDEventGetSenderID = createNativeFunction("IOHIDEventGetSenderID", "uint64", ["pointer"]);

function boolFromArg(value) {
    try {
        return value.toInt32() !== 0;
    } catch (_) {
        return false;
    }
}

function pointerString(value) {
    if (value === null || value === undefined) {
        return "nil";
    }
    return value.toString();
}

function stringFromObjC(value) {
    if (!value || value.isNull()) {
        return "nil";
    }
    try {
        return new ObjC.Object(value).toString();
    } catch (_) {
        return pointerString(value);
    }
}

function callObjectMethod(object, selector) {
    try {
        if (object && object[selector]) {
            return object[selector]();
        }
    } catch (_) {}
    return null;
}

function callBoolMethod(object, selector) {
    const value = callObjectMethod(object, selector);
    if (value === null || value === undefined) {
        return "?";
    }
    try {
        return value ? "true" : "false";
    } catch (_) {
        return String(value);
    }
}

function callNumberMethod(object, selector) {
    const value = callObjectMethod(object, selector);
    if (value === null || value === undefined) {
        return "?";
    }
    try {
        return String(value);
    } catch (_) {
        return String(value);
    }
}

function stateString(selfValue) {
    let object;
    try {
        object = new ObjC.Object(selfValue);
    } catch (_) {
        return "self=" + pointerString(selfValue);
    }

    return (
        "mode=" +
        callObjectMethod(object, "currentEventMode") +
        " lockDown=" +
        callBoolMethod(object, "isLockButtonDown") +
        " menuDown=" +
        callBoolMethod(object, "isMenuButtonDown") +
        " consumed=" +
        callBoolMethod(object, "isButtonSequenceConsumed") +
        " lockPressCount=" +
        callNumberMethod(object, "lockPressCount") +
        " lockPressGeneration=" +
        callNumberMethod(object, "lockPressGeneration") +
        " lockHoldGeneration=" +
        callNumberMethod(object, "lockHoldGeneration") +
        " lockShortHoldRecognized=" +
        callBoolMethod(object, "lockShortHoldRecognized")
    );
}

function describeHIDEvent(event) {
    if (!IOHIDEventGetType || !IOHIDEventGetIntegerValue || !event || event.isNull()) {
        return null;
    }

    try {
        const type = IOHIDEventGetType(event);
        const usagePage = IOHIDEventGetIntegerValue(event, kIOHIDEventFieldKeyboardUsagePage);
        const usage = IOHIDEventGetIntegerValue(event, kIOHIDEventFieldKeyboardUsage);
        const down = IOHIDEventGetIntegerValue(event, kIOHIDEventFieldKeyboardDown) !== 0;
        const senderID = IOHIDEventGetSenderID ? IOHIDEventGetSenderID(event) : null;
        return {
            type: type,
            usagePage: usagePage,
            usage: usage,
            down: down,
            senderID: senderID,
        };
    } catch (error) {
        log("failed to decode HID event " + pointerString(event) + ": " + error);
        return null;
    }
}

function noteHIDEvent(label, event) {
    const hid = describeHIDEvent(event);
    if (!hid || hid.type !== kIOHIDEventTypeKeyboard || hid.usagePage !== kHIDPageConsumer ||
        hid.usage !== kHIDUsageConsumerPower) {
        return;
    }

    const sender = hid.senderID === null ? "" : " senderID=0x" + hid.senderID.toString(16);
    log(
        "HID " +
            label +
            " power down=" +
            hid.down +
            " page=0x" +
            hid.usagePage.toString(16) +
            " usage=0x" +
            hid.usage.toString(16) +
            sender
    );
}

function attachObjCMethod(className, selector, label, callbacks) {
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
    Interceptor.attach(implementation, callbacks);
    log("attached " + label);
    return true;
}

function attachSpringBoardHIDHooks() {
    attachObjCMethod("SpringBoard", "- __handleHIDEvent:withUIEvent:", "SpringBoard -__handleHIDEvent:withUIEvent:", {
        onEnter(args) {
            noteHIDEvent("-__handleHIDEvent:withUIEvent:", args[2]);
        },
    });

    attachObjCMethod("SpringBoard", "- __handleHIDEvent:", "SpringBoard -__handleHIDEvent:", {
        onEnter(args) {
            noteHIDEvent("-__handleHIDEvent:", args[2]);
        },
    });
}

function attachStateMethod(selector, label, options) {
    attachObjCMethod("LATButtonEventSource", selector, label, {
        onEnter(args) {
            this.selfValue = args[0];
            let extra = "";
            if (options && options.onEnterExtra) {
                extra = " " + options.onEnterExtra(args);
            }
            log(label + " enter" + extra + " " + stateString(args[0]));
        },
        onLeave(retval) {
            let extra = "";
            if (options && options.onLeaveExtra) {
                extra = " " + options.onLeaveExtra(retval);
            }
            log(label + " leave" + extra + " " + stateString(this.selfValue));
        },
    });
}

function attachButtonEventSourceHooks() {
    attachStateMethod("- handleLockButtonDown:", "handleLockButtonDown:", {
        onEnterExtra(args) {
            return "keyDown=" + boolFromArg(args[2]);
        },
    });
    attachStateMethod("- noteLockPressRelease", "noteLockPressRelease");
    attachStateMethod("- cancelLockPressRecognition", "cancelLockPressRecognition");
    attachStateMethod("- scheduleLockPressResolutionForPressCount:", "scheduleLockPressResolutionForPressCount:", {
        onEnterExtra(args) {
            return "pressCount=" + args[2].toUInt32();
        },
    });
    attachStateMethod("- resolveLockPressSequenceWithPressCount:generation:", "resolveLockPressSequenceWithPressCount:generation:", {
        onEnterExtra(args) {
            return "pressCount=" + args[2].toUInt32() + " generation=" + args[3].toUInt32();
        },
    });
    attachStateMethod("- shouldRecognizeLockPressSequence", "shouldRecognizeLockPressSequence", {
        onLeaveExtra(retval) {
            return "retval=" + boolFromArg(retval);
        },
    });
    attachStateMethod("- hasAssignedListenerForEventName:", "hasAssignedListenerForEventName:", {
        onEnterExtra(args) {
            return "eventName=" + stringFromObjC(args[2]);
        },
        onLeaveExtra(retval) {
            return "retval=" + boolFromArg(retval);
        },
    });
    attachStateMethod("- sendButtonEventWithName:", "sendButtonEventWithName:", {
        onEnterExtra(args) {
            return "eventName=" + stringFromObjC(args[2]);
        },
        onLeaveExtra(retval) {
            if (!retval || retval.isNull()) {
                return "event=nil";
            }
            try {
                const event = new ObjC.Object(retval);
                return "event=" + event.name() + " handled=" + event.handled();
            } catch (_) {
                return "event=" + pointerString(retval);
            }
        },
    });
}

attachSpringBoardHIDHooks();
attachButtonEventSourceHooks();

log("ready; run lock double/triple button checks now");

setInterval(function () {}, 1000);
