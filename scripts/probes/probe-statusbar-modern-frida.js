// Usage:
//   .venv/bin/frida -U SpringBoard -l scripts/probes/probe-statusbar-modern-frida.js
//   frida -U SpringBoard -l scripts/probes/probe-statusbar-modern-frida.js
//
// Purpose:
//   Observe modern status bar touch delivery and Activator status bar event
//   recognition without changing behavior. Use this to diagnose foreground-app
//   status bar tap / double-tap failures while preserving scroll-to-top.
//
// Notes:
//   Keep the Frida session interactive. Do not pass -q.
//   This is a diagnostic probe, not a test.

"use strict";

if (!ObjC.available) {
    throw new Error("Objective-C runtime is unavailable");
}

const probeName = "[statusbar-modern-probe]";
const startedAt = Date.now();
const hookedImplementations = {};

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

function pointerString(value) {
    if (value === null || value === undefined) {
        return "nil";
    }
    return value.toString();
}

function objectFromPointer(value) {
    if (!value || value.isNull()) {
        return null;
    }
    try {
        return new ObjC.Object(value);
    } catch (_) {
        return null;
    }
}

function safeString(value) {
    if (value === null || value === undefined) {
        return "nil";
    }
    try {
        if (typeof value === "string") {
            return value;
        }
        return String(value);
    } catch (_) {
        return "<error>";
    }
}

function objcString(value) {
    const object = objectFromPointer(value);
    if (!object) {
        return pointerString(value);
    }
    try {
        return object.toString();
    } catch (_) {
        return pointerString(value);
    }
}

function className(value) {
    const object = objectFromPointer(value);
    if (!object) {
        return "nil";
    }
    try {
        return object.$className;
    } catch (_) {
        return "unknown";
    }
}

function callObject(object, selector) {
    try {
        if (object && object[selector]) {
            return object[selector]();
        }
    } catch (_) {}
    return null;
}

function callNumber(object, selector) {
    try {
        const value = callObject(object, selector);
        if (value === null || value === undefined) {
            return null;
        }
        if (typeof value === "number") {
            return value;
        }
        if (value.toString) {
            return Number(value.toString());
        }
    } catch (_) {}
    return null;
}

function numberFromField(value, names, index) {
    if (value === null || value === undefined) {
        return null;
    }
    for (const name of names) {
        try {
            const field = value[name];
            if (typeof field === "number") {
                return field;
            }
            if (field !== null && field !== undefined && field.toString) {
                const parsed = Number(field.toString());
                if (!Number.isNaN(parsed)) {
                    return parsed;
                }
            }
        } catch (_) {}
    }
    try {
        const field = value[index];
        if (typeof field === "number") {
            return field;
        }
        if (field !== null && field !== undefined && field.toString) {
            const parsed = Number(field.toString());
            if (!Number.isNaN(parsed)) {
                return parsed;
            }
        }
    } catch (_) {}
    return null;
}

function formatNumber(value) {
    return value === null || value === undefined ? "?" : value.toFixed(1);
}

function pointString(point) {
    const x = numberFromField(point, ["x"], 0);
    const y = numberFromField(point, ["y"], 1);
    return "(" + formatNumber(x) + "," + formatNumber(y) + ")";
}

function rectString(view) {
    try {
        const bounds = view.bounds();
        const origin = bounds.origin || bounds[0] || {};
        const size = bounds.size || bounds[1] || {};
        const x = numberFromField(origin, ["x"], 0);
        const y = numberFromField(origin, ["y"], 1);
        const width = numberFromField(size, ["width"], 0);
        const height = numberFromField(size, ["height"], 1);
        return (
            "bounds={{" +
            formatNumber(x) +
            "," +
            formatNumber(y) +
            "},{" +
            formatNumber(width) +
            "," +
            formatNumber(height) +
            "}}"
        );
    } catch (_) {
        return "bounds=?";
    }
}

function touchSummary(touchesValue, viewValue) {
    const touches = objectFromPointer(touchesValue);
    const view = objectFromPointer(viewValue);
    if (!touches || !view) {
        return "touch=nil";
    }

    let touch = null;
    try {
        touch = touches.anyObject();
    } catch (_) {}
    if (!touch) {
        return "touch=nil count=?";
    }

    try {
        const point = touch.locationInView_(view);
        const previous = touch.previousLocationInView_(view);
        const tapCount = callNumber(touch, "tapCount");
        const phase = callNumber(touch, "phase");
        return (
            "touch=" +
            pointerString(touch.handle) +
            " tapCount=" +
            safeString(tapCount) +
            " phase=" +
            safeString(phase) +
            " location=(" +
            pointString(point).slice(1, -1) +
            ") previous=" +
            pointString(previous)
        );
    } catch (error) {
        return "touch=" + pointerString(touch.handle) + " summaryError=" + error;
    }
}

function recognizerSummary(viewValue) {
    const view = objectFromPointer(viewValue);
    if (!view) {
        return "recognizers=nil";
    }
    let recognizers = null;
    try {
        recognizers = view.gestureRecognizers();
    } catch (_) {}
    if (!recognizers || recognizers.isNull()) {
        return "recognizers=[]";
    }

    const parts = [];
    try {
        const count = Number(recognizers.count().toString());
        for (let i = 0; i < count && i < 12; i++) {
            const recognizer = recognizers.objectAtIndex_(i);
            const state = callNumber(recognizer, "state");
            parts.push(recognizer.$className + "@" + pointerString(recognizer.handle) + "#state=" + state);
        }
        if (count > 12) {
            parts.push("+" + String(count - 12) + " more");
        }
    } catch (error) {
        parts.push("error=" + error);
    }
    return "recognizers=[" + parts.join(", ") + "]";
}

function attachObjCMethod(classNameToHook, selector, label, callbacks) {
    const klass = ObjC.classes[classNameToHook];
    if (!klass || !klass[selector] || !klass[selector].implementation) {
        log("missing " + classNameToHook + " " + selector);
        return false;
    }

    const key = classNameToHook + " " + selector;
    const implementation = klass[selector].implementation;
    const implementationKey = implementation.toString();
    if (hookedImplementations[implementationKey]) {
        log("already hooked " + key + " shares implementation with " + hookedImplementations[implementationKey]);
        return false;
    }
    hookedImplementations[implementationKey] = key;

    Interceptor.attach(implementation, {
        onEnter(args) {
            try {
                this.selfValue = args[0];
                if (callbacks && callbacks.onEnter) {
                    callbacks.onEnter.call(this, args);
                } else {
                    log(label + " enter self=" + pointerString(args[0]));
                }
            } catch (error) {
                log(label + " enter error: " + error);
            }
        },
        onLeave(retval) {
            try {
                if (callbacks && callbacks.onLeave) {
                    callbacks.onLeave.call(this, retval);
                }
            } catch (error) {
                log(label + " leave error: " + error);
            }
        },
    });

    log("hooked " + key + " => " + implementation);
    return true;
}

function noteStatusBarTouch(label, args) {
    const view = objectFromPointer(args[0]);
    const receiverClassName = className(args[0]);
    if (receiverClassName.indexOf("StatusBar") === -1) {
        return;
    }
    log(
        label +
            " self=" +
            pointerString(args[0]) +
            " class=" +
            receiverClassName +
            " window=" +
            pointerString(callObject(view, "window") ? callObject(view, "window").handle : null) +
            " " +
            rectString(view) +
            " " +
            touchSummary(args[2], args[0]) +
            " " +
            recognizerSummary(args[0])
    );
}

function noteEventSourceTouch(label, args) {
    log(
        label +
            " source=" +
            pointerString(args[0]) +
            " view=" +
            pointerString(args[2]) +
            " viewClass=" +
            className(args[2]) +
            " " +
            touchSummary(args[3], args[2])
    );
}

function noteTestingPoint(label, args) {
    log(label + " source=" + pointerString(args[0]) + " view=" + pointerString(args[2]));
}

function noteSendEvent(args) {
    const name = objcString(args[2]);
    if (name.indexOf("libactivator.statusbar.") !== 0) {
        return;
    }
    log(
        "LATStatusBarEventSource sendEventWithName name=" +
            name +
            " source=" +
            pointerString(args[0]) +
            " view=" +
            pointerString(args[4])
    );
}

function noteActivatorDispatch(label, args) {
    const event = objectFromPointer(args[2]);
    if (!event) {
        return;
    }
    const name = callObject(event, "name");
    const mode = callObject(event, "mode");
    const nameText = safeString(name);
    if (nameText.indexOf("libactivator.statusbar.") !== 0) {
        return;
    }
    log(label + " event=" + nameText + " mode=" + safeString(mode) + " eventPtr=" + pointerString(args[2]));
}

function hookStatusBarClass(classNameToHook) {
    attachObjCMethod(classNameToHook, "- touchesBegan:withEvent:", classNameToHook + " touchesBegan", {
        onEnter(args) {
            noteStatusBarTouch(classNameToHook + " touchesBegan", args);
        },
    });
    attachObjCMethod(classNameToHook, "- touchesMoved:withEvent:", classNameToHook + " touchesMoved", {
        onEnter(args) {
            noteStatusBarTouch(classNameToHook + " touchesMoved", args);
        },
    });
    attachObjCMethod(classNameToHook, "- touchesEnded:withEvent:", classNameToHook + " touchesEnded", {
        onEnter(args) {
            noteStatusBarTouch(classNameToHook + " touchesEnded", args);
        },
    });
    attachObjCMethod(classNameToHook, "- touchesCancelled:withEvent:", classNameToHook + " touchesCancelled", {
        onEnter(args) {
            noteStatusBarTouch(classNameToHook + " touchesCancelled", args);
        },
    });
}

function hookOptionalSelector(classNameToHook, selector, label) {
    attachObjCMethod(classNameToHook, selector, label, {
        onEnter(args) {
            log(label + " self=" + pointerString(args[0]) + " class=" + className(args[0]));
        },
    });
}

hookStatusBarClass("UIStatusBar_Modern");
hookStatusBarClass("UIStatusBar");

attachObjCMethod(
    "LATStatusBarEventSource",
    "- noteStatusBarView:touchesBegan:withEvent:",
    "LATStatusBarEventSource note began",
    {
        onEnter(args) {
            noteEventSourceTouch("LATStatusBarEventSource note began", args);
        },
    }
);
attachObjCMethod(
    "LATStatusBarEventSource",
    "- noteStatusBarView:touchesMoved:withEvent:",
    "LATStatusBarEventSource note moved",
    {
        onEnter(args) {
            noteEventSourceTouch("LATStatusBarEventSource note moved", args);
        },
    }
);
attachObjCMethod(
    "LATStatusBarEventSource",
    "- noteStatusBarView:touchesEnded:withEvent:",
    "LATStatusBarEventSource note ended",
    {
        onEnter(args) {
            noteEventSourceTouch("LATStatusBarEventSource note ended", args);
        },
    }
);
attachObjCMethod(
    "LATStatusBarEventSource",
    "- noteStatusBarView:touchesCancelled:withEvent:",
    "LATStatusBarEventSource note cancelled",
    {
        onEnter(args) {
            log(
                "LATStatusBarEventSource note cancelled source=" +
                    pointerString(args[0]) +
                    " view=" +
                    pointerString(args[2]) +
                    " viewClass=" +
                    className(args[2])
            );
        },
    }
);
attachObjCMethod(
    "LATStatusBarEventSource",
    "- noteTouchEndedInStatusBarView:tapCount:",
    "LATStatusBarEventSource internal ended",
    {
        onEnter(args) {
            log(
                "LATStatusBarEventSource internal ended source=" +
                    pointerString(args[0]) +
                    " view=" +
                    pointerString(args[2]) +
                    " tapCount=" +
                    args[3].toString()
            );
        },
    }
);
attachObjCMethod(
    "LATStatusBarEventSource",
    "- sendEventWithName:statusBarView:session:",
    "LATStatusBarEventSource send event",
    {
        onEnter(args) {
            noteSendEvent(args);
        },
    }
);

attachObjCMethod("LAActivator", "- sendEventToListener:", "LAActivator sendEventToListener", {
    onEnter(args) {
        noteActivatorDispatch("LAActivator sendEventToListener", args);
    },
});
attachObjCMethod(
    "LAActivator",
    "- sendEvent:toListenersWithNames:",
    "LAActivator sendEvent:toListenersWithNames",
    {
        onEnter(args) {
            noteActivatorDispatch("LAActivator sendEvent:toListenersWithNames", args);
        },
    }
);

hookOptionalSelector("UIApplication", "- _statusBarScrollToTop", "UIApplication _statusBarScrollToTop");
hookOptionalSelector("UIApplication", "- _scrollToTopViewsUnderScreenPointIfNecessary:resultHandler:", "UIApplication scrollToTop screen point");
hookOptionalSelector("UIScrollView", "- _scrollToTopIfPossible:", "UIScrollView _scrollToTopIfPossible");
hookOptionalSelector("UIScrollView", "- _scrollToTopFromStatusBar", "UIScrollView _scrollToTopFromStatusBar");

log("ready. Interact with status bar tap/double in foreground app, then report back.");
