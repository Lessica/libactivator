// Usage:
//   frida -U SpringBoard -l scripts/probes/discover-switcher-frida.js
//
// Purpose:
//   Discover App Switcher related Objective-C classes and transition selectors
//   on the attached device. This script only prints Objective-C metadata.
//
// Notes:
//   Keep the Frida session interactive. Do not pass -q.
//   This is a diagnostic probe, not a test.

"use strict";

if (!ObjC.available) {
    throw new Error("Objective-C runtime is unavailable");
}

const classPatterns = [
    /SBMainSwitcher/i,
    /Switcher.*Coordinator/i,
    /Switcher.*Controller/i,
    /FluidSwitcher/i,
    /AppSwitcher/i,
];

const methodPattern =
    /layoutStateTransition|performTransition|transitionDid|transitionWill|bringAppLayout|dismiss.*AppLayout|activate.*AppLayout|didBeginGesture|didEndGesture|recentAppLayouts|isMainSwitcherVisible|isAnySwitcherVisible/i;

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

const classes = matchingClasses();
console.log("[switcher-discovery] matching classes: " + classes.length);

classes.forEach(function (className) {
    const klass = ObjC.classes[className];
    const methods = matchingMethods(klass);
    if (methods.length === 0) {
        return;
    }

    console.log("[switcher-discovery] " + className);
    methods.forEach(function (method) {
        console.log("  " + method);
    });
});

console.log("[switcher-discovery] done");

setInterval(function () {}, 1000);
