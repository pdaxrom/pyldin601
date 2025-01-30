cmake_minimum_required(VERSION 3.16.3)

set(TARGET pyldin601)

project(${TARGET})

INCLUDE(FindPkgConfig)

find_package(SDL2 REQUIRED)
find_package(SDL2_image REQUIRED)

include_directories(${SDL2_INCLUDE_DIRS} ${SDL2_IMAGE_INCLUDE_DIRS})

add_executable(${TARGET})

target_compile_options(${TARGET} PUBLIC -Wall -Wextra -pedantic -Warray-bounds -fsanitize=address -D_THREAD_SAFE -DPYLDIN_LOGO -DPYLDIN_ICON -DUSE_JOYSTICK)

file(GLOB pyldin601_HDR CONFIGURE_DEPENDS "src/*.h" "src/core/*.h")

set(SOURCES src/core/core.c src/discs.c src/screen.c src/sshot.c src/floppymanager.c src/pyldin-sdl2.c src/wave.c ${pyldin601_HDR})

target_sources(${TARGET} PUBLIC ${SOURCES})

target_include_directories(${TARGET} PUBLIC ${CMAKE_CURRENT_LIST_DIR}/src)

target_link_libraries(${TARGET} ${SDL2_LIBRARIES} SDL2_image::SDL2_image -lz -fsanitize=address)
