// Usage:
//   frida -U SpringBoard -l scripts/probes/discover-mediaremote-now-playing-frida.js
//
// Purpose:
//   Discover MediaRemote exports related to now-playing application identity and
//   probe known read-only identity APIs.
//
// Notes:
//   Keep the Frida session interactive. Do not pass -q.
//   This script enumerates symbols and performs read-only calls whose signatures
//   match the existing MediaRemote / SpringBoardServices conventions.

"use strict";

if (!ObjC.available) {
    throw new Error("Objective-C runtime is unavailable");
}

function findMediaRemoteModules() {
    return Process.enumerateModules().filter(function (module) {
        return /MediaRemote/i.test(module.name) || /MediaRemote/i.test(module.path);
    });
}

function loadFramework(path) {
    try {
        Module.load(path);
        console.log("[mediaremote-probe] loaded " + path);
    } catch (error) {
        console.log("[mediaremote-probe] unable to load " + path + ": " + error);
    }
}

function findGlobalExport(symbol) {
    if (typeof Module.getGlobalExportByName === "function") {
        try {
            return Module.getGlobalExportByName(symbol);
        } catch (_) {}
    }

    if (typeof Module.findGlobalExportByName === "function") {
        const address = Module.findGlobalExportByName(symbol);
        if (address) {
            return address;
        }
    }

    if (typeof Module.findExportByName === "function") {
        const address = Module.findExportByName(null, symbol);
        if (address) {
            return address;
        }
    }

    return null;
}

function findExport(symbols) {
    for (const symbol of symbols) {
        const address = findGlobalExport(symbol);
        if (address) {
            console.log("[mediaremote-probe] resolved " + symbol + " => " + address);
            return { name: symbol, address: address };
        }
    }
    console.log("[mediaremote-probe] unresolved " + symbols.join(", "));
    return null;
}

function describeCFObject(value) {
    if (value.isNull()) {
        return "nil";
    }
    try {
        return new ObjC.Object(value).toString();
    } catch (error) {
        return value.toString();
    }
}

function dumpExports(module) {
    const pattern = /(NowPlayingApplication|SBSCopyNowPlaying|SBSCopyDisplayIdentifierForProcessID|SystemMediaApplicationDisplayID)/i;
    console.log("[mediaremote-probe] exports matching " + module.name);
    module
        .enumerateExports()
        .filter(function (exp) {
            return pattern.test(exp.name);
        })
        .sort(function (a, b) {
            return a.name < b.name ? -1 : a.name > b.name ? 1 : 0;
        })
        .forEach(function (exp) {
            console.log("[mediaremote-probe]   " + exp.type + " " + exp.name + " " + exp.address);
        });
}

function dumpPrivateFrameworkClasses() {
    const pattern = /(MediaRemote|NowPlaying|MRNow|MRMedia|MRPlayer|MRClient)/i;
    console.log("[mediaremote-probe] ObjC classes matching media remote patterns");
    Object.keys(ObjC.classes)
        .filter(function (name) {
            return pattern.test(name);
        })
        .sort()
        .forEach(function (name) {
            console.log("[mediaremote-probe]   " + name);
        });
}

function probeSpringBoardController() {
    console.log("[mediaremote-probe] probing SBMediaController");
    const mediaControllerClass = ObjC.classes.SBMediaController;
    if (!mediaControllerClass || !mediaControllerClass["+ sharedInstance"]) {
        console.log("[mediaremote-probe]   SBMediaController unavailable");
        return;
    }

    const controller = mediaControllerClass.sharedInstance();
    if (controller["- nowPlayingApplication"]) {
        const application = controller.nowPlayingApplication();
        console.log("[mediaremote-probe]   nowPlayingApplication=" + (application ? application.toString() : "nil"));
        if (application) {
            if (application["- bundleIdentifier"]) {
                console.log("[mediaremote-probe]   app.bundleIdentifier=" + application.bundleIdentifier());
            }
            if (application["- displayIdentifier"]) {
                console.log("[mediaremote-probe]   app.displayIdentifier=" + application.displayIdentifier());
            }
        }
    } else {
        console.log("[mediaremote-probe]   nowPlayingApplication selector missing");
    }

    if (controller["- nowPlayingProcessPID"]) {
        try {
            console.log("[mediaremote-probe]   nowPlayingProcessPID=" + controller.nowPlayingProcessPID());
        } catch (error) {
            console.log("[mediaremote-probe]   nowPlayingProcessPID call failed: " + error);
        }
    }
}

function probeSpringBoardServices() {
    console.log("[mediaremote-probe] probing SpringBoardServices");
    const copyNowPlaying = findExport(["SBSCopyNowPlayingAppBundleIdentifier"]);
    if (copyNowPlaying) {
        const fn = new NativeFunction(copyNowPlaying.address, "pointer", []);
        const value = fn();
        console.log("[mediaremote-probe]   SBSCopyNowPlayingAppBundleIdentifier => " + describeCFObject(value));
    }
}

const liveBlocks = [];

function probeMediaRemoteAsync() {
    console.log("[mediaremote-probe] probing MediaRemote async identity APIs");

    const setWants = findExport(["MRMediaRemoteSetWantsNowPlayingNotifications"]);
    if (setWants) {
        const fn = new NativeFunction(setWants.address, "void", ["uchar"]);
        fn(1);
        console.log("[mediaremote-probe]   requested now-playing notifications");
    }

    const dispatchGetGlobalQueue = findExport(["dispatch_get_global_queue"]);
    if (!dispatchGetGlobalQueue) {
        console.log("[mediaremote-probe]   dispatch_get_global_queue unavailable");
        return;
    }
    const getGlobalQueue = new NativeFunction(dispatchGetGlobalQueue.address, "pointer", ["long", "ulong"]);
    const queue = getGlobalQueue(0, 0);

    const displayIDExport = findExport([
        "_MRMediaRemoteGetNowPlayingApplicationDisplayID",
        "MRMediaRemoteGetNowPlayingApplicationDisplayID",
    ]);
    if (displayIDExport) {
        const block = new ObjC.Block({
            retType: "void",
            argTypes: ["pointer"],
            implementation: function (displayID) {
                console.log(
                    "[mediaremote-probe]   " +
                        displayIDExport.name +
                        " completion displayID=" +
                        describeCFObject(displayID)
                );
            },
        });
        liveBlocks.push(block);
        const fn = new NativeFunction(displayIDExport.address, "void", ["pointer", "pointer"]);
        try {
            fn(queue, block);
            console.log("[mediaremote-probe]   called " + displayIDExport.name);
        } catch (error) {
            console.log("[mediaremote-probe]   " + displayIDExport.name + " call failed: " + error);
        }
    }

    const pidExport = findExport(["MRMediaRemoteGetNowPlayingApplicationPID"]);
    if (pidExport) {
        const displayForPid = findExport(["SBSCopyDisplayIdentifierForProcessID"]);
        const displayForPidFn = displayForPid ? new NativeFunction(displayForPid.address, "pointer", ["int"]) : null;
        const block = new ObjC.Block({
            retType: "void",
            argTypes: ["int"],
            implementation: function (pid) {
                console.log("[mediaremote-probe]   MRMediaRemoteGetNowPlayingApplicationPID completion pid=" + pid);
                if (displayForPidFn && pid > 0) {
                    const value = displayForPidFn(pid);
                    console.log("[mediaremote-probe]   SBSCopyDisplayIdentifierForProcessID(" + pid + ") => " + describeCFObject(value));
                }
            },
        });
        liveBlocks.push(block);
        const fn = new NativeFunction(pidExport.address, "void", ["pointer", "pointer"]);
        try {
            fn(queue, block);
            console.log("[mediaremote-probe]   called MRMediaRemoteGetNowPlayingApplicationPID");
        } catch (error) {
            console.log("[mediaremote-probe]   MRMediaRemoteGetNowPlayingApplicationPID call failed: " + error);
        }
    }
}

loadFramework("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote");
loadFramework("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices");

const modules = findMediaRemoteModules();
if (modules.length === 0) {
    console.log("[mediaremote-probe] MediaRemote module is not loaded");
} else {
    modules.forEach(function (module) {
        console.log("[mediaremote-probe] module " + module.name + " " + module.path);
        dumpExports(module);
    });
}

dumpPrivateFrameworkClasses();
probeSpringBoardController();
probeSpringBoardServices();
probeMediaRemoteAsync();

setTimeout(function () {
    console.log("[mediaremote-probe] done");
}, 5000);

setInterval(function () {}, 1000);
