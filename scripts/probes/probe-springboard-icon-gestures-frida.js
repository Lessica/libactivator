// Usage:
//   frida -U -n SpringBoard -l scripts/probes/probe-springboard-icon-gestures-frida.js
//
// Purpose:
//   Inspect modern SpringBoard icon gesture surfaces without changing behavior.
//   This probe reports SBIconView display identifier paths, live icon view
//   hierarchy, SBIconScrollView pinch/pan gesture recognizers, and likely
//   current icon-list controller selectors.
//
// Notes:
//   Keep the Frida session interactive. Do not pass -q.
//   This is a diagnostic probe, not a test.

"use strict";

if (!ObjC.available) {
    throw new Error("Objective-C runtime is unavailable");
}

const probeName = "[springboard-icon-gesture-probe]";
const startedAt = Date.now();

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

function selectorToMethodName(selector) {
    return selector.replace(/:/g, "_");
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
        return value.toString();
    } catch (_) {
        return "<error>";
    }
}

function describeObject(object) {
    if (!object) {
        return "nil";
    }
    try {
        return object.$className + "(" + object.handle + ")";
    } catch (_) {
        return safeString(object);
    }
}

function responds(object, selector) {
    if (!object) {
        return false;
    }
    const methodName = selectorToMethodName(selector);
    if (object[methodName]) {
        return true;
    }
    try {
        return !!object.respondsToSelector_(ObjC.selector(selector));
    } catch (_) {
        return false;
    }
}

function callObject(object, selector) {
    if (!responds(object, selector)) {
        return null;
    }
    const methodName = selectorToMethodName(selector);
    try {
        return object[methodName]();
    } catch (error) {
        log("call failed " + describeObject(object) + " " + selector + " error=" + error);
        return null;
    }
}

function callBool(object, selector) {
    const value = callObject(object, selector);
    if (value === null || value === undefined) {
        return null;
    }
    return normalizeNumber(value) !== 0;
}

function callString(object, selector) {
    const value = callObject(object, selector);
    if (value === null || value === undefined) {
        return null;
    }
    return safeString(value);
}

function classMethodsMatching(className, needleRegex) {
    const cls = ObjC.classes[className];
    if (!cls) {
        return [];
    }
    const methods = [];
    const ownMethods = cls.$ownMethods || [];
    for (const method of ownMethods) {
        if (needleRegex.test(method)) {
            methods.push(method);
        }
    }
    methods.sort();
    return methods;
}

function arrayItems(arrayObject, limit) {
    const items = [];
    if (!arrayObject) {
        return items;
    }
    let count = 0;
    try {
        count = normalizeNumber(arrayObject.count());
    } catch (_) {
        return items;
    }
    const capped = Math.min(count, limit);
    for (let index = 0; index < capped; index++) {
        try {
            items.push(arrayObject.objectAtIndex_(index));
        } catch (_) {}
    }
    return items;
}

function viewChain(view, limit) {
    const parts = [];
    let current = view;
    for (let index = 0; index < limit && current; index++) {
        parts.push(describeObject(current));
        current = callObject(current, "superview");
    }
    return parts.join(" <- ");
}

function describeGestureRecognizers(view) {
    const recognizers = callObject(view, "gestureRecognizers");
    if (!recognizers) {
        return "gestureRecognizers=nil";
    }
    let count = 0;
    try {
        count = normalizeNumber(recognizers.count());
    } catch (_) {}
    const parts = ["gestureRecognizers=" + count];
    for (const recognizer of arrayItems(recognizers, 10)) {
        const state = callObject(recognizer, "state");
        const enabled = callBool(recognizer, "isEnabled");
        const delegate = callObject(recognizer, "delegate");
        parts.push(
            describeObject(recognizer) +
                " state=" +
                safeString(state) +
                " enabled=" +
                safeString(enabled) +
                " delegate=" +
                describeObject(delegate)
        );
    }
    return parts.join(" | ");
}

function displayIdentifierForIconView(view) {
    const candidates = [];
    const shortcutIdentifier = callString(view, "applicationBundleIdentifierForShortcuts");
    if (shortcutIdentifier) {
        candidates.push("view.applicationBundleIdentifierForShortcuts=" + shortcutIdentifier);
    }

    const icon = callObject(view, "icon");
    candidates.push("icon=" + describeObject(icon));
    if (icon) {
        for (const selector of [
            "applicationBundleID",
            "applicationBundleIdentifier",
            "bundleIdentifier",
            "displayIdentifier",
            "leafIdentifier",
            "nodeIdentifier",
            "uniqueIdentifier",
        ]) {
            const value = callString(icon, selector);
            if (value) {
                candidates.push("icon." + selector + "=" + value);
            }
        }
    }
    return candidates.join(" ");
}

function describeIconView(view, index) {
    log("iconView[" + index + "] " + describeObject(view));
    log("iconView[" + index + "] ids " + displayIdentifierForIconView(view));
    log(
        "iconView[" +
            index +
            "] state editing=" +
            safeString(callBool(view, "isEditing")) +
            " dragging=" +
            safeString(callBool(view, "isDragging")) +
            " showingContextMenu=" +
            safeString(callBool(view, "isShowingContextMenu")) +
            " highlighted=" +
            safeString(callBool(view, "isHighlighted")) +
            " location=" +
            safeString(callString(view, "location"))
    );
    log("iconView[" + index + "] " + describeGestureRecognizers(view));
    log("iconView[" + index + "] chain " + viewChain(view, 12));
}

function describeScrollView(scrollView, index) {
    log("iconScrollView[" + index + "] " + describeObject(scrollView));
    log(
        "iconScrollView[" +
            index +
            "] zoom min=" +
            safeString(callObject(scrollView, "minimumZoomScale")) +
            " max=" +
            safeString(callObject(scrollView, "maximumZoomScale")) +
            " scale=" +
            safeString(callObject(scrollView, "zoomScale")) +
            " zooming=" +
            safeString(callBool(scrollView, "isZooming")) +
            " dragging=" +
            safeString(callBool(scrollView, "isDragging"))
    );
    log(
        "iconScrollView[" +
            index +
            "] pinch=" +
            describeObject(callObject(scrollView, "pinchGestureRecognizer")) +
            " pan=" +
            describeObject(callObject(scrollView, "panGestureRecognizer"))
    );
    log("iconScrollView[" + index + "] " + describeGestureRecognizers(scrollView));
    log("iconScrollView[" + index + "] chain " + viewChain(scrollView, 10));
}

function sharedInstance(className) {
    const cls = ObjC.classes[className];
    if (!cls || !cls.sharedInstance) {
        return null;
    }
    try {
        return cls.sharedInstance();
    } catch (_) {
        return null;
    }
}

function inspectIconController() {
    const controller = sharedInstance("SBIconController");
    log("SBIconController.sharedInstance=" + describeObject(controller));
    if (!controller) {
        return [];
    }

    const methods = classMethodsMatching("SBIconController", /(IconList|iconList|Folder|folder|Root|root|Editing|editing|visible|Visible|current|Current)/);
    log("SBIconController methods matching current/list/folder/editing count=" + methods.length);
    log("SBIconController methods sample " + methods.slice(0, 80).join(", "));
    log("SBIconController isEditing=" + safeString(callBool(controller, "isEditing")));

    const candidates = [];
    for (const selector of [
        "rootFolderController",
        "currentRootIconList",
        "currentRootIconListView",
        "currentIconListView",
        "currentFolderIconList",
        "currentFolderIconListView",
        "openFolderController",
        "openedFolderController",
        "visibleIconListViews",
        "iconListView",
        "rootFolder",
    ]) {
        const value = callObject(controller, selector);
        if (value) {
            log("SBIconController " + selector + " => " + describeObject(value));
            candidates.push({ selector: selector, value: value });
        }
    }
    return candidates;
}

function inspectDescendantGates(iconViews, candidates) {
    for (let i = 0; i < Math.min(iconViews.length, 5); i++) {
        const view = iconViews[i];
        for (const candidate of candidates) {
            if (!responds(view, "isDescendantOfView:")) {
                continue;
            }
            try {
                const result = view.isDescendantOfView_(candidate.value);
                log(
                    "descendant iconView[" +
                        i +
                        "] in " +
                        candidate.selector +
                        "=" +
                        safeString(normalizeNumber(result) !== 0)
                );
            } catch (_) {}
        }
    }
}

ObjC.schedule(ObjC.mainQueue, function () {
    log("start");
    for (const className of ["SBIconView", "SBIconScrollView", "SBIconController", "UIScrollView"]) {
        log("class " + className + " exists=" + safeString(!!ObjC.classes[className]));
    }

    const controllerCandidates = inspectIconController();

    const iconViews = ObjC.classes.SBIconView ? ObjC.chooseSync(ObjC.classes.SBIconView) : [];
    log("live SBIconView count=" + iconViews.length);
    for (let index = 0; index < Math.min(iconViews.length, 8); index++) {
        describeIconView(iconViews[index], index);
    }
    inspectDescendantGates(iconViews, controllerCandidates);

    const scrollViews = ObjC.classes.SBIconScrollView ? ObjC.chooseSync(ObjC.classes.SBIconScrollView) : [];
    log("live SBIconScrollView count=" + scrollViews.length);
    for (let index = 0; index < Math.min(scrollViews.length, 5); index++) {
        describeScrollView(scrollViews[index], index);
    }

    log("done");
    send({ event: "done" });
});
