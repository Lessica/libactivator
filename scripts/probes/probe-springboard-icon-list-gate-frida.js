// Usage:
//   frida -U -n SpringBoard -l scripts/probes/probe-springboard-icon-list-gate-frida.js
//
// Purpose:
//   Discover the modern SpringBoard controller/view path that can answer
//   whether an SBIconView belongs to the currently active icon list.
//
// Notes:
//   Keep the Frida session interactive. Do not pass -q.
//   This is a diagnostic probe, not a test.

"use strict";

if (!ObjC.available) {
    throw new Error("Objective-C runtime is unavailable");
}

const probeName = "[springboard-icon-list-gate-probe]";
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

function classMethodsMatching(className, needleRegex, limit) {
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
    return methods.slice(0, limit);
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
    for (let index = 0; index < Math.min(count, limit); index++) {
        try {
            items.push(arrayObject.objectAtIndex_(index));
        } catch (_) {}
    }
    return items;
}

function expandValue(value) {
    if (!value) {
        return [];
    }
    const className = value.$className || "";
    if (className.indexOf("NSArray") !== -1 || className.indexOf("NSSet") !== -1 || className.indexOf("NSHashTable") !== -1) {
        return arrayItems(value, 12);
    }
    return [value];
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

function findControllerObjects() {
    const controller = sharedInstance("SBIconController");
    log("SBIconController.sharedInstance=" + describeObject(controller));
    if (!controller) {
        return [];
    }
    log("SBIconController isEditing=" + safeString(callBool(controller, "isEditing")));
    log(
        "SBIconController relevant methods " +
            classMethodsMatching("SBIconController", /(IconList|iconList|Folder|folder|Root|root|View|view|current|Current|open|Open|dock|Dock)/, 140).join(", ")
    );

    const selectors = [
        "_rootFolderController",
        "rootFolderController",
        "_openFolderController",
        "openFolderController",
        "_currentFolderController",
        "currentFolderController",
        "rootFolder",
        "currentAnimationContainer",
        "currentIconListIndex",
    ];
    const results = [];
    for (const selector of selectors) {
        const value = callObject(controller, selector);
        if (value) {
            log("SBIconController " + selector + " => " + describeObject(value) + " value=" + safeString(value));
            results.push({ label: "SBIconController." + selector, object: value });
        }
    }
    return results;
}

function inspectObject(label, object, depth) {
    if (!object || depth <= 0) {
        return [];
    }
    const className = object.$className || "";
    log(label + " object=" + describeObject(object));
    log(
        label +
            " methods " +
            classMethodsMatching(className, /(IconList|iconList|Scroll|scroll|Folder|folder|Root|root|View|view|current|Current|Page|page|Index|index|dock|Dock)/, 120).join(", ")
    );

    const selectors = [
        "view",
        "rootFolderView",
        "folderView",
        "contentView",
        "rootFolder",
        "folder",
        "iconListView",
        "currentIconListView",
        "currentRootIconListView",
        "currentFolderIconListView",
        "currentIconList",
        "currentRootIconList",
        "currentFolderIconList",
        "visibleIconListViews",
        "iconListViews",
        "dockListView",
        "dockView",
        "scrollView",
        "iconScrollView",
        "currentPageIndex",
        "currentIconListIndex",
        "pageControl",
    ];

    const discovered = [];
    for (const selector of selectors) {
        const value = callObject(object, selector);
        if (!value) {
            continue;
        }
        log(label + " " + selector + " => " + describeObject(value) + " value=" + safeString(value));
        for (const expanded of expandValue(value)) {
            discovered.push({ label: label + "." + selector, object: expanded });
        }
    }
    return discovered;
}

function iconViewSummary(view, index) {
    log(
        "iconView[" +
            index +
            "] " +
            describeObject(view) +
            " location=" +
            safeString(callString(view, "location")) +
            " id=" +
            safeString(callString(view, "applicationBundleIdentifierForShortcuts")) +
            " chain=" +
            viewChain(view, 10)
    );
}

function inspectDescendant(iconViews, candidates) {
    for (let iconIndex = 0; iconIndex < Math.min(iconViews.length, 8); iconIndex++) {
        const view = iconViews[iconIndex];
        for (const candidate of candidates) {
            if (!responds(view, "isDescendantOfView:")) {
                continue;
            }
            try {
                const result = view.isDescendantOfView_(candidate.object);
                if (normalizeNumber(result) !== 0) {
                    log("descendant iconView[" + iconIndex + "] in " + candidate.label + " => true " + describeObject(candidate.object));
                }
            } catch (_) {}
        }
    }
}

ObjC.schedule(ObjC.mainQueue, function () {
    log("start");
    let queue = findControllerObjects();
    const allCandidates = [];
    const seen = {};

    for (let depth = 0; depth < 3; depth++) {
        const next = [];
        for (const item of queue) {
            const key = item.object && item.object.handle ? item.object.handle.toString() : item.label;
            if (seen[key]) {
                continue;
            }
            seen[key] = true;
            allCandidates.push(item);
            const discovered = inspectObject(item.label, item.object, 3 - depth);
            next.push.apply(next, discovered);
        }
        queue = next;
    }

    const iconViews = ObjC.classes.SBIconView ? ObjC.chooseSync(ObjC.classes.SBIconView) : [];
    log("live SBIconView count=" + iconViews.length);
    for (let index = 0; index < Math.min(iconViews.length, 8); index++) {
        iconViewSummary(iconViews[index], index);
    }
    inspectDescendant(iconViews, allCandidates);
    log("done");
    send({ event: "done" });
});
