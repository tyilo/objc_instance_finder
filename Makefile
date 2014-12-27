export TARGET=macosx:clang
ARCHS = x86_64

# Disable dpkg
override PACKAGE_FORMAT := none
include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = objc_instance_finder
objc_instance_finder_FILES = objc_instance_finder.m

# This requires a modified version of theos
objc_instance_finder_LINKAGE = static

include $(THEOS_MAKE_PATH)/library.mk
