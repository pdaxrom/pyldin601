#!/bin/bash

if [ "$1" = "install" ]; then

    adb uninstall com.pdaxrom.pyldin601
    adb install bin/pyldin601-debug.apk

elif [ "$1" = "clean" ]; then

    /home/sash/Android/android-ndk-r10e/ndk-build distclean
    ant clean

    rm -rf assets/Bios
    rm -rf assets/Rom
    rm -rf assets/shaders

elif [ "$1" = "release" ]; then

    if [ ! -d assets/Rom ]; then
	mkdir -p assets/Rom
	cp -R ../../native/RAMROMDiskPipnet/rom*.roz assets/Rom/
    fi

    test -d assets/Bios    || cp -R ../../native/Bios assets/
    test -d assets/shaders || cp -R ../shaders assets/

    /home/sash/Android/android-ndk-r10e/ndk-build -j8
    ant release

else

    if [ ! -d assets/Rom ]; then
	mkdir -p assets/Rom
	cp -R ../../native/RAMROMDiskPipnet/rom*.roz assets/Rom/
    fi

    test -d assets/Bios    || cp -R ../../native/Bios assets/
    test -d assets/shaders || cp -R ../shaders assets/

    NDK_DEBUG=1 /home/sash/Android/android-ndk-r10e/ndk-build -j8
    ant debug

fi
