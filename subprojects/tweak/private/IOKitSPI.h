//
//  IOKitSPI.h
//  libactivator
//
//  Created by Lessica on 6/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifndef LA_IOKIT_SPI_H
#define LA_IOKIT_SPI_H

#ifdef __cplusplus
extern "C" {
#endif

typedef double IOHIDFloat;

typedef uint32_t IOHIDEventField;
typedef uint32_t IOHIDEventOptionBits;
typedef uint32_t IOHIDEventType;
typedef uint32_t IOHIDDigitizerEventMask;
typedef uint32_t IOHIDDigitizerTransducerType;
typedef UInt32 IOOptionBits;

typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;

#define IOHIDEventFieldBase(type) ((type) << 16)

enum {
    kIOHIDEventOptionNone = 0,
};

enum {
    kHIDPage_KeyboardOrKeypad = 0x07,
    kHIDPage_Telephony = 0x0B,
    kHIDPage_Consumer = 0x0C,
    kHIDPage_VendorDefinedStart = 0xFF00,
};

enum {
    kHIDUsage_Telephony_Mute = 0x2E,
};

enum {
    kHIDUsage_Csmr_Power = 0x30,
    kHIDUsage_Csmr_Menu = 0x40,
    kHIDUsage_Csmr_Snapshot = 0x65,
    kHIDUsage_Csmr_DisplayBrightnessIncrement = 0x6F,
    kHIDUsage_Csmr_DisplayBrightnessDecrement = 0x70,
    kHIDUsage_Csmr_Play = 0xB0,
    kHIDUsage_Csmr_Pause = 0xB1,
    kHIDUsage_Csmr_FastForward = 0xB3,
    kHIDUsage_Csmr_Rewind = 0xB4,
    kHIDUsage_Csmr_ScanNextTrack = 0xB5,
    kHIDUsage_Csmr_ScanPreviousTrack = 0xB6,
    kHIDUsage_Csmr_Stop = 0xB7,
    kHIDUsage_Csmr_Eject = 0xB8,
    kHIDUsage_Csmr_StopOrEject = 0xCC,
    kHIDUsage_Csmr_PlayOrPause = 0xCD,
    kHIDUsage_Csmr_Mute = 0xE2,
    kHIDUsage_Csmr_VolumeIncrement = 0xE9,
    kHIDUsage_Csmr_VolumeDecrement = 0xEA,
    kHIDUsage_Csmr_ALKeyboardLayout = 0x1AE,
    kHIDUsage_Csmr_ACSearch = 0x221,
    kHIDUsage_Csmr_ACLock = 0x26B,
    kHIDUsage_Csmr_ACUnlock = 0x26C,
};

enum {
    kIOHIDDigitizerEventRange = 1 << 0,
    kIOHIDDigitizerEventTouch = 1 << 1,
    kIOHIDDigitizerEventPosition = 1 << 2,
    kIOHIDDigitizerEventIdentity = 1 << 5,
    kIOHIDDigitizerEventAttribute = 1 << 6,
    kIOHIDDigitizerEventCancel = 1 << 7,
    kIOHIDDigitizerEventStart = 1 << 8,
    kIOHIDDigitizerEventEstimatedAltitude = 1 << 28,
    kIOHIDDigitizerEventEstimatedAzimuth = 1 << 29,
    kIOHIDDigitizerEventEstimatedPressure = 1 << 30,
    kIOHIDDigitizerEventSwipeUp = 0x01000000,
    kIOHIDDigitizerEventSwipeDown = 0x02000000,
    kIOHIDDigitizerEventSwipeLeft = 0x04000000,
    kIOHIDDigitizerEventSwipeRight = 0x08000000,
    kIOHIDDigitizerEventSwipeMask = 0xFF000000,
};

enum {
    kIOHIDEventTypeNULL,
    kIOHIDEventTypeVendorDefined,
    kIOHIDEventTypeKeyboard = 3,
    kIOHIDEventTypeRotation = 5,
    kIOHIDEventTypeScroll = 6,
    kIOHIDEventTypeZoom = 8,
    kIOHIDEventTypeDigitizer = 11,
    kIOHIDEventTypeBiometric = 14,
    kIOHIDEventTypeNavigationSwipe = 16,
    kIOHIDEventTypeTouchID = 29,
    kIOHIDEventTypeForce = 32,
};

enum {
    kIOHIDEventFieldIsRelative = IOHIDEventFieldBase(kIOHIDEventTypeNULL),
    kIOHIDEventFieldIsCollection,
    kIOHIDEventFieldIsPixelUnits,
    kIOHIDEventFieldIsCenterOrigin,
    kIOHIDEventFieldIsBuiltIn,
};

enum {
    kIOHIDEventFieldKeyboardUsagePage = IOHIDEventFieldBase(kIOHIDEventTypeKeyboard),
    kIOHIDEventFieldKeyboardUsage,
    kIOHIDEventFieldKeyboardDown,
    kIOHIDEventFieldKeyboardRepeat,
};

enum {
    kIOHIDEventFieldDigitizerX = IOHIDEventFieldBase(kIOHIDEventTypeDigitizer),
    kIOHIDEventFieldDigitizerY,
    kIOHIDEventFieldDigitizerZ,
    kIOHIDEventFieldDigitizerType = kIOHIDEventFieldDigitizerX + 4,
    kIOHIDEventFieldDigitizerIndex,
    kIOHIDEventFieldDigitizerIdentity,
    kIOHIDEventFieldDigitizerEventMask,
    kIOHIDEventFieldDigitizerRange,
    kIOHIDEventFieldDigitizerTouch,
    kIOHIDEventFieldDigitizerPressure,
    kIOHIDEventFieldDigitizerBarrelPressure,
    kIOHIDEventFieldDigitizerTwist,
    kIOHIDEventFieldDigitizerMajorRadius = kIOHIDEventFieldDigitizerX + 20,
    kIOHIDEventFieldDigitizerMinorRadius,
    kIOHIDEventFieldDigitizerIsDisplayIntegrated = kIOHIDEventFieldDigitizerMajorRadius + 5,
};

enum {
    kIOHIDEventFieldTouchIDPresence = IOHIDEventFieldBase(kIOHIDEventTypeTouchID),
    kIOHIDEventFieldTouchIDTouchDown,
    kIOHIDEventFieldTouchIDSequenceState = IOHIDEventFieldBase(kIOHIDEventTypeTouchID) + 4,
};

enum {
    kIOHIDDigitizerTransducerTypeStylus = 0,
    kIOHIDDigitizerTransducerTypeFinger = 2,
    kIOHIDDigitizerTransducerTypeHand = 3,
};

IOHIDEventRef IOHIDEventCreateDigitizerEvent(CFAllocatorRef allocator, uint64_t timeStamp,
                                             IOHIDDigitizerTransducerType type, uint32_t index, uint32_t identity,
                                             IOHIDDigitizerEventMask eventMask, uint32_t buttonMask, IOHIDFloat x,
                                             IOHIDFloat y, IOHIDFloat z, IOHIDFloat tipPressure, IOHIDFloat twist,
                                             Boolean range, Boolean touch, IOOptionBits options);
IOHIDEventRef IOHIDEventCreateDigitizerFingerEvent(CFAllocatorRef allocator, uint64_t timeStamp, uint32_t index,
                                                   uint32_t identity, IOHIDDigitizerEventMask eventMask, IOHIDFloat x,
                                                   IOHIDFloat y, IOHIDFloat z, IOHIDFloat tipPressure, IOHIDFloat twist,
                                                   Boolean range, Boolean touch, IOHIDEventOptionBits options);
IOHIDEventRef IOHIDEventCreateKeyboardEvent(CFAllocatorRef allocator, uint64_t timeStamp, uint32_t usagePage,
                                            uint32_t usage, Boolean down, IOOptionBits options);

IOHIDEventType IOHIDEventGetType(IOHIDEventRef event);
CFArrayRef IOHIDEventGetChildren(IOHIDEventRef event);
CFIndex IOHIDEventGetIntegerValue(IOHIDEventRef event, IOHIDEventField field);
void IOHIDEventSetIntegerValue(IOHIDEventRef event, IOHIDEventField field, CFIndex value);
IOHIDFloat IOHIDEventGetFloatValue(IOHIDEventRef event, IOHIDEventField field);
void IOHIDEventSetFloatValue(IOHIDEventRef event, IOHIDEventField field, IOHIDFloat value);
uint64_t IOHIDEventGetSenderID(IOHIDEventRef event);
void IOHIDEventSetSenderID(IOHIDEventRef event, uint64_t senderID);
void IOHIDEventAppendEvent(IOHIDEventRef event, IOHIDEventRef childEvent, IOOptionBits options);

IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
void IOHIDEventSystemClientDispatchEvent(IOHIDEventSystemClientRef client, IOHIDEventRef event);

#ifdef __cplusplus
}
#endif

#endif
