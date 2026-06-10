// Usage:
//   frida -U SpringBoard -l scripts/discover-volume-control-instances-frida.js
//
// Purpose:
//   Find live SBVolumeControl instances and inspect read-only state useful for
//   deciding whether _presentVolumeHUDWithVolume: can back Activator's
//   libactivator.audio.show-volume-bar action.
//
// Notes:
//   Keep the Frida session interactive. Do not pass -q.
//   This script does not invoke presentation or mutation selectors.

"use strict";

if (!ObjC.available) {
    throw new Error("Objective-C runtime is unavailable");
}

function describe(value) {
    if (value === null || value === undefined) {
        return "nil";
    }
    try {
        if (value.isNull && value.isNull()) {
            return "nil";
        }
        return new ObjC.Object(value).toString();
    } catch (error) {
        return value.toString ? value.toString() : "error:" + error;
    }
}

function boolResult(object, selector) {
    try {
        if (!object[selector]) {
            return "<missing>";
        }
        return object[selector]() ? "YES" : "NO";
    } catch (error) {
        return "error:" + error;
    }
}

function floatResult(object, selector) {
    try {
        if (!object[selector]) {
            return "<missing>";
        }
        return String(object[selector]());
    } catch (error) {
        return "error:" + error;
    }
}

function objectResult(object, selector) {
    try {
        if (!object[selector]) {
            return "<missing>";
        }
        return describe(object[selector]());
    } catch (error) {
        return "error:" + error;
    }
}

function dumpClass(className) {
    const klass = ObjC.classes[className];
    if (!klass) {
        console.log("[volume-instance] " + className + " unavailable");
        return;
    }

    console.log("[volume-instance] " + className + " class methods");
    klass.$ownMethods
        .filter(function (method) {
            return method[0] === "+";
        })
        .sort()
        .forEach(function (method) {
            console.log("  " + method);
        });

    console.log("[volume-instance] " + className + " ivars");
    Object.keys(klass.$ivars)
        .sort()
        .forEach(function (ivar) {
            console.log("  " + ivar + " : " + klass.$ivars[ivar].type);
        });
}

function inspectInstance(instance, index) {
    const object = new ObjC.Object(instance);
    console.log("[volume-instance] SBVolumeControl instance[" + index + "] " + object);
    [
        "- _effectiveVolume",
        "- _isVolumeHUDVisible",
        "- presentedVolumeHUDViewController",
        "- existingVolumeHUDViewController",
        "- elasticVolumeViewControllerActiveAudioCategory",
    ].forEach(function (selector) {
        const value = selector.indexOf("Volume") >= 0 && selector.indexOf("ViewController") < 0
            ? selector.indexOf("Visible") >= 0
              ? boolResult(object, selector)
              : floatResult(object, selector)
            : objectResult(object, selector);
        console.log("[volume-instance]   " + selector + " => " + value);
    });
}

ObjC.schedule(ObjC.mainQueue, function () {
    dumpClass("SBVolumeControl");

    let count = 0;
    ObjC.choose(ObjC.classes.SBVolumeControl, {
        onMatch(instance) {
            inspectInstance(instance, count);
            count += 1;
        },
        onComplete() {
            console.log("[volume-instance] live SBVolumeControl instances: " + count);
            console.log("[volume-instance] done");
        },
    });
});

setInterval(function () {}, 1000);
