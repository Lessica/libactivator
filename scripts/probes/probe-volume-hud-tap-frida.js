// Usage:
//   frida -U -n SpringBoard -l scripts/probes/probe-volume-hud-tap-frida.js
//
// Purpose:
//   Inspect SBElasticVolumeViewController lifecycle, its slider container,
//   gesture recognizers, and touch delivery while the modern Volume HUD is
//   visible. Press a volume button, then tap the HUD while this probe runs.
//
// Notes:
//   Keep the Frida session interactive. Do not pass -q.
//   This is a diagnostic probe, not a test. It does not add recognizers or
//   mutate the controller hierarchy.

"use strict";

if (!ObjC.available) {
    throw new Error("Objective-C runtime is unavailable");
}

const controllerClassName = "SBElasticVolumeViewController";
const controllerClass = ObjC.classes[controllerClassName];
const maxTouchLogs = 80;
let touchLogs = 0;
let currentController = null;
let currentRootView = null;
let currentSliderContainerView = null;

function describe(object) {
    if (object === null || object === undefined) {
        return "nil";
    }
    try {
        if (object.isNull && object.isNull()) {
            return "nil";
        }
        return new ObjC.Object(object).toString();
    } catch (error) {
        return "error:" + error;
    }
}

function objectClassName(object) {
    try {
        return new ObjC.Object(object).$className;
    } catch (error) {
        return "<unknown>";
    }
}

function callObject(object, selector) {
    try {
        if (!object || !object[selector]) {
            return null;
        }
        const value = object[selector]();
        if (!value || (value.isNull && value.isNull())) {
            return null;
        }
        return new ObjC.Object(value);
    } catch (error) {
        console.log("[volume-tap-probe] " + selector + " error: " + error);
        return null;
    }
}

function sliderContainerView(controller) {
    try {
        const ivars = controller.$ivars;
        if (!ivars || !ivars._sliderContainerView) {
            return null;
        }
        const value = ivars._sliderContainerView;
        if (!value || (value.isNull && value.isNull())) {
            return null;
        }
        return new ObjC.Object(value);
    } catch (error) {
        console.log("[volume-tap-probe] _sliderContainerView error: " + error);
        return null;
    }
}

function isSameObject(left, right) {
    if (!left || !right) {
        return false;
    }
    try {
        return left.handle.equals(right.handle);
    } catch (error) {
        return false;
    }
}

function isRelevantView(view) {
    if (!view) {
        return false;
    }
    if (isSameObject(view, currentRootView) || isSameObject(view, currentSliderContainerView)) {
        return true;
    }
    for (const ancestor of [currentSliderContainerView, currentRootView]) {
        if (!ancestor) {
            continue;
        }
        try {
            if (view["- isDescendantOfView:"] && view["- isDescendantOfView:"](ancestor)) {
                return true;
            }
        } catch (error) {
            console.log("[volume-tap-probe] descendant check error: " + error);
        }
    }
    return false;
}

function gestureRecognizerSummary(view) {
    try {
        if (!view || !view["- gestureRecognizers"]) {
            return "[]";
        }
        const recognizers = view["- gestureRecognizers"]();
        if (!recognizers || recognizers.isNull()) {
            return "[]";
        }
        const count = Number(recognizers.count());
        const parts = [];
        for (let index = 0; index < count; index++) {
            const recognizer = new ObjC.Object(recognizers.objectAtIndex_(index));
            parts.push(
                recognizer.$className +
                    "{state=" +
                    recognizer.state() +
                    ",enabled=" +
                    (recognizer.isEnabled() ? "YES" : "NO") +
                    ",cancels=" +
                    (recognizer.cancelsTouchesInView() ? "YES" : "NO") +
                    "}"
            );
        }
        return "[" + parts.join(", ") + "]";
    } catch (error) {
        return "error:" + error;
    }
}

function dumpViewTree(view, depth) {
    if (!view || depth > 4) {
        return;
    }
    let frame = "<unknown>";
    let hidden = "<unknown>";
    let alpha = "<unknown>";
    try {
        frame = view.frame().toString();
        hidden = view.isHidden() ? "YES" : "NO";
        alpha = String(view.alpha());
    } catch (error) {
        frame = "error:" + error;
    }
    console.log(
        "[volume-tap-probe] " +
            "  ".repeat(depth) +
            view.$className +
            " frame=" +
            frame +
            " hidden=" +
            hidden +
            " alpha=" +
            alpha +
            " recognizers=" +
            gestureRecognizerSummary(view)
    );
    try {
        const subviews = view.subviews();
        const count = Number(subviews.count());
        for (let index = 0; index < count; index++) {
            dumpViewTree(new ObjC.Object(subviews.objectAtIndex_(index)), depth + 1);
        }
    } catch (error) {
        console.log("[volume-tap-probe] subview traversal error: " + error);
    }
}

function inspectController(controller, reason) {
    currentController = controller;
    currentRootView = callObject(controller, "- view");
    currentSliderContainerView = sliderContainerView(controller);
    console.log(
        "[volume-tap-probe] controller " +
            reason +
            " object=" +
            controller +
            " root=" +
            describe(currentRootView) +
            " sliderContainer=" +
            describe(currentSliderContainerView)
    );
    if (currentSliderContainerView) {
        console.log(
            "[volume-tap-probe] slider recognizers=" + gestureRecognizerSummary(currentSliderContainerView)
        );
    }
    if (currentRootView) {
        dumpViewTree(currentRootView, 0);
    }
}

function attachControllerLifecycle(selector) {
    const method = controllerClass[selector];
    if (!method) {
        console.log("[volume-tap-probe] missing " + controllerClassName + " " + selector);
        return;
    }
    Interceptor.attach(method.implementation, {
        onEnter(args) {
            this.controller = new ObjC.Object(args[0]);
        },
        onLeave() {
            inspectController(this.controller, selector);
        },
    });
    console.log("[volume-tap-probe] attached " + controllerClassName + " " + selector);
}

function attachGestureRecognizerState() {
    const method = ObjC.classes.UIGestureRecognizer["- setState:"];
    if (!method) {
        console.log("[volume-tap-probe] missing UIGestureRecognizer -setState:");
        return;
    }
    Interceptor.attach(method.implementation, {
        onEnter(args) {
            if (touchLogs >= maxTouchLogs) {
                return;
            }
            const recognizer = new ObjC.Object(args[0]);
            const view = callObject(recognizer, "- view");
            if (!isRelevantView(view)) {
                return;
            }
            console.log(
                "[volume-tap-probe] recognizer=" +
                    recognizer.$className +
                    " state=" +
                    args[2].toInt32() +
                    " view=" +
                    objectClassName(view)
            );
        },
    });
}

function attachWindowTouchDelivery() {
    const method = ObjC.classes.UIWindow["- sendEvent:"];
    if (!method) {
        console.log("[volume-tap-probe] missing UIWindow -sendEvent:");
        return;
    }
    Interceptor.attach(method.implementation, {
        onEnter(args) {
            if (touchLogs >= maxTouchLogs) {
                return;
            }
            const event = new ObjC.Object(args[2]);
            let touches = null;
            try {
                touches = event.allTouches();
            } catch (error) {
                return;
            }
            if (!touches || touches.isNull()) {
                return;
            }
            const allTouches = touches.allObjects();
            const count = Number(allTouches.count());
            for (let index = 0; index < count && touchLogs < maxTouchLogs; index++) {
                const touch = new ObjC.Object(allTouches.objectAtIndex_(index));
                const view = callObject(touch, "- view");
                if (!isRelevantView(view)) {
                    continue;
                }
                let location = "<unknown>";
                try {
                    location = touch.locationInView_(currentRootView).toString();
                } catch (error) {
                    location = "error:" + error;
                }
                console.log(
                    "[volume-tap-probe] touch phase=" +
                        touch.phase() +
                        " tapCount=" +
                        touch.tapCount() +
                        " view=" +
                        objectClassName(view) +
                        " location=" +
                        location
                );
                touchLogs += 1;
            }
        },
    });
}

if (!controllerClass) {
    throw new Error(controllerClassName + " is unavailable");
}

console.log("[volume-tap-probe] class=" + controllerClassName);
console.log("[volume-tap-probe] own ivars:");
Object.keys(controllerClass.$ivars)
    .sort()
    .forEach(function (ivarName) {
        console.log("[volume-tap-probe]   " + ivarName + " : " + controllerClass.$ivars[ivarName].type);
    });
console.log("[volume-tap-probe] matching own methods:");
controllerClass.$ownMethods
    .filter(function (methodName) {
        return /view|slider|volume|appear|disappear|dismiss|present/i.test(methodName);
    })
    .sort()
    .forEach(function (methodName) {
        console.log("[volume-tap-probe]   " + methodName);
    });

for (const selector of ["- viewDidLoad", "- viewWillAppear:", "- viewDidAppear:", "- viewWillDisappear:", "- viewDidDisappear:"]) {
    attachControllerLifecycle(selector);
}
attachGestureRecognizerState();
attachWindowTouchDelivery();

ObjC.schedule(ObjC.mainQueue, function () {
    let count = 0;
    ObjC.choose(controllerClass, {
        onMatch(instance) {
            count += 1;
            inspectController(new ObjC.Object(instance), "existing-instance");
        },
        onComplete() {
            console.log("[volume-tap-probe] live instances=" + count);
            console.log("[volume-tap-probe] ready: press a volume button, then tap the Volume HUD");
        },
    });
});

setTimeout(function () {
    send({ event: "done", touchLogs: touchLogs });
    console.log("[volume-tap-probe] observation window ended touchLogs=" + touchLogs);
}, 60000);
