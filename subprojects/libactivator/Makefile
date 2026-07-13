TARGET := iphone:clang:16.5:15.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME := libactivator

libactivator_FILES += LAConstants.m
libactivator_FILES += LAEvent.m
libactivator_FILES += LAApplicationAccessibility.m
libactivator_FILES += LAListenerFallbacks.m
libactivator_FILES += LAEventDataSourceFallbacks.m
libactivator_FILES += LAPersistence.m
libactivator_FILES += LALegacyBridge.m
libactivator_FILES += LAServerBackend.m
libactivator_FILES += LAResourceManager.m
libactivator_FILES += LAListenerMetadataCache.m
libactivator_FILES += LARuntimeContext.m
libactivator_FILES += LADefaultEventDataSource.m
libactivator_FILES += LAIPC.m
libactivator_FILES += LAIPCCodec.m
libactivator_FILES += LAIPCClient.m
libactivator_FILES += LAIPCServer.m
libactivator_FILES += LARemoteListener.m
libactivator_FILES += LAActivator.m
libactivator_FILES += LASettingsShims.m
libactivator_FILES += UIImageView+Activator.m

libactivator_CFLAGS += -fobjc-arc
libactivator_CFLAGS += -I../../include

ifeq ($(LIBACTIVATOR_TEST_SUPPORT),1)
libactivator_FILES += tests/LAActivatorTestSupport.m
libactivator_FILES += tests/support/LATestEnvironment.m
libactivator_FILES += tests/support/LATestRecorder.m
libactivator_FILES += tests/fakes/LATestCountingPersistence.m
libactivator_FILES += tests/fakes/LATestEventDataSource.m
libactivator_FILES += tests/fakes/LATestEventDefinitionProvider.m
libactivator_FILES += tests/fakes/LATestEventSource.m
libactivator_FILES += tests/fakes/LATestListener.m
libactivator_FILES += tests/fakes/LATestSimpleAbortListener.m
libactivator_FILES += tests/fakes/LATestTouch.m
libactivator_FILES += tests/fakes/LATestTouchEvent.m
libactivator_FILES += tests/suites/core/LATestEventSuite.m
libactivator_FILES += tests/suites/core/LATestPersistenceSuite.m
libactivator_FILES += tests/suites/core/LATestIPCCodecSuite.m
libactivator_FILES += tests/suites/core/LATestResourceSuite.m
libactivator_FILES += tests/suites/core/LATestSpringBoardCoreSuite.m
libactivator_FILES += tests/suites/core/LATestDispatchSuite.m
libactivator_FILES += tests/suites/builtins/LATestBuiltInActionRegistrySuite.m
libactivator_FILES += tests/suites/builtins/LATestBuiltInURLActionsSuite.m
libactivator_FILES += tests/suites/builtins/LATestBuiltInHardwareActionsSuite.m
libactivator_FILES += tests/suites/builtins/LATestBuiltInSystemActionsSuite.m
libactivator_FILES += tests/suites/builtins/LATestBuiltInCameraActionsSuite.m
libactivator_FILES += tests/suites/builtins/LATestBuiltInComposeActionsSuite.m
libactivator_FILES += tests/suites/builtins/LATestBuiltInTelephonyActionsSuite.m
libactivator_FILES += tests/suites/builtins/LATestBuiltInDynamicApplicationListenersSuite.m
libactivator_FILES += tests/suites/builtins/LATestBuiltInEventSourcesSuite.m
libactivator_FILES += tests/suites/builtins/LATestEventDefinitionRegistrySuite.m
libactivator_FILES += tests/suites/builtins/LATestEventSourceRegistrySuite.m
libactivator_FILES += tests/suites/builtins/LATestEventSourceModuleLoaderSuite.m
libactivator_FILES += tests/suites/runtime/LATestRuntimeInputSuite.m
libactivator_FILES += tests/suites/runtime/LATestRuntimeDeviceSuite.m
libactivator_CFLAGS += -DLIBACTIVATOR_TEST_SUPPORT=1
libactivator_CFLAGS += -I.
libactivator_CFLAGS += -Itests
libactivator_CFLAGS += -Itests/support
libactivator_CFLAGS += -Itests/fakes
libactivator_CFLAGS += -Itests/suites/core
libactivator_CFLAGS += -Itests/suites/builtins
libactivator_CFLAGS += -Itests/suites/runtime
libactivator_CFLAGS += -I../tweak/events/core
libactivator_CFLAGS += -I../tweak/events/definitions
libactivator_CFLAGS += -I../tweak/events/recognizers
libactivator_CFLAGS += -I../tweak/events/sources
libactivator_CFLAGS += -I../tweak/private
libactivator_CFLAGS += -I../tweak/runtime
endif

libactivator_FRAMEWORKS += Foundation
libactivator_FRAMEWORKS += UIKit
libactivator_FRAMEWORKS += CoreGraphics

libactivator_LIBRARIES += MobileGestalt

libactivator_PRIVATE_FRAMEWORKS += AppSupport
libactivator_PRIVATE_FRAMEWORKS += IOKit

libactivator_INSTALL_PATH := /usr/lib

include $(THEOS_MAKE_PATH)/library.mk
