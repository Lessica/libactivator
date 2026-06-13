// Usage:
//   .venv-16/bin/frida -U SpringBoard -l scripts/probes/probe-button-hold-thresholds-frida.js
//   frida -U SpringBoard -l scripts/probes/probe-button-hold-thresholds-frida.js
//
// Purpose:
//   Measure Home/Menu and Power/Sleep hold thresholds on a real SpringBoard by
//   correlating HID down/up events with legacy SpringBoard button hooks and
//   modern Siri / power-down UI entry points.
//
// Notes:
//   Keep the Frida session interactive. Do not pass -q.
//   This is a diagnostic probe, not a test.

"use strict";

if (!ObjC.available) {
    throw new Error("Objective-C runtime is unavailable");
}

const probeName = "[button-hold-probe]";
const startedAt = Date.now();
const hookedImplementations = {};
const lastDownAt = {
    menu: null,
    power: null,
};

const kIOHIDEventTypeKeyboard = 3;
const kIOHIDEventFieldKeyboardUsagePage = kIOHIDEventTypeKeyboard << 16;
const kIOHIDEventFieldKeyboardUsage = kIOHIDEventFieldKeyboardUsagePage + 1;
const kIOHIDEventFieldKeyboardDown = kIOHIDEventFieldKeyboardUsagePage + 2;
const kHIDPageConsumer = 0x0c;
const kHIDUsageConsumerPower = 0x30;
const kHIDUsageConsumerMenu = 0x40;
const kHIDUsageConsumerVolumeIncrement = 0xe9;
const kHIDUsageConsumerVolumeDecrement = 0xea;

function nowMillis() {
    return Date.now();
}

function now() {
    const date = new Date();
    return (
        date.toTimeString().split(" ")[0] +
        "." +
        String(date.getMilliseconds()).padStart(3, "0")
    );
}

function elapsed() {
    return "+" + String(nowMillis() - startedAt).padStart(6, " ") + "ms";
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

function usageName(usage) {
    switch (usage) {
    case kHIDUsageConsumerPower:
        return "power";
    case kHIDUsageConsumerMenu:
        return "menu";
    case kHIDUsageConsumerVolumeIncrement:
        return "volume-up";
    case kHIDUsageConsumerVolumeDecrement:
        return "volume-down";
    default:
        return "usage-0x" + usage.toString(16);
    }
}

function maybePointer(value) {
    if (value === null || value === undefined) {
        return "nil";
    }
    return value.toString();
}

function boolFromPointer(value) {
    try {
        return value.toInt32() !== 0;
    } catch (_) {
        return false;
    }
}

function deltaString(from) {
    if (from === null) {
        return "n/a";
    }
    return String(nowMillis() - from) + "ms";
}

function noteHardwareButtonEdge(className, selector, args) {
    if (/SBHomeHardwareButton/.test(className)) {
        if (selector === "- initialButtonDown:") {
            lastDownAt.menu = nowMillis();
            log("hardware menu down=true " + eventDeltaString());
        } else if (selector === "- initialButtonUp:") {
            log("hardware menu down=false " + eventDeltaString());
        }
        return;
    }

    if (selector !== "- _reportAggdLoggingForButtonEventIsDownEvent:") {
        return;
    }

    let key = null;
    if (/SBLockHardwareButton/.test(className)) {
        key = "power";
    }

    if (!key) {
        return;
    }

    const down = boolFromPointer(args[2]);
    if (down) {
        lastDownAt[key] = nowMillis();
    }
    log("hardware " + key + " down=" + down + " " + eventDeltaString());
}

function eventDeltaString() {
    return "menuDownDelta=" + deltaString(lastDownAt.menu) + " powerDownDelta=" + deltaString(lastDownAt.power);
}

function describeHIDEvent(event) {
    if (!IOHIDEventGetType || !IOHIDEventGetIntegerValue || event.isNull()) {
        return null;
    }

    let type;
    let usagePage;
    let usage;
    let down;
    let senderID = null;
    try {
        type = IOHIDEventGetType(event);
        usagePage = IOHIDEventGetIntegerValue(event, kIOHIDEventFieldKeyboardUsagePage);
        usage = IOHIDEventGetIntegerValue(event, kIOHIDEventFieldKeyboardUsage);
        down = IOHIDEventGetIntegerValue(event, kIOHIDEventFieldKeyboardDown) !== 0;
        if (IOHIDEventGetSenderID) {
            senderID = IOHIDEventGetSenderID(event);
        }
    } catch (error) {
        log("failed to decode HID event " + maybePointer(event) + ": " + error);
        return null;
    }

    return {
        type: type,
        usagePage: usagePage,
        usage: usage,
        down: down,
        senderID: senderID,
    };
}

function noteHIDEvent(label, event) {
    const hid = describeHIDEvent(event);
    if (!hid) {
        return;
    }

    if (hid.type !== kIOHIDEventTypeKeyboard || hid.usagePage !== kHIDPageConsumer) {
        return;
    }

    const name = usageName(hid.usage);
    if (name === "menu" || name === "power") {
        if (hid.down) {
            lastDownAt[name] = nowMillis();
        }
        const sender = hid.senderID === null ? "" : " senderID=0x" + hid.senderID.toString(16);
        log(
            "HID " +
                label +
                " " +
                name +
                " down=" +
                hid.down +
                " page=0x" +
                hid.usagePage.toString(16) +
                " usage=0x" +
                hid.usage.toString(16) +
                sender +
                " " +
                eventDeltaString()
        );
    }
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

function attachLegacyButtonHooks() {
    [
        ["SpringBoard", "- menuButtonDown:", "legacy menuButtonDown"],
        ["SpringBoard", "- menuButtonUp:", "legacy menuButtonUp"],
        ["SpringBoard", "- menuButtonWasHeld", "legacy menuButtonWasHeld"],
        ["SpringBoard", "- _menuButtonWasHeld", "legacy _menuButtonWasHeld"],
        ["SpringBoard", "- activatorMenuButtonTimerCompleted", "legacy activatorMenuButtonTimerCompleted"],
        ["SpringBoard", "- lockButtonDown:", "legacy lockButtonDown"],
        ["SpringBoard", "- lockButtonUp:", "legacy lockButtonUp"],
        ["SpringBoard", "- lockButtonWasHeld", "legacy lockButtonWasHeld"],
        ["SpringBoard", "- activatorLockButtonHoldCompleted", "legacy activatorLockButtonHoldCompleted"],
    ].forEach(function (entry) {
        attachObjCMethod(entry[0], entry[1], entry[2], {
            onEnter() {
                log(entry[2] + " enter " + eventDeltaString());
            },
            onLeave() {
                log(entry[2] + " leave " + eventDeltaString());
            },
        });
    });
}

function methodListForClass(klass) {
    if (!klass) {
        return [];
    }

    const methods = [];
    if (klass.$ownMethods) {
        methods.push.apply(methods, klass.$ownMethods);
    }

    const seen = {};
    return methods.filter(function (method) {
        if (seen[method]) {
            return false;
        }
        seen[method] = true;
        return true;
    });
}

function attachMatchingMethodsForClasses(classNames, selectorPattern, label, maxHooks) {
    let count = 0;
    classNames.forEach(function (className) {
            const klass = ObjC.classes[className];
            if (!klass) {
                log("missing class " + className);
                return;
            }
            methodListForClass(klass)
                .filter(function (selector) {
                    return selectorPattern.test(selector);
                })
                .sort()
                .forEach(function (selector) {
                    if (count >= maxHooks) {
                        return;
                    }
                    const attached = attachObjCMethod(className, selector, label + " " + className + " " + selector, {
                        onEnter(args) {
                            noteHardwareButtonEdge(className, selector, args);
                            log(
                                label +
                                    " enter " +
                                    className +
                                    " " +
                                    selector +
                                    " arg0=" +
                                    maybePointer(args[2]) +
                                    " " +
                                    eventDeltaString()
                            );
                        },
                        onLeave(retval) {
                            log(label + " leave " + className + " " + selector + " retval=" + maybePointer(retval) + " " + eventDeltaString());
                        },
                    });
                    if (attached) {
                        count += 1;
                    }
                });
        });
    log("attached " + count + " " + label + " matching hooks");
}

function printMatchingMethodsForClasses(classNames, selectorPattern, label, maxLines) {
    let count = 0;
    log("matching methods for " + label);
    classNames.forEach(function (className) {
            if (!ObjC.classes[className]) {
                log("  missing class " + className);
                return;
            }
            methodListForClass(ObjC.classes[className])
                .filter(function (selector) {
                    return selectorPattern.test(selector);
                })
                .sort()
                .forEach(function (selector) {
                    if (count < maxLines) {
                        log("  " + className + " " + selector);
                    }
                    count += 1;
                });
        });
    if (count > maxLines) {
        log("  ... " + (count - maxLines) + " more");
    }
    log("matched " + count + " methods for " + label);
}

attachSpringBoardHIDHooks();
attachLegacyButtonHooks();

const homeClasses = [
    "SBHomeHardwareButton",
    "SBHomeHardwareButtonActions",
    "SBHomeButtonPressMesaUnlockTrigger",
    "SBHomeButtonPressSpeedMesaUnlockTrigger",
    "AXSBHomeHardwareButtonActions",
];

const assistantClasses = [
    "SBAssistantController",
    "SBAssistantRootViewController",
    "SBAssistantSessionController",
    "SBAssistantWindow",
    "SBVoiceControlController",
];

const powerDownClasses = [
    "SBPowerDownController",
    "SBPowerDownViewController",
    "SBLockHardwareButton",
    "SBLockHardwareButtonActions",
    "SBSOSClawGestureObserver",
    "SBSOSLockGestureObserver",
];

printMatchingMethodsForClasses(homeClasses, /(home|menu|button|press|hold|held|long|down|up|report|siri|assistant|voice)/i, "home/menu", 80);
printMatchingMethodsForClasses(assistantClasses, /(activate|assistant|siri|voice|show|present|button|hold|press)/i, "assistant/siri", 60);
printMatchingMethodsForClasses(powerDownClasses, /(present|show|power|shutdown|sos|hold|held|button|long|activate|order)/i, "power-down", 60);

attachMatchingMethodsForClasses(homeClasses, /(home|menu|button|press|hold|held|long|down|up|report|siri|assistant|voice)/i, "home/menu", 50);
attachMatchingMethodsForClasses(assistantClasses, /(activate|assistant|siri|voice|show|present|button|hold|press)/i, "assistant/siri", 40);
attachMatchingMethodsForClasses(powerDownClasses, /(present|show|power|shutdown|sos|hold|held|button|long|activate|order)/i, "power-down", 40);

log("ready; press and hold Home/Menu until Siri appears, then press and hold Power/Sleep until the power-off UI appears");

setInterval(function () {}, 1000);
