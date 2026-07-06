// Usage:
//   frida -U -n SpringBoard -l scripts/probes/probe-springboard-icon-controller-editing-frida.js
//
// Purpose:
//   Verify whether SBIconController responds to -isEditing and report related
//   editing selectors. This is read-only and does not change SpringBoard state.

"use strict";

if (!ObjC.available) {
    throw new Error("Objective-C runtime is unavailable");
}

const probeName = "[springboard-icon-controller-editing-probe]";

function log(message) {
    console.log(probeName + " " + message);
}

function describeObject(object) {
    if (!object) {
        return "nil";
    }
    try {
        return object.$className + "(" + object.handle + ")";
    } catch (_) {
        return String(object);
    }
}

function methodName(selector) {
    return selector.replace(/:/g, "_");
}

function responds(object, selector) {
    if (!object) {
        return false;
    }
    try {
        if (object[methodName(selector)]) {
            return true;
        }
    } catch (_) {}
    try {
        return !!object.respondsToSelector_(ObjC.selector(selector));
    } catch (_) {
        return false;
    }
}

function callBoolean(object, selector) {
    if (!responds(object, selector)) {
        return "not-responding";
    }
    try {
        const result = object[methodName(selector)]();
        if (typeof result === "number") {
            return result !== 0;
        }
        if (result && typeof result.toInt32 === "function") {
            return result.toInt32() !== 0;
        }
        return String(result);
    } catch (error) {
        return "error=" + error;
    }
}

function matchingMethods(className, regex) {
    const cls = ObjC.classes[className];
    if (!cls) {
        return [];
    }
    return (cls.$ownMethods || []).filter(method => regex.test(method)).sort();
}

ObjC.schedule(ObjC.mainQueue, function () {
    const cls = ObjC.classes.SBIconController;
    log("SBIconController class exists=" + String(!!cls));
    const controller = cls && cls.sharedInstance ? cls.sharedInstance() : null;
    log("sharedInstance=" + describeObject(controller));
    for (const selector of ["isEditing", "editing", "setEditing:", "isEditingForHomeScreenOverlayController:"]) {
        log("responds " + selector + "=" + String(responds(controller, selector)));
    }
    log("isEditing value=" + String(callBoolean(controller, "isEditing")));
    log("editing methods=" + matchingMethods("SBIconController", /(Editing|editing)/).join(", "));
    log("done");
    send({ event: "done" });
});
