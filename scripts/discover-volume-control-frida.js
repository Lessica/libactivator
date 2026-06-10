// Usage:
//   frida -U SpringBoard -l scripts/discover-volume-control-frida.js
//
// Purpose:
//   Discover volume-control related Objective-C classes and selectors on the
//   attached device. This script only prints Objective-C metadata and a few
//   read-only object descriptions.
//
// Notes:
//   Keep the Frida session interactive. Do not pass -q.
//   This is a diagnostic probe, not a test.

"use strict";

if (!ObjC.available) {
    throw new Error("Objective-C runtime is unavailable");
}

const classPatterns = [
    /^SBVolumeControl$/,
    /Volume.*Control/i,
    /Volume.*HUD/i,
    /HUD.*Volume/i,
    /Volume.*View/i,
    /Volume.*Controller/i,
];

const methodPattern =
    /shared|volume|Volume|HUD|hud|show|hide|present|dismiss|increase|decrease|change|ringer|mute|effective|route|audio/i;

function uniqueSorted(values) {
    return Array.from(new Set(values)).sort();
}

function matchingClasses() {
    return uniqueSorted(
        Object.keys(ObjC.classes).filter(function (name) {
            return classPatterns.some(function (pattern) {
                return pattern.test(name);
            });
        })
    );
}

function matchingMethods(klass) {
    return uniqueSorted(
        klass.$ownMethods.filter(function (method) {
            return methodPattern.test(method);
        })
    );
}

function describeObject(value) {
    if (value === null || value === undefined) {
        return "nil";
    }
    try {
        if (value.isNull && value.isNull()) {
            return "nil";
        }
        return new ObjC.Object(value).toString();
    } catch (error) {
        return "error:" + error;
    }
}

function callNoArg(object, selector) {
    try {
        if (!object || !object[selector]) {
            return "<missing>";
        }
        return describeObject(object[selector]());
    } catch (error) {
        return "error:" + error;
    }
}

const classes = matchingClasses();
console.log("[volume-discovery] matching classes: " + classes.length);

classes.forEach(function (className) {
    const klass = ObjC.classes[className];
    const methods = matchingMethods(klass);
    console.log("[volume-discovery] " + className);
    if (methods.length === 0) {
        console.log("  <no matching own methods>");
        return;
    }
    methods.forEach(function (method) {
        console.log("  " + method);
    });
});

ObjC.schedule(ObjC.mainQueue, function () {
    const candidates = ["SBVolumeControl", "VolumeControl"];
    candidates.forEach(function (className) {
        const klass = ObjC.classes[className];
        if (!klass) {
            console.log("[volume-discovery] " + className + " unavailable");
            return;
        }

        const sharedSelector = klass["+ sharedInstance"]
            ? "+ sharedInstance"
            : klass["+ sharedVolumeControl"]
              ? "+ sharedVolumeControl"
              : null;
        if (!sharedSelector) {
            console.log("[volume-discovery] " + className + " has no known shared selector");
            return;
        }

        let instance = null;
        try {
            instance = klass[sharedSelector]();
        } catch (error) {
            console.log("[volume-discovery] " + className + " " + sharedSelector + " error: " + error);
            return;
        }

        console.log("[volume-discovery] " + className + " " + sharedSelector + " => " + describeObject(instance));
        const object = new ObjC.Object(instance);
        [
            "- volume",
            "- effectiveVolume",
            "- mediaVolume",
            "- ringerVolume",
            "- isMuted",
            "- isRingerMuted",
            "- isVolumeHUDVisible",
            "- volumeHUDIsVisible",
        ].forEach(function (selector) {
            console.log("[volume-discovery] " + className + " " + selector + " => " + callNoArg(object, selector));
        });
    });
});

console.log("[volume-discovery] done");

setInterval(function () {}, 1000);
