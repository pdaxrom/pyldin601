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
    ../../../src/shader.c		\
    ../../../src/pyldin-sdl2.c

#    ../../../src/gui.c

LOCAL_CFLAGS := -DUSE_GLES2 -Wall -g -Ofast -fomit-frame-pointer -I../src/core -I../src -ISDL2/include -Ijni/SDL2_gfx/include -DVERSION=\"$(shell cat ../VERSION)-$(shell LANG=en_US svn info .. 2>&1 | grep Revision | awk '{print $$2}')\"
# -DUSE_GUI

LOCAL_LDLIBS := -lGLESv2 -lz -llog

LOCAL_SHARED_LIBRARIES := SDL2
# SDL2_gfx

include $(BUILD_SHARED_LIBRARY)
