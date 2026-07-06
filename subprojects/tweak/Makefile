TARGET := iphone:clang:16.5:15.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := ActivatorTweak
TWEAK_NAME += ActivatorAppTweak

ActivatorTweak_FILES += ActivatorTweak.m
ActivatorTweak_FILES += LATBuiltInRegistry.m
ActivatorTweak_FILES += applications/LATApplicationCatalog.m
ActivatorTweak_FILES += applications/LATApplicationDescriptor.m
ActivatorTweak_FILES += applications/LATApplicationLauncher.m
ActivatorTweak_FILES += applications/LATApplicationListenerProvider.m
ActivatorTweak_FILES += applications/LATLockScreenCameraLauncher.m
ActivatorTweak_FILES += runtime/LATEventSourceInterestGate.m
ActivatorTweak_FILES += runtime/LATHIDEventSender.m
ActivatorTweak_FILES += runtime/LATRuntimeStateSource.m
ActivatorTweak_FILES += events/LATButtonEventSource.m
ActivatorTweak_FILES += events/LATMediaEventSource.m
ActivatorTweak_FILES += events/LATLockStateEventSource.m
ActivatorTweak_FILES += events/LATPowerStateEventSource.m
ActivatorTweak_FILES += events/LATNetworkEventSource.m
ActivatorTweak_FILES += events/LATStatusBarEventSource.m
ActivatorTweak_FILES += events/LATEdgeGestureClassifier.m
ActivatorTweak_FILES += events/LATEdgeGestureEventSource.m
ActivatorTweak_FILES += events/LATFingerprintSensorEventSource.m
ActivatorTweak_FILES += events/LATForceTouchEventSource.m
ActivatorTweak_FILES += events/LATMultiTouchGestureRecognizer.m
ActivatorTweak_FILES += events/LATMultiTouchEventSource.m
ActivatorTweak_FILES += events/LATSpringBoardIconGestureEventSource.m
ActivatorTweak_FILES += listeners/LATApplicationActionListener.m
ActivatorTweak_FILES += listeners/LATCameraActionListener.m
ActivatorTweak_FILES += listeners/LATComposeActionListener.m
ActivatorTweak_FILES += listeners/LATHardwareActionListener.m
ActivatorTweak_FILES += listeners/LATNothingListener.m
ActivatorTweak_FILES += listeners/LATTelephonyActionListener.m
ActivatorTweak_FILES += listeners/LATSystemActionListener.m
ActivatorTweak_FILES += listeners/LATURLActionListener.m
ActivatorTweak_FILES += listeners/hardware/LATHardwareActionCommand.m
ActivatorTweak_FILES += listeners/system/LATSystemActionCommand.m
ActivatorTweak_FILES += listeners/system/LATSystemAccessibilityElementController.m
ActivatorTweak_FILES += listeners/system/LATSystemAssistantController.m
ActivatorTweak_FILES += listeners/system/LATSystemCenterController.m
ActivatorTweak_FILES += listeners/system/LATSystemDictationController.m
ActivatorTweak_FILES += listeners/system/LATSystemHapticFeedbackController.m
ActivatorTweak_FILES += listeners/system/LATSystemHomeScreenController.m
ActivatorTweak_FILES += listeners/system/LATSystemLocalBackController.m
ActivatorTweak_FILES += listeners/system/LATSystemLockScreenController.m
ActivatorTweak_FILES += listeners/system/LATSystemNowPlayingApplicationLauncher.m
ActivatorTweak_FILES += listeners/system/LATSystemOrientationController.m
ActivatorTweak_FILES += listeners/system/LATSystemPowerController.m
ActivatorTweak_FILES += listeners/system/LATSystemPowerMenuController.m
ActivatorTweak_FILES += listeners/system/LATSystemPreviousApplicationController.m
ActivatorTweak_FILES += listeners/system/LATSystemReachabilityController.m
ActivatorTweak_FILES += listeners/system/LATSystemRingerMuteController.m
ActivatorTweak_FILES += listeners/system/LATSystemRingerStateResetter.m
ActivatorTweak_FILES += listeners/system/LATSystemScreenshotController.m
ActivatorTweak_FILES += listeners/system/LATSystemSwitcherController.m
ActivatorTweak_FILES += listeners/system/LATSystemVolumeHUDPresenter.m
ActivatorTweak_FILES += listeners/system/LATSystemVoiceControlController.m
ActivatorTweak_FILES += listeners/system/LATSystemWalletController.m
ActivatorTweak_FILES += listeners/compose/LATComposeActionCommand.m
ActivatorTweak_FILES += listeners/compose/LATComposeActionPresenter.m
ActivatorTweak_FILES += listeners/telephony/LATTelephonyActionCommand.m
ActivatorTweak_FILES += listeners/telephony/LATTelephonyCallController.m
ActivatorTweak_FILES += listeners/telephony/LATTelephonyCallStateObserver.m

ActivatorTweak_CFLAGS += -fobjc-arc
ActivatorTweak_CFLAGS += -I.
ActivatorTweak_CFLAGS += -Iapplications
ActivatorTweak_CFLAGS += -Ievents
ActivatorTweak_CFLAGS += -Ilisteners
ActivatorTweak_CFLAGS += -Iprivate
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
