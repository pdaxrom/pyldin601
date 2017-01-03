#!/bin/bash

export PATH=${HOME}/bin/jdk1.6.0_32/bin:$PATH

if [ "$1" = "install" ]; then

    adb uninstall com.pdaxrom.pyldin601
    adb install bin/pyldin601-debug.apk

elif [ "$1" = "clean" ]; then

    ${HOME}/Android/android-ndk/ndk-build distclean
    ant clean

    rm -rf assets/Bios
    rm -rf assets/Rom
    rm -rf assets/shaders

    rm -f AndroidManifest.xml
    rm -rf libs obj

elif [ "$1" = "release" ]; then

    if [ ! -f AndroidManifest.xml ]; then

	svn update ..

	VERSION_NAME=$(cat ../VERSION)-$(LANG=en_US svn info .. 2>&1 | grep Revision | awk '{print $2}')

	cp AndroidManifest.xml.in AndroidManifest.xml
	sed -i -e "s|@VERSION_NAME@|${VERSION_NAME}|" AndroidManifest.xml

    fi

    if [ ! -d assets/Rom ]; then
	mkdir -p assets/Rom
	cp -R ../../native/RAMROMDiskPipnet/rom*.roz assets/Rom/
    fi

    test -d assets/Bios    || cp -R ../../native/Bios assets/
    test -d assets/shaders || cp -R ../shaders assets/

    ${HOME}/Android/android-ndk/ndk-build -j8
    ant release

else

    if [ ! -f AndroidManifest.xml ]; then

	svn update ..

	VERSION_NAME=$(cat ../VERSION)-$(LANG=en_US svn info .. 2>&1 | grep Revision | awk '{print $2}')

	cp AndroidManifest.xml.in AndroidManifest.xml
	sed -i -e "s|@VERSION_NAME@|${VERSION_NAME}|" AndroidManifest.xml

    fi

    if [ ! -d assets/Rom ]; then
	mkdir -p assets/Rom
	cp -R ../../native/RAMROMDiskPipnet/rom*.roz assets/Rom/
    fi

    test -d assets/Bios    || cp -R ../../native/Bios assets/
    test -d assets/shaders || cp -R ../shaders assets/

    NDK_DEBUG=1 ${HOME}/Android/android-ndk/ndk-build -j8
    ant debug

fi
