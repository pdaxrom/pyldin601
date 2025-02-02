cmake_minimum_required(VERSION 3.16.3)

set(TARGET pyldin)

project(${TARGET})

INCLUDE(FindPkgConfig)

find_package(PkgConfig REQUIRED)

find_package(SDL2 REQUIRED CONFIG REQUIRED COMPONENTS SDL2)
find_package(SDL2_image REQUIRED CONFIG REQUIRED COMPONENTS SDL2_image)

#pkg_check_modules(libpng16 REQUIRED libpng16)
#pkg_check_modules(libjxl REQUIRED libjxl)
#pkg_check_modules(libjpeg REQUIRED libjpeg)
#pkg_check_modules(libtiff-4 REQUIRED libtiff-4)
#pkg_check_modules(libavif REQUIRED libavif)
#pkg_check_modules(libwebp REQUIRED libwebp)
#pkg_check_modules(libwebpdemux REQUIRED libwebpdemux)

#link_directories(
#    ${libpng16_LIBRARY_DIRS}
#    ${libjxl_LIBRARY_DIRS}
#    ${libjpeg_LIBRARY_DIRS}
#    ${libtiff-4_LIBRARY_DIRS}
#    ${libavif_LIBRARY_DIRS}
#    ${libwebp_LIBRARY_DIRS}
#    ${libwebpdemux_LIBRARY_DIRS}
#)

#include_directories(${libpng16_INCLUDE_DIRS})

execute_process(
    COMMAND cat VERSION
    WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}
    OUTPUT_VARIABLE APP_VERSION
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

execute_process(
    COMMAND git log -1 --format=%h
    WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}
    OUTPUT_VARIABLE GIT_HASH
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

add_executable(${TARGET})

target_compile_options(${TARGET} PUBLIC -Wall -Wextra -pedantic -Warray-bounds -fsanitize=address -D_THREAD_SAFE -DPYLDIN_LOGO -DPYLDIN_ICON -DUSE_JOYSTICK -DVERSION="${APP_VERSION}-${GIT_HASH}")

file(GLOB pyldin601_HDR CONFIGURE_DEPENDS "src/*.h" "src/core/*.h")

set(SOURCES src/core/core.c src/discs.c src/screen.c src/sshot.c src/floppymanager.c src/pyldin-sdl2.c src/wave.c ${pyldin601_HDR})

target_sources(${TARGET} PUBLIC ${SOURCES})

target_include_directories(${TARGET} PUBLIC ${CMAKE_CURRENT_LIST_DIR}/src)

target_link_libraries(${TARGET}
    SDL2::SDL2
    SDL2_image::SDL2_image
    # ${libpng16_LIBRARIES}
    # ${libjxl_LIBRARIES}
    # ${libjpeg_LIBRARIES}
    # ${libtiff-4_LIBRARIES}
    # ${libavif_LIBRARIES}
    # ${libwebp_LIBRARUES}
    # ${libwebpdemux_LIBRARIES}
    -lz
    -fsanitize=address
)

IF(${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
add_custom_command(TARGET ${TARGET}
    POST_BUILD
    COMMAND mkdir -p ${CMAKE_CURRENT_BINARY_DIR}/Pyldin-601.app/Contents/MacOS
    COMMAND cp -f ${CMAKE_CURRENT_LIST_DIR}/addon/MacOSX/Pyldin-601 ${CMAKE_CURRENT_BINARY_DIR}/Pyldin-601.app/Contents/MacOS
    COMMAND cp -f ${CMAKE_CURRENT_LIST_DIR}/addon/MacOSX/Info.plist ${CMAKE_CURRENT_BINARY_DIR}/Pyldin-601.app/Contents
    COMMAND cp -f pyldin ${CMAKE_CURRENT_BINARY_DIR}/Pyldin-601.app/Contents/MacOS/pyldin
    COMMAND chmod 755 ${CMAKE_CURRENT_BINARY_DIR}/Pyldin-601.app/Contents/MacOS/pyldin
    COMMAND echo 'APPLhiti' > ${CMAKE_CURRENT_BINARY_DIR}/Pyldin-601.app/Contents/PkgInfo
    COMMAND mkdir -p ${CMAKE_CURRENT_BINARY_DIR}/Pyldin-601.app/Contents/Resources
    COMMAND cp -f ${CMAKE_CURRENT_LIST_DIR}/addon/MacOSX/pyldin.icns ${CMAKE_CURRENT_BINARY_DIR}/Pyldin-601.app/Contents/Resources

)
ENDIF()
