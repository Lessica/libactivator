// Usage:
//   frida -U SpringBoard -l scripts/probes/watch-frontmost-transitions-frida.js
//
// Purpose:
//   Observe SpringBoard transition hooks that may indicate frontmost application
//   changes. UI and SpringBoard state queries are always scheduled onto the
//   SpringBoard main queue.
//
// Notes:
//   Keep the Frida session interactive. Do not pass -q.
//   This is a diagnostic probe, not a test.

"use strict";

if (!ObjC.available) {
    throw new Error("Objective-C runtime is unavailable");
}

function now() {
    const date = new Date();
    return (
        date.toTimeString().split(" ")[0] +
        "." +
        String(date.getMilliseconds()).padStart(3, "0")
    );
}

function pointerDescription(value) {
    if (value === null || value === undefined) {
        return "nil";
    }
    return value.toString();
}

function objectFromValue(value) {
    if (value === null || value === undefined) {
        return null;
    }
    if (value.handle && value.handle.isNull()) {
        return null;
    }
    if (value.isNull && value.isNull()) {
        return null;
    }
    if (value.handle) {
        return value;
    }
    return ObjC.Object(value);
}

function callObjectMethod(object, selector) {
    if (!object || !object[selector]) {
        return null;
    }
    return object[selector]();
}

function stringFromObjectMethod(object, selector) {
    try {
        const value = callObjectMethod(object, selector);
        if (value === null || value === undefined) {
            return "";
        }
        return value.toString();
    } catch (_) {
        return "";
    }
}

function frontmostBundleIdentifierOnMainQueue() {
    try {
        const application = ObjC.classes.UIApplication["+ sharedApplication"]();
        const frontmost = objectFromValue(callObjectMethod(application, "- _accessibilityFrontMostApplication"));
        if (!frontmost) {
            return "";
        }

        return (
            stringFromObjectMethod(frontmost, "- bundleIdentifier") ||
            stringFromObjectMethod(frontmost, "- displayIdentifier") ||
            frontmost.toString()
        );
    } catch (error) {
        return "error:" + error;
    }
}

function sampleFrontmost(label, suffix) {
    ObjC.schedule(ObjC.mainQueue, function () {
        console.log(
            "[frontmost-probe] " +
                now() +
                " " +
                label +
                suffix +
                " frontMost=" +
                frontmostBundleIdentifierOnMainQueue()
        );
    });
}

function sampleFrontmostSeries(label) {
    sampleFrontmost(label, " main");
    [100, 300, 600, 1000].forEach(function (delay) {
        setTimeout(function () {
            sampleFrontmost(label, " +" + delay + "ms");
        }, delay);
    });
}

function attachHook(className, selector, label, options) {
    const klass = ObjC.classes[className];
    if (!klass || !klass[selector] || !klass[selector].implementation) {
        console.log("[frontmost-probe] missing " + label + " " + selector);
        return;
    }

    const logEnter = !options || options.enter !== false;
    const logLeave = options && options.leave === true;

    Interceptor.attach(klass[selector].implementation, {
        onEnter(args) {
            if (logEnter) {
                console.log(
                    "[frontmost-probe] " +
                        now() +
                        " enter " +
                        label +
                        " arg0=" +
                        pointerDescription(args[2])
                );
                sampleFrontmostSeries(label + " enter");
            }
        },
        onLeave() {
            if (logLeave) {
                console.log("[frontmost-probe] " + now() + " leave " + label);
                sampleFrontmostSeries(label + " leave");
            }
        },
    });

    console.log("[frontmost-probe] attached " + label);
}

attachHook(
    "SBMainSwitcherViewController",
    "- layoutStateTransitionCoordinator:transitionDidBeginWithTransitionContext:",
    "SBMainSwitcherViewController layout transition begin",
    {}
);
attachHook(
    "SBMainSwitcherViewController",
    "- layoutStateTransitionCoordinator:transitionDidEndWithTransitionContext:",
    "SBMainSwitcherViewController layout transition end",
    {}
);
attachHook(
    "SBMainSwitcherControllerCoordinator",
    "- layoutStateTransitionCoordinator:transitionDidBeginWithTransitionContext:",
    "SBMainSwitcherControllerCoordinator layout transition begin",
    {}
);
attachHook(
    "SBMainSwitcherControllerCoordinator",
    "- layoutStateTransitionCoordinator:transitionDidEndWithTransitionContext:",
    "SBMainSwitcherControllerCoordinator layout transition end",
    {}
);

sampleFrontmost("ready", "");
console.log("[frontmost-probe] ready");

setInterval(function () {}, 1000);
