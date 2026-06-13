// frida -U -n SpringBoard -l scripts/probes/probe-home-button-type.js

"use strict";

if (!ObjC.available) {
    console.log("Objective-C runtime is unavailable");
    throw new Error("Objective-C runtime is unavailable");
}

function findGlobalExport(name) {
    if (typeof Module.getGlobalExportByName === "function") {
        try {
            return Module.getGlobalExportByName(name);
        } catch (_) {}
    }

    if (typeof Module.findGlobalExportByName === "function") {
        const address = Module.findGlobalExportByName(name);
        if (address) {
            return address;
        }
    }

    if (typeof Module.findExportByName === "function") {
        const address = Module.findExportByName(null, name);
        if (address) {
            return address;
        }
    }

    return null;
}

function findModuleExport(moduleName, exportName) {
    try {
        const module = Process.getModuleByName(moduleName);
        if (typeof module.findExportByName === "function") {
            const address = module.findExportByName(exportName);
            if (address) {
                return address;
            }
        }
        if (typeof module.getExportByName === "function") {
            return module.getExportByName(exportName);
        }
    } catch (_) {}

    if (typeof Module.findExportByName === "function") {
        return Module.findExportByName(moduleName, exportName);
    }

    return null;
}

function findMobileGestaltExport(name) {
    const globalExport = findGlobalExport(name);
    if (globalExport) {
        return globalExport;
    }

    return findModuleExport("MobileGestalt", name);
}

const mg = findMobileGestaltExport("MGCopyAnswer");
const mgBool = findMobileGestaltExport("MGGetBoolAnswer");

function nsString(value) {
    return ObjC.classes.NSString.stringWithString_(value);
}

function describeCF(value) {
    if (value.isNull()) {
        return "null";
    }
    try {
        const obj = new ObjC.Object(value);
        return `${obj.$className}: ${obj.toString()}`;
    } catch (_) {
        return `ptr(${value})`;
    }
}

if (!mg) {
    console.log("MGCopyAnswer not found");
} else {
    const MGCopyAnswer = new NativeFunction(mg, "pointer", ["pointer"]);
    for (const key of ["HomeButtonType", "real-home-button", "fake-home-button"]) {
        const value = MGCopyAnswer(nsString(key));
        console.log(`MGCopyAnswer(${key}) = ${describeCF(value)}`);
    }
}

if (!mgBool) {
    console.log("MGGetBoolAnswer not found");
} else {
    const MGGetBoolAnswer = new NativeFunction(mgBool, "bool", ["pointer"]);
    for (const key of ["real-home-button", "fake-home-button"]) {
        console.log(`MGGetBoolAnswer(${key}) = ${MGGetBoolAnswer(nsString(key))}`);
    }
}
