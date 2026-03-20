cmake_minimum_required(VERSION 3.16)
project(pyldin601-android C)

if(NOT VCPKG_ROOT)
    message(FATAL_ERROR "VCPKG_ROOT must be set")
endif()

# Map Android ABI to vcpkg triplet
if(ANDROID_ABI STREQUAL "arm64-v8a")
    set(VCPKG_TRIPLET "arm64-android")
elseif(ANDROID_ABI STREQUAL "armeabi-v7a")
    set(VCPKG_TRIPLET "arm-neon-android")
elseif(ANDROID_ABI STREQUAL "x86_64")
    set(VCPKG_TRIPLET "x64-android")
elseif(ANDROID_ABI STREQUAL "x86")
    set(VCPKG_TRIPLET "x86-android")
else()
    message(FATAL_ERROR "Unsupported ANDROID_ABI: ${ANDROID_ABI}")
endif()

set(VCPKG_INSTALLED "${VCPKG_ROOT}/installed/${VCPKG_TRIPLET}")
set(SDL2_DIR "${VCPKG_INSTALLED}/share/sdl2")
list(APPEND CMAKE_PREFIX_PATH "${VCPKG_INSTALLED}")

find_package(SDL2 REQUIRED CONFIG)

# Read version
set(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../..")
file(READ "${REPO_ROOT}/VERSION" PYLDIN_VERSION)
string(STRIP "${PYLDIN_VERSION}" PYLDIN_VERSION)

set(SRC_DIR "${REPO_ROOT}/src")

add_library(main SHARED
    ${SRC_DIR}/core/core.c
    ${SRC_DIR}/discs.c
    ${SRC_DIR}/screen.c
    ${SRC_DIR}/floppymanager.c
    ${SRC_DIR}/wave.c
    ${SRC_DIR}/pyldin-sdl2.c
)

target_include_directories(main PRIVATE
    ${SRC_DIR}/core
    ${SRC_DIR}
)

target_compile_options(main PRIVATE
    -Wall -Ofast -fomit-frame-pointer
    -DVERSION="${PYLDIN_VERSION}"
)

target_link_libraries(main PRIVATE
    $<TARGET_NAME_IF_EXISTS:SDL2::SDL2main>
    SDL2::SDL2-static
    GLESv2
    z
    log
)
