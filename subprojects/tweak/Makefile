TARGET := iphone:clang:16.5:15.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := ActivatorTweak
TWEAK_NAME += ActivatorAppTweak

ActivatorTweak_FILES += ActivatorTweak.m
ActivatorTweak_FILES += LATBuiltInRegistry.m
ActivatorTweak_FILES += $(wildcard applications/*.m)
ActivatorTweak_FILES += $(wildcard events/core/*.m)
ActivatorTweak_FILES += $(wildcard events/definitions/*.m)
ActivatorTweak_FILES += $(wildcard events/recognizers/*.m)
ActivatorTweak_FILES += $(wildcard events/sources/*.m)
ActivatorTweak_FILES += $(wildcard listeners/*.m)
ActivatorTweak_FILES += $(wildcard listeners/compose/*.m)
ActivatorTweak_FILES += $(wildcard listeners/hardware/*.m)
ActivatorTweak_FILES += $(wildcard listeners/system/*.m)
ActivatorTweak_FILES += $(wildcard listeners/telephony/*.m)
ActivatorTweak_FILES += $(wildcard runtime/*.m)

ActivatorTweak_CFLAGS += -fobjc-arc
ActivatorTweak_CFLAGS += -I.
ActivatorTweak_CFLAGS += -Iapplications
ActivatorTweak_CFLAGS += -Ievents/core
ActivatorTweak_CFLAGS += -Ievents/definitions
ActivatorTweak_CFLAGS += -Ievents/recognizers
ActivatorTweak_CFLAGS += -Ievents/sources
ActivatorTweak_CFLAGS += -Ilisteners
ActivatorTweak_CFLAGS += -Iprivate

ifeq ($(LIBACTIVATOR_TEST_SUPPORT),1)
ActivatorTweak_CFLAGS += -DLIBACTIVATOR_TEST_SUPPORT=1
endif
ActivatorTweak_CFLAGS += -Iruntime
ActivatorTweak_CFLAGS += -I../../include
ActivatorTweak_CFLAGS += -I../libactivator

ifeq ($(DEBUG),1)
ActivatorTweak_CFLAGS += -DDEBUG=1
endif

ActivatorTweak_FRAMEWORKS += Foundation
ActivatorTweak_FRAMEWORKS += AudioToolbox
ActivatorTweak_FRAMEWORKS += CoreServices
ActivatorTweak_FRAMEWORKS += CoreTelephony
ActivatorTweak_FRAMEWORKS += Network
ActivatorTweak_FRAMEWORKS += UIKit

ActivatorTweak_LIBRARIES += activator

ActivatorTweak_PRIVATE_FRAMEWORKS += BackBoardServices
ActivatorTweak_PRIVATE_FRAMEWORKS += IOKit
ActivatorTweak_PRIVATE_FRAMEWORKS += MediaRemote
ActivatorTweak_PRIVATE_FRAMEWORKS += SpringBoardServices

ActivatorAppTweak_FILES += ActivatorAppTweak.m
ActivatorAppTweak_CFLAGS += -fobjc-arc
ActivatorAppTweak_CFLAGS += -I.
ActivatorAppTweak_CFLAGS += -I../../include
ActivatorAppTweak_FRAMEWORKS += Foundation
ActivatorAppTweak_FRAMEWORKS += UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
