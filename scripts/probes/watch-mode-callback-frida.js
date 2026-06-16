// Usage:
//   frida -U SpringBoard -l scripts/probes/watch-mode-callback-frida.js
//
// Notes:
//   Keep the Frida session interactive. Do not pass -q, because -q exits after
//   the script is loaded and invalidates the dynamically registered listener.
//   Before exiting, run rpc.exports.cleanup() and wait for the
//   "listener unregistered" log.

if (!ObjC.available) {
    throw new Error("Objective-C runtime is unavailable");
}

const listenerName = ObjC.classes.NSString.stringWithString_("libactivator.frida.mode-callback");

function stringFromArgument(value) {
    if (value === null || value === undefined) {
        return null;
    }

    try {
        return new ObjC.Object(value).toString();
    } catch (_) {
        return null;
    }
}

const Listener = ObjC.registerClass({
    name: "LAFridaModeChangeListener",
    super: ObjC.classes.NSObject,
    methods: {
        "- activator:didChangeToEventMode:": {
            retType: "void",
            argTypes: ["object", "object"],
            implementation() {
                const mode = stringFromArgument(arguments[3]) || stringFromArgument(arguments[1]) || "<unknown>";
                console.log("[mode-callback] " + mode);
            },
        },
    },
});

const listener = Listener.alloc().init();

globalThis.listener = listener;
globalThis.listenerName = listenerName;

ObjC.schedule(ObjC.mainQueue, function () {
    const activator = ObjC.classes.LAActivator.sharedInstance();
    globalThis.activator = activator;
    activator.registerListener_forName_(listener, listenerName);
    console.log("[mode-callback] listener registered");
});

rpc.exports = {
    cleanup() {
        ObjC.schedule(ObjC.mainQueue, function () {
            if (globalThis.activator) {
                globalThis.activator.unregisterListenerWithName_(globalThis.listenerName);
                console.log("[mode-callback] listener unregistered");
            }
        });
    },
};

setInterval(function () {}, 1000);
