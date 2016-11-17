TARGET = pyldin
PREFIX = /usr
BINDIR = $(PREFIX)/bin
DATADIR= $(PREFIX)/share

UNIBIOSONLY=no

VERSION=3.4
EXTRAVERSION=$(shell LANG=en_US svn info 2>&1 | grep Revision | awk '{print $$2}')
DATE=$(shell LANG=en_US date -R)

all:	$(TARGET)

CC := gcc
CXX := g++
OPT_FLAGS := -g -Ofast -fomit-frame-pointer
#OPT_STRIP := -s
CFLAGS = -Wall $(OPT_FLAGS) -Isrc/core -Isrc $(shell sdl2-config --cflags) $(shell pkg-config libpng --cflags) $(EXTRA_CFLAGS)
CFLAGS += -DDATADIR=\"$(DATADIR)/pyldin\" -DVERSION=\"$(VERSION)-$(EXTRAVERSION)\"
CFLAGS += -DPYLDIN_LOGO -DPYLDIN_ICON -DUSE_JOYSTICK

ifeq (opengl, $(VIDEO))
VIDEOLIB = -lGL
else
CFLAGS += -DUSE_GLES2
VIDEOLIB = -lGLESv2 -lEGL
endif

CXXFLAGS = $(CFLAGS) -fno-exceptions -fno-rtti
LDFLAGS = $(OPT_LIBS) $(shell sdl2-config --libs) -lSDL2_image $(shell pkg-config libpng --libs) $(VIDEOLIB) -lz $(OPT_STRIP) -g

##########################
#CFLAGS += -DPYLDIN_LOGO -DPYLDIN_ICON
#CXXFLAGS += -DPYLDIN_LOGO -DPYLDIN_ICON
#LDFLAGS += -lSDL_image -ljpeg -lpng
##########################

#OBJS  = src/core/devices.o src/core/floppy.o src/core/keyboard.o src/core/mc6800.o src/core/swiemu.o src/core/mc6845.o src/core/i8272.o
OBJS  = src/core/core.o
OBJS += src/discs.o src/screen.o src/sshot.o src/floppymanager.o src/pyldin-sdl2.o src/shader.o

ifeq (alsa, $(SOUND))
OBJS += src/wave-alsa.o
CFLAGS += -DUSE_ALSA=1
CXXFLAGS += -DUSE_ALSA=1
LDFLAGS += -lasound
else
OBJS += src/wave.o
endif

$(TARGET): $(OBJS)
	$(CC) -o $@ $(OBJS) $(LDFLAGS)

clean:
	rm -f $(OBJS) $(TARGET)

distclean: clean

install:
	mkdir -p $(DESTDIR)$(DATADIR)/pyldin/Rom
	mkdir -p $(DESTDIR)$(DATADIR)/pyldin/Floppy
	mkdir -p $(DESTDIR)$(DATADIR)/pyldin/Bios
	cp -f ../native/Bios/*.roz			$(DESTDIR)$(DATADIR)/pyldin/Bios/
	cp -f ../native/Floppy/*.imz			$(DESTDIR)$(DATADIR)/pyldin/Floppy/
ifeq (yes, $(UNIBIOSONLY))
	cp -f ../native/Rom/str*.roz			$(DESTDIR)$(DATADIR)/pyldin/Rom/
else
	cp -f ../native/RAMROMDiskPipnet/rom*.roz	$(DESTDIR)$(DATADIR)/pyldin/Rom/
endif
	mkdir -p $(DESTDIR)$(BINDIR)
	install -m 755 $(TARGET)      $(DESTDIR)$(BINDIR)
	install -m 755 pyldin-fb      $(DESTDIR)$(BINDIR)
	mkdir -p $(DESTDIR)$(DATADIR)/applications
	mkdir -p $(DESTDIR)$(DATADIR)/pixmaps
	install -m 644 pyldin.desktop $(DESTDIR)$(DATADIR)/applications
	install -m 644 pyldin.png     $(DESTDIR)$(DATADIR)/pixmaps

package:
	cp debian/changelog.in debian/changelog
	sed -i -e "s|@VERSION@|${VERSION}-${EXTRAVERSION}|" debian/changelog
	sed -i -e "s|@DATE@|${DATE}|" debian/changelog
	dpkg-buildpackage -rfakeroot -b -tc || true
	rm -f debian/changelog debian/files debian/pyldin601.debhelper.log debian/pyldin601.substvars
	rm -rf debian/pyldin601
