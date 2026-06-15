// Usage:
//   frida -U -f com.apple.camera -l scripts/probes/probe-camera-ready-frida.js
//   frida -U Camera -l scripts/probes/probe-camera-ready-frida.js
//
// Purpose:
//   Trace CameraUI readiness and shutter paths on device. This script only logs
//   Objective-C method calls and does not alter return values.

"use strict";

if (!ObjC.available) {
    throw new Error("Objective-C runtime is unavailable");
}

const start = Date.now();
const installed = {};

function elapsed() {
    return (Date.now() - start).toString().padStart(6, " ");
}

function log(message) {
    console.log("[camera-ready +" + elapsed() + "ms] " + message);
}

function describeObject(value) {
    if (value === null || value === undefined) {
        return String(value);
    }

    const pointer = ptr(value);
    if (pointer.isNull()) {
        return "nil";
    }

    try {
        return new ObjC.Object(pointer).toString();
    } catch (error) {
        return pointer.toString();
    }
}

function hookMethod(className, selector, options) {
    const key = className + " " + selector;
    if (installed[key]) {
        return true;
    }

    const klass = ObjC.classes[className];
    if (!klass) {
        return false;
    }

    const method = klass[selector];
    if (!method || !method.implementation) {
        return false;
    }

    installed[key] = true;
    Interceptor.attach(method.implementation, {
        onEnter(args) {
            const pieces = [];
            if (options && options.args) {
                options.args.forEach(function (arg) {
                    if (arg.type === "bool") {
                        pieces.push(arg.name + "=" + (!args[arg.index].isNull()));
                    } else if (arg.type === "int") {
                        pieces.push(arg.name + "=" + args[arg.index].toInt32());
                    } else if (arg.type === "double") {
                        pieces.push(arg.name + "=" + args[arg.index].readDouble());
                    } else if (arg.type === "object") {
                        pieces.push(arg.name + "=" + describeObject(args[arg.index]));
                    } else {
                        pieces.push(arg.name + "=" + args[arg.index]);
                    }
                });
            }
            log("enter " + key + (pieces.length ? " " + pieces.join(" ") : ""));
        },
        onLeave(retval) {
            if (!options || !options.ret) {
                return;
            }
            if (options.ret === "bool") {
                log("leave " + key + " return=" + (!retval.isNull()));
            } else if (options.ret === "object") {
                log("leave " + key + " return=" + describeObject(retval));
            } else if (options.ret === "int") {
                log("leave " + key + " return=" + retval.toInt32());
            } else {
                log("leave " + key + " return=" + retval);
            }
        },
    });

    log("hooked " + key);
    return true;
}

function installHooks() {
    hookMethod("UIApplication", "- setWantsVolumeButtonEvents:", {
        args: [{ index: 2, name: "wants", type: "bool" }],
    });

    hookMethod("CAMViewfinderViewController", "- captureController:didOutputCaptureAvailability:", {
        args: [{ index: 3, name: "available", type: "bool" }],
    });
    hookMethod("CAMViewfinderViewController", "- _updateEnabledControlsWithReason:", {
        args: [{ index: 2, name: "reason", type: "object" }],
    });
    hookMethod("CAMViewfinderViewController", "- _updateEnabledControlsWithReason:forceLog:", {
        args: [
            { index: 2, name: "reason", type: "object" },
            { index: 3, name: "forceLog", type: "bool" },
        ],
    });
    hookMethod("CAMViewfinderViewController", "- _updatePhysicalButtonCapturedEnabledResigningActiveOrDisappearing:", {
        args: [{ index: 2, name: "resigningOrDisappearing", type: "bool" }],
    });
    hookMethod("CAMViewfinderViewController", "- pressShutterButtonWithTouchUpDelay:", {
        args: [{ index: 2, name: "delay", type: "double" }],
    });
    hookMethod("CAMViewfinderViewController", "- _handleShutterButtonActionWithEventTriggerDescription:", {
        args: [{ index: 2, name: "trigger", type: "object" }],
    });
    hookMethod("CAMViewfinderViewController", "- _handleShutterButtonPressed:", {
        args: [{ index: 2, name: "sender", type: "object" }],
    });
    hookMethod("CAMViewfinderViewController", "- _handleShutterButtonReleased:", {
        args: [{ index: 2, name: "sender", type: "object" }],
    });
    hookMethod("CAMViewfinderViewController", "- _shouldEnableShutterButton", {
        ret: "bool",
    });
    hookMethod("CAMViewfinderViewController", "- _reasonsToDisableShutterButton", {
        ret: "object",
    });

    hookMethod("CAMPhysicalCaptureRecognizer", "- setEnabled:", {
        args: [{ index: 2, name: "enabled", type: "bool" }],
    });
    hookMethod("CAMPhysicalCaptureRecognizer", "- _updateApplicationButtonStatus", {});

    hookMethod("CAMPhysicalCaptureNotifier", "- setEnabled:", {
        args: [{ index: 2, name: "enabled", type: "bool" }],
    });
    hookMethod("CAMPhysicalCaptureNotifier", "- _updateCaptureButtonNotifications", {});

    hookMethod("CUCaptureController", "- _updateAvailabilityForRequestType:", {
        args: [{ index: 2, name: "requestType", type: "int" }],
    });
    hookMethod("CUCaptureController", "- _notifyDelegateOfCaptureAvailabilityChanged:", {
        args: [{ index: 2, name: "available", type: "bool" }],
    });
    hookMethod("CUCaptureController", "- isCaptureAvailable", {
        ret: "bool",
    });

    hookMethod("CAMCaptureEngine", "- captureOutput:readyForResponsiveRequestAfterResolvedSettings:", {
        args: [{ index: 3, name: "settings", type: "object" }],
    });
}

installHooks();

const timer = setInterval(installHooks, 250);
setTimeout(function () {
    clearInterval(timer);
    log("installed hooks: " + Object.keys(installed).length);
}, 10000);

log("probe loaded");
setInterval(function () {}, 1000);
