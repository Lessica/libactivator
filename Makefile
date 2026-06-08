TARGET := iphone:clang:16.5:15.0
ARCHS := arm64 arm64e
INSTALL_TARGET_PROCESSES := SpringBoard

include $(THEOS)/makefiles/common.mk

SUBPROJECTS += subprojects/libactivator
SUBPROJECTS += subprojects/libactivatorsettings
SUBPROJECTS += subprojects/tweak
SUBPROJECTS += subprojects/preferences
SUBPROJECTS += subprojects/app

include $(THEOS_MAKE_PATH)/aggregate.mk

export THEOS_STAGING_DIR
internal-stage::
	$(ECHO_NOTHING)scripts/stage-public-headers.sh$(ECHO_END)

ifeq ($(LA_TESTING),1)
after-stage::
	$(ECHO_NOTHING)$(MAKE) -C tests commands stage LA_TESTING=1$(ECHO_END)
endif

include $(THEOS_MAKE_PATH)/package.mk
