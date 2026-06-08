TARGET := iphone:clang:16.5:15.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME := libactivator

libactivator_FILES += LAConstants.m
libactivator_FILES += LAEvent.m
libactivator_FILES += LAListenerDefaults.m
libactivator_FILES += LAEventDataSourceDefaults.m
libactivator_FILES += LAActivatorPersistence.m
libactivator_FILES += LAActivatorBackend.m
libactivator_FILES += LAActivatorResourceManager.m
libactivator_FILES += LAListenerMetadataCache.m
libactivator_FILES += LAActivatorUnlockService.m
libactivator_FILES += LAActivatorRuntimeStateProvider.m
libactivator_FILES += LATouchActivityTracker.m
libactivator_FILES += LADefaultEventDataSource.m
libactivator_FILES += LAActivatorIPC.m
libactivator_FILES += LAActivatorIPCCodec.m
libactivator_FILES += LAActivatorIPCClient.m
libactivator_FILES += LAActivatorIPCServer.m
libactivator_FILES += LARemoteListener.m
libactivator_FILES += LAActivator.m
libactivator_FILES += LASettingsShims.m
libactivator_FILES += UIImageView+Activator.m

libactivator_CFLAGS += -fobjc-arc
libactivator_CFLAGS += -I../../include

ifeq ($(LA_TESTING),1)
libactivator_FILES += LAActivatorTestSupport.m
libactivator_CFLAGS += -DLA_TESTING=1
libactivator_PRIVATE_FRAMEWORKS += IOKit
endif

libactivator_FRAMEWORKS += Foundation
libactivator_FRAMEWORKS += UIKit
libactivator_FRAMEWORKS += CoreGraphics

libactivator_PRIVATE_FRAMEWORKS += AppSupport

libactivator_INSTALL_PATH := /usr/lib

include $(THEOS_MAKE_PATH)/library.mk
