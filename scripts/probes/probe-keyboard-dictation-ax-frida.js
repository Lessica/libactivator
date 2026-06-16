// Usage:
//   frida -U SpringBoard -l scripts/probes/probe-keyboard-dictation-ax-frida.js
//
// Purpose:
//   Inspect currently visible AXElement objects for the on-screen keyboard dictation key.
//   This probe is read-only: it enumerates labels/actions and does not press anything.

"use strict";

if (!ObjC.available) {
    throw new Error("Objective-C runtime is unavailable");
}

const probeName = "[keyboard-dictation-ax-probe]";
const dictationIdentifier = "0:30";
function log(message) {
    console.log(probeName + " " + message);
}

function loadFramework(path) {
    try {
        Module.load(path);
        log("loaded " + path);
        return true;
    } catch (error) {
        log("failed to load " + path + ": " + error);
        return false;
    }
}

function ptrToObj(value) {
    if (!value || value.isNull()) {
        return null;
    }
    try {
        return new ObjC.Object(value);
    } catch (_) {
        return null;
    }
}

function responds(object, selectorName) {
    try {
        return !!(object && object.respondsToSelector_(ObjC.selector(selectorName)));
    } catch (error) {
        log("respondsToSelector failed selector=" + selectorName + " error=" + error);
        return false;
    }
}

function callObject(object, selectorName) {
    if (!responds(object, selectorName)) {
        return null;
    }
    try {
        return object[selectorName]();
    } catch (error) {
        return "<error:" + error + ">";
    }
}

function callRequiredObject(object, selectorName, context) {
    log(context + " calling " + selectorName);
    const value = callObject(object, selectorName);
    if (typeof value === "string" && value.indexOf("<error:") === 0) {
        log(context + " " + selectorName + " failed " + value);
        return null;
    }
    if (!value) {
        log(context + " " + selectorName + " returned nil");
        return null;
    }
    log(context + " " + selectorName + " returned class=" + (value.$className || "<unknown>") + " ptr=" + value.handle);
    return value;
}

function callBool(object, selectorName) {
    if (!responds(object, selectorName)) {
        return null;
    }
    try {
        return !!object[selectorName]();
    } catch (_) {
        return null;
    }
}

function callNumber(object, selectorName) {
    const value = callObject(object, selectorName);
    if (value === null || value === undefined || typeof value === "string") {
        return null;
    }
    try {
        return Number(value.toString());
    } catch (_) {
        return null;
    }
}

function objectDescription(value) {
    if (value === null || value === undefined) {
        return "";
    }
    if (typeof value === "string") {
        return value;
    }
    try {
        return value.toString();
    } catch (_) {
        return "<unprintable>";
    }
}

function nsArrayToStrings(value) {
    if (!value || typeof value === "string") {
        return [];
    }
    try {
        const count = Number(value.count().toString());
        const strings = [];
        for (let i = 0; i < count; i++) {
            const item = value.objectAtIndex_(i);
            strings.push(objectDescription(item));
        }
        return strings;
    } catch (_) {
        return [];
    }
}

function titleCandidates(element) {
    const candidates = [];
    for (const selectorName of ["label", "speechInputLabel", "value", "identifier"]) {
        const value = callObject(element, selectorName);
        const text = objectDescription(value);
        if (text.length > 0 && text.indexOf("<error:") !== 0) {
            candidates.push(selectorName + "=" + text);
        }
    }
    for (const selectorName of ["recognitionStrings", "userInputLabels"]) {
        const strings = nsArrayToStrings(callObject(element, selectorName));
        if (strings.length > 0) {
            candidates.push(selectorName + "=[" + strings.join(" | ") + "]");
        }
    }
    return candidates;
}

function frameDescription(element) {
    const frame = callObject(element, "frame");
    if (!frame || typeof frame === "string") {
        return "";
    }
    try {
        return objectDescription(frame);
    } catch (_) {
        return "";
    }
}

function shouldHighlight(summary) {
    return summary.indexOf("identifier=" + dictationIdentifier) >= 0;
}

function logElement(prefix, element) {
    if (!element) {
        log(prefix + " nil");
        return;
    }
    const className = element.$className || "<unknown>";
    const traits = callNumber(element, "traits");
    const enabled = callBool(element, "isEnabled");
    const visible = callBool(element, "isVisible");
    const canPress = responds(element, "press");
    const canPerformAction = responds(element, "performAction:");
    const titles = titleCandidates(element);
    const frame = frameDescription(element);
    const summary =
        prefix +
        " class=" +
        className +
        " ptr=" +
        element.handle +
        " traits=" +
        (traits === null ? "?" : "0x" + traits.toString(16)) +
        " enabled=" +
        enabled +
        " visible=" +
        visible +
        " press=" +
        canPress +
        " performAction=" +
        canPerformAction +
        (frame.length > 0 ? " frame=" + frame : "") +
        (titles.length > 0 ? " " + titles.join(" ") : "");
    log((shouldHighlight(summary) ? "CANDIDATE " : "") + summary);
}

function checkApplicationAccessibility() {
    try {
        const enabledPtr = Module.getGlobalExportByName
            ? Module.getGlobalExportByName("_AXSApplicationAccessibilityEnabled")
            : null;
        if (!enabledPtr) {
            log("_AXSApplicationAccessibilityEnabled unavailable");
            return;
        }
        const enabled = new NativeFunction(enabledPtr, "bool", []);
        log("application accessibility enabled=" + enabled());
    } catch (error) {
        log("application accessibility check failed: " + error);
    }
}

function enumerateVisibleElements() {
    log("enumeration started");
    loadFramework("/System/Library/PrivateFrameworks/SpeechRecognitionCommandAndControl.framework/SpeechRecognitionCommandAndControl");
    loadFramework("/System/Library/PrivateFrameworks/AccessibilityUtilities.framework/AccessibilityUtilities");
    loadFramework("/usr/lib/libAccessibility.dylib");
    checkApplicationAccessibility();

    const AXElement = ObjC.classes.AXElement;
    log("AXElement class=" + (AXElement ? "available" : "missing"));
    if (!AXElement) {
        log("AXElement is unavailable");
        return;
    }
    if (!responds(AXElement, "systemApplication")) {
        log("AXElement.systemApplication is unavailable");
        return;
    }

    const systemApplication = callRequiredObject(AXElement, "systemApplication", "AXElement");
    if (!systemApplication) {
        return;
    }
    logElement("systemApplication", systemApplication);
    enumerateElementCollection(systemApplication, "systemApplication");

    const applications = callRequiredObject(systemApplication, "currentApplications", "systemApplication");
    if (!applications || typeof applications === "string") {
        log("currentApplications unavailable: " + objectDescription(applications));
        return;
    }

    const appCount = Number(applications.count().toString());
    log("currentApplications count=" + appCount);
    for (let appIndex = 0; appIndex < appCount; appIndex++) {
        const application = applications.objectAtIndex_(appIndex);
        logElement("application[" + appIndex + "]", application);
        enumerateElementCollection(application, "application[" + appIndex + "]");
    }
}

function enumerateElementCollection(owner, prefix) {
    for (const selectorName of ["visibleElements", "children"]) {
        const elements = callObject(owner, selectorName);
        if (!elements || typeof elements === "string") {
            log(prefix + " " + selectorName + " unavailable: " + objectDescription(elements));
            continue;
        }

        let count = 0;
        try {
            count = Number(elements.count().toString());
        } catch (error) {
            log(prefix + " " + selectorName + " count failed: " + error);
            continue;
        }
        log(prefix + " " + selectorName + " count=" + count);
        for (let elementIndex = 0; elementIndex < count; elementIndex++) {
            try {
                const element = elements.objectAtIndex_(elementIndex);
                logElement(prefix + "." + selectorName + "[" + elementIndex + "]", element);
            } catch (error) {
                log(prefix + "." + selectorName + "[" + elementIndex + "] failed: " + error);
            }
        }
    }
}

log("script loaded; scheduling enumeration on main queue");
ObjC.schedule(ObjC.mainQueue, function () {
    try {
        enumerateVisibleElements();
        log("probe complete");
        send({ event: "done" });
    } catch (error) {
        log("probe failed: " + (error.stack || error));
        send({ event: "done", error: String(error) });
    }
});

setTimeout(function () {
    send({ event: "timeout" });
}, 10000);
