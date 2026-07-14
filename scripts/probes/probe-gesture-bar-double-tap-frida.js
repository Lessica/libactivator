// Usage:
//   .venv/bin/frida -U -n SpringBoard -l scripts/probes/probe-gesture-bar-double-tap-frida.js
//
// Purpose:
//   Inspect the modern gesture-bar double-tap recognizer owned by
//   SBHomeGrabberRevealGesturesManager. Double-tap the gesture bar while this
//   probe runs.
//
// Notes:
//   Keep the Frida session interactive. Do not pass -q.
//   This probe does not add recognizers, targets, or alter recognizer state.

"use strict";

if (!ObjC.available) {
    throw new Error("Objective-C runtime is unavailable");
}

const probeName = "[gesture-bar-double-tap-probe]";
const managerClassName = "SBHomeGrabberRevealGesturesManager";
const managerClass = ObjC.classes[managerClassName];
const recognizerHandles = new Set();
const hookedImplementations = new Set();
let transitionCount = 0;
let touchCount = 0;

function log(message) {
    console.log(probeName + " " + message);
}

function objectFromValue(value) {
    if (!value) {
        return null;
    }
    try {
        if (value.isNull && value.isNull()) {
            return null;
        }
        return value.$className ? value : new ObjC.Object(value);
    } catch (_) {
        return null;
    }
}

function callObject(object, selector) {
    try {
        if (!object || !object[selector]) {
            return null;
        }
        return objectFromValue(object[selector]());
    } catch (_) {
        return null;
    }
}

function callNumber(object, selector) {
    try {
        if (!object || !object[selector]) {
            return null;
        }
        return Number(object[selector]());
    } catch (_) {
        return null;
    }
}

function callBoolean(object, selector) {
    const value = callNumber(object, selector);
    return value === null ? "?" : value === 0 ? "NO" : "YES";
}

function fieldNumber(value, fieldName, fallbackIndex) {
    try {
        if (value[fieldName] !== undefined) {
            return Number(value[fieldName]);
        }
    } catch (_) {}
    try {
        return Number(value[fallbackIndex]);
    } catch (_) {
        return NaN;
    }
}

function pointSummary(point) {
    return "(" + fieldNumber(point, "x", 0).toFixed(1) + "," + fieldNumber(point, "y", 1).toFixed(1) + ")";
}

function sizeSummary(size) {
    return fieldNumber(size, "width", 0).toFixed(1) + "x" + fieldNumber(size, "height", 1).toFixed(1);
}

function recognizerFromManager(manager) {
    try {
        const value = manager.$ivars._revealDoubleTapRecognizer;
        return objectFromValue(value);
    } catch (_) {
        return null;
    }
}

function recognizerIsTracked(recognizer) {
    return recognizer && recognizerHandles.has(recognizer.handle.toString());
}

function recognizerGeometry(recognizer) {
    const view = callObject(recognizer, "- view");
    if (!view) {
        return "view=nil";
    }

    let result = "view=" + view.$className + "@" + view.handle;
    try {
        const bounds = view.bounds();
        result += " bounds=" + sizeSummary(bounds.size || bounds[1]);
    } catch (_) {}
    try {
        const location = recognizer.locationInView_(view);
        const bounds = view.bounds();
        const height = fieldNumber(bounds.size || bounds[1], "height", 1);
        const y = fieldNumber(location, "y", 1);
        result += " location=" + pointSummary(location) + " bottomDistance=" + (height - y).toFixed(1);
    } catch (_) {}
    return result;
}

function trackRecognizer(recognizer, reason) {
    if (!recognizer) {
        log(reason + " recognizer=nil");
        return;
    }

    recognizerHandles.add(recognizer.handle.toString());
    log(
        reason +
            " recognizer=" +
            recognizer.$className +
            "@" +
            recognizer.handle +
            " state=" +
            callNumber(recognizer, "- state") +
            " enabled=" +
            callBoolean(recognizer, "- isEnabled") +
            " taps=" +
            callNumber(recognizer, "- numberOfTapsRequired") +
            " touches=" +
            callNumber(recognizer, "- numberOfTouchesRequired") +
            " cancels=" +
            callBoolean(recognizer, "- cancelsTouchesInView") +
            " delaysBegan=" +
            callBoolean(recognizer, "- delaysTouchesBegan") +
            " delaysEnded=" +
            callBoolean(recognizer, "- delaysTouchesEnded") +
            " " +
            recognizerGeometry(recognizer)
    );
}

function inspectManager(manager, reason) {
    log(reason + " manager=" + manager.$className + "@" + manager.handle);
    trackRecognizer(recognizerFromManager(manager), reason);
}

function attachImplementation(method, label, callbacks) {
    if (!method) {
        log("missing " + label);
        return;
    }
    const key = method.implementation.toString();
    if (hookedImplementations.has(key)) {
        return;
    }
    hookedImplementations.add(key);
    Interceptor.attach(method.implementation, callbacks);
    log("attached " + label);
}

function attachManagerInitialization() {
    attachImplementation(managerClass["- init"], managerClassName + " -init", {
        onLeave(retval) {
            const manager = objectFromValue(retval);
            if (!manager || !manager.isKindOfClass_(managerClass)) {
                return;
            }
            ObjC.schedule(ObjC.mainQueue, function () {
                inspectManager(manager, "initialized");
            });
        },
    });
}

function attachRecognizerStateTransitions() {
    for (const selector of ["- setState:", "- _setState:"]) {
        const method = ObjC.classes.UIGestureRecognizer[selector];
        attachImplementation(method, "UIGestureRecognizer " + selector, {
            onEnter(args) {
                const recognizer = objectFromValue(args[0]);
                if (!recognizerIsTracked(recognizer)) {
                    return;
                }
                transitionCount += 1;
                log(
                    "state recognizer=" +
                        recognizer.$className +
                        " old=" +
                        callNumber(recognizer, "- state") +
                        " new=" +
                        args[2].toInt32() +
                        " " +
                        recognizerGeometry(recognizer)
                );
            },
        });
    }
}

function attachRecognizerTouches() {
    for (const selector of [
        "- touchesBegan:withEvent:",
        "- touchesMoved:withEvent:",
        "- touchesEnded:withEvent:",
        "- touchesCancelled:withEvent:",
    ]) {
        const method = ObjC.classes.UITapGestureRecognizer[selector];
        attachImplementation(method, "UITapGestureRecognizer " + selector, {
            onEnter(args) {
                const recognizer = objectFromValue(args[0]);
                if (!recognizerIsTracked(recognizer)) {
                    return;
                }

                touchCount += 1;
                const touches = objectFromValue(args[2]);
                const touch = touches ? callObject(touches, "- anyObject") : null;
                const view = callObject(recognizer, "- view");
                let touchDetails = "touch=nil";
                if (touch && view) {
                    try {
                        touchDetails =
                            "phase=" +
                            callNumber(touch, "- phase") +
                            " tapCount=" +
                            callNumber(touch, "- tapCount") +
                            " location=" +
                            pointSummary(touch.locationInView_(view));
                    } catch (_) {}
                }
                log(selector + " " + touchDetails + " " + recognizerGeometry(recognizer));
            },
        });
    }
}

function printClassContract() {
    log("class=" + managerClassName);
    log("own ivars:");
    Object.keys(managerClass.$ivars)
        .sort()
        .forEach(function (name) {
            log("  " + name + " : " + managerClass.$ivars[name].type);
        });
    log("matching methods:");
    managerClass.$methods
        .filter(function (name) {
            return /init|reveal|double|gesture|grabber/i.test(name);
        })
        .sort()
        .forEach(function (name) {
            log("  " + name);
        });
}

if (!managerClass) {
    log(managerClassName + " is unavailable");
    log("related classes:");
    Object.keys(ObjC.classes)
        .filter(function (name) {
            return /Home.*Grabber|Grabber.*Gesture|Home.*Indicator/i.test(name);
        })
        .sort()
        .forEach(function (name) {
            log("  " + name);
        });
    throw new Error(managerClassName + " is unavailable");
}

printClassContract();
attachManagerInitialization();
attachRecognizerStateTransitions();
attachRecognizerTouches();

ObjC.schedule(ObjC.mainQueue, function () {
    let count = 0;
    ObjC.choose(managerClass, {
        onMatch(instance) {
            count += 1;
            inspectManager(objectFromValue(instance), "existing");
        },
        onComplete() {
            log("live managers=" + count);
            log("ready: double-tap the gesture bar several times");
        },
    });
});

setTimeout(function () {
    log("observation window ended transitions=" + transitionCount + " touches=" + touchCount);
    send({ event: "done", transitions: transitionCount, touches: touchCount });
}, 90000);
