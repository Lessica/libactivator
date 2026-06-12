// Usage:
//   frida -U SpringBoard -l scripts/probes/probe-wifi-status-frida.js
//
// Purpose:
//   Validate whether the legacy Activator Wi-Fi event source signals still work
//   on modern iOS. The probe reads SBWiFiManager state, observes the legacy
//   SpringBoard Wi-Fi notification, and hooks the same SBWiFiManager methods
//   used by Activator 1.9.13.
//
// Notes:
//   Keep the Frida session interactive. Do not pass -q.

"use strict";

if (!ObjC.available) {
    throw new Error("Objective-C runtime is unavailable");
}

function describeObject(value) {
    if (value === null || value === undefined) {
        return "nil";
    }

    try {
        if (value.isNull && value.isNull()) {
            return "nil";
        }
    } catch (_) {}

    try {
        return new ObjC.Object(value).toString();
    } catch (_) {
        try {
            return value.toString();
        } catch (_) {
            return String(value);
        }
    }
}

function callNoArgObject(instance, selectorName) {
    try {
        if (!instance || !instance[selectorName]) {
            return "<missing>";
        }
        return describeObject(instance[selectorName]());
    } catch (error) {
        return "<error: " + error + ">";
    }
}

function callNoArgBool(instance, selectorName) {
    try {
        if (!instance || !instance[selectorName]) {
            return "<missing>";
        }
        return instance[selectorName]() ? "YES" : "NO";
    } catch (error) {
        return "<error: " + error + ">";
    }
}

function managerInstance() {
    const Manager = ObjC.classes.SBWiFiManager;
    if (!Manager) {
        return null;
    }

    const selectors = ["sharedInstance", "sharedWiFiManager", "sharedManager"];
    for (const selector of selectors) {
        if (Manager["+ " + selector]) {
            try {
                const value = Manager[selector]();
                if (value) {
                    return value;
                }
            } catch (error) {
                console.log("[wifi-probe] " + selector + " failed: " + error);
            }
        }
    }

    return null;
}

function logState(reason) {
    ObjC.schedule(ObjC.mainQueue, function () {
        const manager = managerInstance();
        if (!manager) {
            console.log("[wifi-probe] " + reason + " SBWiFiManager unavailable");
            return;
        }

        const currentNetworkName = callNoArgObject(manager, "currentNetworkName");
        const wiFiEnabled = callNoArgBool(manager, "wiFiEnabled");
        const associated = callNoArgBool(manager, "isAssociated");
        const powered = callNoArgBool(manager, "power");
        console.log(
            "[wifi-probe] " +
                reason +
                " currentNetworkName=" +
                currentNetworkName +
                " wiFiEnabled=" +
                wiFiEnabled +
                " isAssociated=" +
                associated +
                " power=" +
                powered
        );
    });
}

function hookInstanceMethod(className, selectorName) {
    const klass = ObjC.classes[className];
    if (!klass || !klass["- " + selectorName]) {
        console.log("[wifi-probe] missing " + className + " -" + selectorName);
        return;
    }

    Interceptor.attach(klass["- " + selectorName].implementation, {
        onEnter() {
            console.log("[wifi-probe] " + className + " -" + selectorName + " enter");
        },
        onLeave() {
            logState(className + " -" + selectorName + " leave");
        },
    });
    console.log("[wifi-probe] hooked " + className + " -" + selectorName);
}

function logRelevantMethods(className) {
    const klass = ObjC.classes[className];
    if (!klass) {
        return;
    }

    const pattern = /(shared|network|wi.?fi|ssid|link|current|associated|power|enabled|update)/i;
    console.log("[wifi-probe] relevant " + className + " methods");
    klass.$ownMethods
        .filter(function (name) {
            return pattern.test(name);
        })
        .sort()
        .forEach(function (name) {
            console.log("[wifi-probe]   " + name);
        });
}

function observeNotification(notificationName) {
    const Observer = ObjC.registerClass({
        name: "LAFridaWiFiStatusObserver",
        super: ObjC.classes.NSObject,
        methods: {
            "- handleNotification:": {
                retType: "void",
                argTypes: ["object"],
                implementation(self, _cmd, notification) {
                    console.log("[wifi-probe] notification " + describeObject(notification));
                    logState(String(notificationName));
                },
            },
        },
    });

    const observer = Observer.alloc().init();
    globalThis.wifiStatusObserver = observer;

    ObjC.classes.NSNotificationCenter.defaultCenter().addObserver_selector_name_object_(
        observer,
        ObjC.selector("handleNotification:"),
        ObjC.classes.NSString.stringWithString_(notificationName),
        NULL
    );
    console.log("[wifi-probe] observing " + notificationName);
}

console.log("[wifi-probe] SBWiFiManager class=" + (ObjC.classes.SBWiFiManager ? "available" : "missing"));
logRelevantMethods("SBWiFiManager");
logState("initial");
observeNotification("SBWifiSignalStrengthChangedNotification");
hookInstanceMethod("SBWiFiManager", "_updateCurrentNetwork");
hookInstanceMethod("SBWiFiManager", "_linkDidChange");

setInterval(function () {
    logState("poll");
}, 10000);
