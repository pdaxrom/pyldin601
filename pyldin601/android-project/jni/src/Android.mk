LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE := main

SDL_PATH := ../SDL

LOCAL_C_INCLUDES := $(LOCAL_PATH)/$(SDL_PATH)/include

LOCAL_SRC_FILES := 			\
    $(SDL_PATH)/src/main/android/SDL_android_main.c \
    ../../../src/core/core.c		\
    ../../../src/discs.c		\
    ../../../src/screen.c		\
    ../../../src/floppymanager.c	\
    ../../../src/wave.c			\
    ../../../src/pyldin-sdl2.c

#    ../../../src/gui.c

ifndef PYLDIN_VERSION
PYLDIN_VERSION := 0.0.0
endif

LOCAL_C_INCLUDES += \
    $(LOCAL_PATH)/../../../src/core \
    $(LOCAL_PATH)/../../../src

LOCAL_CFLAGS := -Wall -g -Ofast -fomit-frame-pointer -DVERSION=\"$(PYLDIN_VERSION)\"
# -DUSE_GUI

LOCAL_LDLIBS := -lGLESv2 -lz -llog

LOCAL_SHARED_LIBRARIES := SDL2
# SDL2_gfx

include $(BUILD_SHARED_LIBRARY)
