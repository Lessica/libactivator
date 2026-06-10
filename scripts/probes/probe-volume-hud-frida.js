// Usage:
//   frida -U SpringBoard -l scripts/probes/probe-volume-hud-frida.js
//
// Purpose:
//   Verify whether SBVolumeControl -_presentVolumeHUDWithVolume: can present
//   the modern system volume HUD. This script briefly shows the HUD, samples
//   state, then hides it again.
//
// Notes:
//   Keep the Frida session interactive. Do not pass -q.
//   This is a diagnostic probe, not a test.

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

function sample(label, object) {
    let visible = "<missing>";
    let presented = "<missing>";
    let existing = "<missing>";
    try {
        if (object["- _isVolumeHUDVisible"]) {
            visible = object["- _isVolumeHUDVisible"]() ? "YES" : "NO";
        }
        if (object["- presentedVolumeHUDViewController"]) {
            presented = describe(object["- presentedVolumeHUDViewController"]());
        }
        if (object["- existingVolumeHUDViewController"]) {
            existing = describe(object["- existingVolumeHUDViewController"]());
        }
    } catch (error) {
        console.log("[volume-hud-probe] " + label + " sample error: " + error);
        return;
    }
    console.log(
        "[volume-hud-probe] " +
            label +
            " visible=" +
            visible +
            " presented=" +
            presented +
            " existing=" +
            existing
    );
}

ObjC.schedule(ObjC.mainQueue, function () {
    let target = null;
    ObjC.choose(ObjC.classes.SBVolumeControl, {
        onMatch(instance) {
            if (target === null) {
                target = new ObjC.Object(instance);
            }
        },
        onComplete() {
            if (target === null) {
                console.log("[volume-hud-probe] no live SBVolumeControl instance");
                return;
            }

            let volume = 0.5;
            try {
                if (target["- _effectiveVolume"]) {
                    volume = target["- _effectiveVolume"]();
                }
            } catch (error) {
                console.log("[volume-hud-probe] _effectiveVolume error: " + error);
            }

            console.log("[volume-hud-probe] target=" + target + " volume=" + volume);
            sample("before", target);

            try {
                target["- _presentVolumeHUDWithVolume:"](volume);
                console.log("[volume-hud-probe] invoked -_presentVolumeHUDWithVolume:");
            } catch (error) {
                console.log("[volume-hud-probe] present error: " + error);
                return;
            }

            setTimeout(function () {
                ObjC.schedule(ObjC.mainQueue, function () {
                    sample("after-present", target);
                    try {
                        if (target["- hideVolumeHUDIfVisible"]) {
                            target["- hideVolumeHUDIfVisible"]();
                            console.log("[volume-hud-probe] invoked -hideVolumeHUDIfVisible");
                        }
                    } catch (error) {
                        console.log("[volume-hud-probe] hide error: " + error);
                    }
                });
            }, 500);

            setTimeout(function () {
                ObjC.schedule(ObjC.mainQueue, function () {
                    sample("after-hide", target);
                    console.log("[volume-hud-probe] done");
                });
            }, 1000);
        },
    });
});

setInterval(function () {}, 1000);
