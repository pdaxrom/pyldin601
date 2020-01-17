SYSTEM := $(shell uname)

PATH := $(PWD)/tmpinst/bin:$(PATH)
PKG_CONFIG_PATH := $(PWD)/tmpinst/lib/pkgconfig

#include ../../Makefile.flags

CFG_FLAGS :=

ifeq (mingw, $(SYSTEM))
OPT_FLAGS := CPPFLAGS="-I$(PWD)/tmpinst/include" LDFLAGS="-L$(PWD)/tmpinst/lib -static-libgcc -static-libstdc++ -Wl,-Bstatic -lstdc++ -lpthread -Wl,-Bdynamic"
CFG_FLAGS := --host=i686-w64-mingw32
CC := i686-w64-mingw32-gcc
else
OPT_FLAGS := CPPFLAGS="-I$(PWD)/tmpinst/include" LDFLAGS="-L$(PWD)/tmpinst/lib"
endif

ifeq (Darwin, $(SYSTEM))
OPT_FLAGS := CPPFLAGS="$(SDK_FLAGS)" LDFLAGS="$(SDK_FLAGS)"
endif

all: libsdl libsdl_image

SDL/.inited:
	cd SDL && \
	git submodule update --init --recursive && \
	./autogen.sh && \
	touch .inited

SDL/.configured: SDL/.inited
	cd SDL && \
	git submodule update --init --recursive && \
	./configure $(CFG_FLAGS) --prefix=$(PWD)/tmpinst $(OPT_FLAGS) && \
	touch .configured

SDL/.compiled: SDL/.configured
	cd SDL && \
	make -j && \
	touch .compiled

SDL/.installed: SDL/.compiled
	cd SDL && \
	make install && \
	touch .installed

clean_SDL: SDL/.configured
	cd SDL && \
	make clean

libsdl: SDL/.installed

SDL_image/.inited: SDL/.installed addon_libs
	cd SDL_image && \
	git submodule update --init --recursive && \
	./autogen.sh && \
	touch .inited

SDL_image/.configured: SDL_image/.inited
	cd SDL_image && \
	git submodule update --init --recursive && \
	./configure $(CFG_FLAGS) --prefix=$(PWD)/tmpinst --disable-sdltest $(OPT_FLAGS) && \
	touch .configured

SDL_image/.compiled: SDL_image/.configured
	cd SDL_image && \
	make -j && \
	touch .compiled

SDL_image/.installed: SDL_image/.compiled
	cd SDL_image && \
	make install && \
	touch .installed

clean_SDL_image: SDL_image/.configured
	cd SDL_image && \
	make clean

libsdl_image: SDL_image/.installed

addon_libs:
	make -f Makefile.component \
	    CC=$(CC) \
	    SYSTEM=$(SYSTEM) \
	    TARGET=SDL_image/external/zlib-1.2.11 \
	    OPT_FLAGS="--static" \
	    all
	make -f Makefile.component \
	    SYSTEM=$(SYSTEM) \
	    TARGET=SDL_image/external/libpng-1.6.37 \
	    OPT_FLAGS="$(CFG_FLAGS) --disable-shared --enable-static CPPFLAGS=\"-I$$PWD/tmpinst/include\" LDFLAGS=\"-I$$PWD/tmpinst/lib\" LIBS=\"-lz -lm\"" \
	    all
	make -f Makefile.component \
	    SYSTEM=$(SYSTEM) \
	    TARGET=SDL_image/external/jpeg-9c \
	    OPT_FLAGS="$(CFG_FLAGS) --disable-shared --enable-static CPPFLAGS=\"-I$$PWD/tmpinst/include\" LDFLAGS=\"-I$$PWD/tmpinst/lib\" LIBS=\"-lz -lm\"" \
	    all
	make -f Makefile.component \
	    SYSTEM=$(SYSTEM) \
	    TARGET=SDL_image/external/tiff-4.1.0 \
	    OPT_FLAGS="$(CFG_FLAGS) --disable-shared --enable-static CPPFLAGS=\"-I$$PWD/tmpinst/include\" LDFLAGS=\"-I$$PWD/tmpinst/lib\" LIBS=\"-lz -lm\"" \
	    all
	make -f Makefile.component \
	    SYSTEM=$(SYSTEM) \
	    TARGET=SDL_image/external/libwebp-1.0.3 \
	    OPT_FLAGS="$(CFG_FLAGS) --disable-shared --enable-static CPPFLAGS=\"-I$$PWD/tmpinst/include\" LDFLAGS=\"-I$$PWD/tmpinst/lib\" LIBS=\"-lz -lm\"" \
	    all

clean_addon_libs:
	make -f Makefile.component \
	    TARGET=SDL_image/external/zlib-1.2.11 \
	    distclean
	make -f Makefile.component \
	    TARGET=SDL_image/external/libpng-1.6.37 \
	    distclean
	make -f Makefile.component \
	    TARGET=SDL_image/external/jpeg-9c \
	    distclean
	make -f Makefile.component \
	    TARGET=SDL_image/external/tiff-4.1.0 \
	    distclean
	make -f Makefile.component \
	    TARGET=SDL_image/external/libwebp-1.0.3 \
	    distclean

clean: clean_SDL clean_SDL_image

distclean:
	rm -rf tmpinst
	cd SDL && \
	git clean -f -d && \
	git checkout -- .
	cd SDL_image && \
	git clean -f -d && \
	git checkout -- .
