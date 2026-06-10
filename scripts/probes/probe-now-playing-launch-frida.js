// Usage:
//   frida -U SpringBoard -l scripts/probes/probe-now-playing-launch-frida.js
//   /var/jb/usr/bin/activator send libactivator.audio.launch-playing-app
//
// Purpose:
//   Diagnose libactivator.audio.launch-playing-app by observing the runtime
//   now-playing application lookup and SpringBoard application launch SPI.
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
    return new ObjC.Object(value);
}

function describeValue(value) {
    const object = objectFromValue(value);
    if (!object) {
        return "nil";
    }
    try {
        return object.toString();
    } catch (error) {
        return object.handle ? object.handle.toString() : "error:" + error;
    }
}

function stringFromObjectMethod(object, selector) {
    try {
        if (!object || !object[selector]) {
            return "";
        }
        const value = object[selector]();
        return value ? value.toString() : "";
    } catch (error) {
        return "error:" + error;
    }
}

function describeApplication(value) {
    const object = objectFromValue(value);
    if (!object) {
        return "nil";
    }
    const klass = object.$className || "<unknown>";
    const displayIdentifier = stringFromObjectMethod(object, "- displayIdentifier");
    const bundleIdentifier = stringFromObjectMethod(object, "- bundleIdentifier");
    const displayName = stringFromObjectMethod(object, "- displayName");
    return (
        klass +
        " displayIdentifier=" +
        (displayIdentifier || "<empty>") +
        " bundleIdentifier=" +
        (bundleIdentifier || "<empty>") +
        " displayName=" +
        (displayName || "<empty>") +
        " object=" +
        object
    );
}

function frontmostApplication() {
    try {
        const application = ObjC.classes.UIApplication["+ sharedApplication"]();
        if (!application || !application["- _accessibilityFrontMostApplication"]) {
            return "<unavailable>";
        }
        return describeApplication(application["- _accessibilityFrontMostApplication"]());
    } catch (error) {
        return "error:" + error;
    }
}

function sampleFrontmost(label) {
    ObjC.schedule(ObjC.mainQueue, function () {
        console.log("[now-playing-launch] " + now() + " " + label + " frontmost=" + frontmostApplication());
    });
}

function attachObjCMethod(className, selector, label, callbacks) {
    const klass = ObjC.classes[className];
    if (!klass || !klass[selector] || !klass[selector].implementation) {
        console.log("[now-playing-launch] missing " + className + " " + selector);
        return false;
    }

    Interceptor.attach(klass[selector].implementation, {
        onEnter(args) {
            this.args = args;
            if (callbacks && callbacks.onEnter) {
                callbacks.onEnter.call(this, args);
            } else {
                console.log("[now-playing-launch] " + now() + " enter " + label);
            }
        },
        onLeave(retval) {
            if (callbacks && callbacks.onLeave) {
                callbacks.onLeave.call(this, retval);
            } else {
                console.log("[now-playing-launch] " + now() + " leave " + label + " retval=" + describeValue(retval));
            }
        },
    });

    console.log("[now-playing-launch] attached " + className + " " + selector);
    return true;
}

function dumpRelevantMethods(className) {
    const klass = ObjC.classes[className];
    if (!klass) {
        console.log("[now-playing-launch] class unavailable " + className);
        return;
    }

    const pattern = /(now|play|media|app|launch|activate|open|display|bundle|destination)/i;
    console.log("[now-playing-launch] methods matching " + className);
    klass.$ownMethods
        .filter(function (method) {
            return pattern.test(method);
        })
        .sort()
        .forEach(function (method) {
            console.log("[now-playing-launch]   " + method);
        });
}

function sampleNowPlayingState() {
    ObjC.schedule(ObjC.mainQueue, function () {
        console.log("[now-playing-launch] " + now() + " sampling now-playing state");
        const mediaControllerClass = ObjC.classes.SBMediaController;
        if (!mediaControllerClass || !mediaControllerClass["+ sharedInstance"]) {
            console.log("[now-playing-launch] SBMediaController sharedInstance unavailable");
            return;
        }

        const mediaController = mediaControllerClass["+ sharedInstance"]();
        [
            "- nowPlayingApplication",
            "- mediaControlsDestinationApp",
            "- nowPlayingApplicationDisplayID",
            "- nowPlayingBundleID",
            "- nowPlayingProcessPID",
        ].forEach(function (selector) {
            try {
                if (!mediaController[selector]) {
                    console.log("[now-playing-launch] " + selector + " => <missing>");
                    return;
                }
                const result = mediaController[selector]();
                console.log("[now-playing-launch] " + selector + " => " + describeApplication(result));
            } catch (error) {
                console.log("[now-playing-launch] " + selector + " => error:" + error);
            }
        });
    });
}

ObjC.schedule(ObjC.mainQueue, function () {
    console.log("[now-playing-launch] ready");
    [
        "LATMediaNowPlayingApplicationLauncher",
        "SBMediaController",
        "SpringBoard",
        "SBUIController",
        "SBApplicationController",
        "FBSystemService",
        "FBSOpenApplicationService",
        "FBSSystemService",
    ].forEach(dumpRelevantMethods);

    sampleNowPlayingState();
    sampleFrontmost("initial");
});

attachObjCMethod(
    "LATMediaNowPlayingApplicationLauncher",
    "- launchNowPlayingApplicationForListenerName:",
    "LAT launcher",
    {
        onEnter(args) {
            console.log(
                "[now-playing-launch] " +
                    now() +
                    " enter LAT launcher listener=" +
                    describeValue(args[2])
            );
            sampleNowPlayingState();
            sampleFrontmost("before LAT launcher");
        },
        onLeave(retval) {
            console.log("[now-playing-launch] " + now() + " leave LAT launcher retval=" + retval);
            sampleFrontmost("after LAT launcher");
            [100, 500, 1000, 2000].forEach(function (delay) {
                setTimeout(function () {
                    sampleFrontmost("after LAT launcher +" + delay + "ms");
                }, delay);
            });
        },
    }
);

attachObjCMethod("LATMediaNowPlayingApplicationLauncher", "- nowPlayingApplication", "LAT nowPlayingApplication", {
    onLeave(retval) {
        console.log("[now-playing-launch] " + now() + " LAT nowPlayingApplication => " + describeApplication(retval));
    },
});

attachObjCMethod(
    "LATMediaNowPlayingApplicationLauncher",
    "- launchApplicationWithIdentifier:",
    "LAT launchApplicationWithIdentifier",
    {
        onEnter(args) {
            console.log(
                "[now-playing-launch] " +
                    now() +
                    " LAT launchApplicationWithIdentifier identifier=" +
                    describeValue(args[2])
            );
        },
        onLeave(retval) {
            console.log("[now-playing-launch] " + now() + " LAT launchApplicationWithIdentifier => " + retval);
        },
    }
);

attachObjCMethod("LATMediaNowPlayingApplicationLauncher", "- activateApplication:", "LAT activateApplication", {
    onEnter(args) {
        console.log(
            "[now-playing-launch] " +
                now() +
                " LAT activateApplication app=" +
                describeApplication(args[2])
        );
    },
    onLeave(retval) {
        console.log("[now-playing-launch] " + now() + " LAT activateApplication => " + retval);
    },
});

attachObjCMethod("SBMediaController", "- nowPlayingApplication", "SBMediaController nowPlayingApplication", {
    onLeave(retval) {
        console.log(
            "[now-playing-launch] " +
                now() +
                " SBMediaController nowPlayingApplication => " +
                describeApplication(retval)
        );
    },
});

attachObjCMethod("SBMediaController", "- mediaControlsDestinationApp", "SBMediaController mediaControlsDestinationApp", {
    onLeave(retval) {
        console.log(
            "[now-playing-launch] " +
                now() +
                " SBMediaController mediaControlsDestinationApp => " +
                describeApplication(retval)
        );
    },
});

attachObjCMethod("SpringBoard", "- launchApplicationWithIdentifier:suspended:", "SpringBoard launch", {
    onEnter(args) {
        console.log(
            "[now-playing-launch] " +
                now() +
                " SpringBoard launch identifier=" +
                describeValue(args[2]) +
                " suspended=" +
                args[3]
        );
        sampleFrontmost("before SpringBoard launch");
    },
    onLeave(retval) {
        console.log("[now-playing-launch] " + now() + " SpringBoard launch returned " + retval);
        sampleFrontmost("after SpringBoard launch");
    },
});

attachObjCMethod("SBUIController", "- activateApplicationAnimated:", "SBUIController activateApplicationAnimated", {
    onEnter(args) {
        console.log(
            "[now-playing-launch] " +
                now() +
                " SBUIController activateApplicationAnimated app=" +
                describeApplication(args[2])
        );
    },
});

attachObjCMethod("SBUIController", "- activateApplicationFromSwitcher:", "SBUIController activateApplicationFromSwitcher", {
    onEnter(args) {
        console.log(
            "[now-playing-launch] " +
                now() +
                " SBUIController activateApplicationFromSwitcher app=" +
                describeApplication(args[2])
        );
    },
});

setInterval(function () {}, 1000);
