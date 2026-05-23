cmake_minimum_required(VERSION 3.24)

if(NOT DEFINED CMAKE_TOOLCHAIN_FILE)
    if(DEFINED ENV{VCPKG_ROOT} AND EXISTS "$ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake")
        set(
            CMAKE_TOOLCHAIN_FILE
            "$ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake"
            CACHE FILEPATH "Path to the vcpkg toolchain file"
        )
    endif()
endif()

file(READ "${CMAKE_CURRENT_SOURCE_DIR}/VERSION" PYLDIN_VERSION)
string(STRIP "${PYLDIN_VERSION}" PYLDIN_VERSION)

project(pyldin VERSION "${PYLDIN_VERSION}" LANGUAGES C)

include(GNUInstallDirs)

option(PYLDIN_ENABLE_ASAN "Enable AddressSanitizer for local debugging builds" OFF)
option(PYLDIN_ENABLE_OPENGL "Enable the OpenGL renderer path" OFF)
option(PYLDIN_ENABLE_JOYSTICK "Enable joystick support" ON)
option(PYLDIN_ENABLE_LOGO "Compile the splash logo into the executable" ON)
option(PYLDIN_ENABLE_ICON "Compile the application icon into the executable" ON)
option(PYLDIN_UNIBIOS_ONLY "Install only the UniBios ROM set" OFF)
option(PYLDIN_BUNDLE_RUNTIME_DEPS "Copy non-system runtime libraries into install/package bundles" ON)

set(PYLDIN_NATIVE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../native")
set(PYLDIN_HD6303_NATIVE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../native-hd6303")
set(PYLDIN_DATA_SUBDIR "pyldin")
set(PYLDIN_DATA_INSTALL_DIR "${CMAKE_INSTALL_DATADIR}/${PYLDIN_DATA_SUBDIR}")
set(PYLDIN_STAGE_DIR "${CMAKE_BINARY_DIR}/bundle")

execute_process(
    COMMAND git rev-parse --short HEAD
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    RESULT_VARIABLE PYLDIN_GIT_HASH_RESULT
    OUTPUT_VARIABLE PYLDIN_GIT_HASH
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
)

if(NOT PYLDIN_GIT_HASH_RESULT EQUAL 0 OR PYLDIN_GIT_HASH STREQUAL "")
    set(PYLDIN_GIT_HASH "nogit")
endif()

set(PYLDIN_BUILD_VERSION "${PROJECT_VERSION}-${PYLDIN_GIT_HASH}")

if(CMAKE_TOOLCHAIN_FILE MATCHES "vcpkg.cmake$")
    message(STATUS "Using vcpkg toolchain: ${CMAKE_TOOLCHAIN_FILE}")
else()
    message(STATUS "Configure with CMakePresets.json or -DCMAKE_TOOLCHAIN_FILE=<vcpkg>/scripts/buildsystems/vcpkg.cmake to build through vcpkg.")
endif()

find_package(SDL2 CONFIG REQUIRED)
find_package(SDL2_image CONFIG REQUIRED)
find_package(ZLIB REQUIRED)

if(PYLDIN_ENABLE_OPENGL)
    find_package(OpenGL REQUIRED)
endif()

function(pyldin_resolve_target output_var)
    foreach(candidate IN LISTS ARGN)
        if(TARGET "${candidate}")
            set("${output_var}" "${candidate}" PARENT_SCOPE)
            return()
        endif()
    endforeach()

    message(FATAL_ERROR "Unable to resolve any of the imported targets: ${ARGN}")
endfunction()

pyldin_resolve_target(PYLDIN_SDL2_TARGET SDL2::SDL2 SDL2::SDL2-static)
pyldin_resolve_target(PYLDIN_SDL2_IMAGE_TARGET SDL2_image::SDL2_image SDL2_image::SDL2_image-static)

set(PYLDIN_SDL2MAIN_TARGET "")
if(TARGET SDL2::SDL2main)
    set(PYLDIN_SDL2MAIN_TARGET SDL2::SDL2main)
elseif(TARGET SDL2::SDL2main-static)
    set(PYLDIN_SDL2MAIN_TARGET SDL2::SDL2main-static)
endif()

set(PYLDIN_SOURCES
    src/core/core.c
    src/discs.c
    src/floppymanager.c
    src/pyldin-sdl2.c
    src/screen.c
    src/sshot.c
    src/wave.c
)

if(APPLE)
    set(PYLDIN_APP_BUNDLE_NAME "Pyldin-601")
    set(PYLDIN_APPLE_ICON "${CMAKE_CURRENT_SOURCE_DIR}/addon/MacOSX/pyldin.icns")
    set_source_files_properties("${PYLDIN_APPLE_ICON}" PROPERTIES MACOSX_PACKAGE_LOCATION "Resources")
    configure_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/cmake/Info.plist.in"
        "${CMAKE_CURRENT_BINARY_DIR}/Info.plist"
        @ONLY
    )
endif()

add_executable(pyldin ${PYLDIN_SOURCES})

target_include_directories(pyldin PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/src")

if(APPLE)
    target_sources(pyldin PRIVATE "${PYLDIN_APPLE_ICON}")
endif()

set_target_properties(pyldin PROPERTIES C_STANDARD 99 C_STANDARD_REQUIRED ON)

if(APPLE)
    set_target_properties(
        pyldin
        PROPERTIES
            MACOSX_BUNDLE TRUE
            OUTPUT_NAME "${PYLDIN_APP_BUNDLE_NAME}"
            MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_BINARY_DIR}/Info.plist"
            MACOSX_BUNDLE_ICON_FILE "pyldin.icns"
            MACOSX_BUNDLE_BUNDLE_NAME "${PYLDIN_APP_BUNDLE_NAME}"
            MACOSX_BUNDLE_GUI_IDENTIFIER "org.pdaxrom.pyldin601"
            MACOSX_BUNDLE_BUNDLE_VERSION "${PYLDIN_BUILD_VERSION}"
            MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
            INSTALL_RPATH "@executable_path/../Frameworks"
    )
elseif(UNIX AND NOT APPLE)
    set_target_properties(
        pyldin
        PROPERTIES
            BUILD_RPATH_USE_ORIGIN ON
            INSTALL_RPATH "\$ORIGIN/../${CMAKE_INSTALL_LIBDIR}"
    )
else()
    set_target_properties(pyldin PROPERTIES OUTPUT_NAME "pyldin")
endif()

target_compile_definitions(
    pyldin
    PRIVATE
        VERSION="${PYLDIN_BUILD_VERSION}"
        DATADIR="${CMAKE_INSTALL_FULL_DATADIR}/${PYLDIN_DATA_SUBDIR}"
        _THREAD_SAFE
)

if(PYLDIN_ENABLE_OPENGL)
    target_compile_definitions(pyldin PRIVATE USE_OPENGL=1)
endif()

if(PYLDIN_ENABLE_JOYSTICK)
    target_compile_definitions(pyldin PRIVATE USE_JOYSTICK)
endif()

if(PYLDIN_ENABLE_LOGO)
    target_compile_definitions(pyldin PRIVATE PYLDIN_LOGO)
endif()

if(PYLDIN_ENABLE_ICON)
    target_compile_definitions(pyldin PRIVATE PYLDIN_ICON)
endif()

if(MSVC)
    target_compile_options(pyldin PRIVATE /W4)
else()
    target_compile_options(pyldin PRIVATE -Wall -Wextra -Wpedantic -Warray-bounds)
endif()

if(PYLDIN_ENABLE_ASAN AND NOT MSVC)
    target_compile_options(pyldin PRIVATE -fsanitize=address -fno-omit-frame-pointer)
    target_link_options(pyldin PRIVATE -fsanitize=address)
endif()

set(PYLDIN_LINK_LIBS
    ${PYLDIN_SDL2_TARGET}
    ${PYLDIN_SDL2_IMAGE_TARGET}
    ZLIB::ZLIB
)

if(PYLDIN_SDL2MAIN_TARGET)
    list(INSERT PYLDIN_LINK_LIBS 0 ${PYLDIN_SDL2MAIN_TARGET})
endif()

if(PYLDIN_ENABLE_OPENGL)
    list(APPEND PYLDIN_LINK_LIBS OpenGL::GL)
endif()

target_link_libraries(pyldin PRIVATE ${PYLDIN_LINK_LIBS})

if(APPLE)
    set(PYLDIN_RUNTIME_INSTALL_DESTINATION ".")
    set(PYLDIN_LIBRARY_INSTALL_DESTINATION "${PYLDIN_APP_BUNDLE_NAME}.app/Contents/Frameworks")
    set(PYLDIN_DATA_INSTALL_DESTINATION "${PYLDIN_APP_BUNDLE_NAME}.app/Contents/Resources/${PYLDIN_DATA_INSTALL_DIR}")

    set(PYLDIN_BUILD_APP_DATA_DIR "$<TARGET_BUNDLE_CONTENT_DIR:pyldin>/Resources/${PYLDIN_DATA_INSTALL_DIR}")
    if(PYLDIN_UNIBIOS_ONLY)
        set(PYLDIN_BUILD_ROM_SOURCE_DIR "${PYLDIN_NATIVE_DIR}/Rom")
    else()
        set(PYLDIN_BUILD_ROM_SOURCE_DIR "${PYLDIN_NATIVE_DIR}/RAMROMDiskPipnet")
    endif()

    add_custom_command(
        TARGET pyldin
        POST_BUILD
        COMMAND "${CMAKE_COMMAND}" -E make_directory "${PYLDIN_BUILD_APP_DATA_DIR}"
        COMMAND "${CMAKE_COMMAND}" -E copy_directory "${PYLDIN_NATIVE_DIR}/Bios" "${PYLDIN_BUILD_APP_DATA_DIR}/Bios"
        COMMAND "${CMAKE_COMMAND}" -E copy_directory "${PYLDIN_NATIVE_DIR}/Floppy" "${PYLDIN_BUILD_APP_DATA_DIR}/Floppy"
        COMMAND "${CMAKE_COMMAND}" -E copy_directory "${PYLDIN_BUILD_ROM_SOURCE_DIR}" "${PYLDIN_BUILD_APP_DATA_DIR}/Rom"
        COMMAND "${CMAKE_COMMAND}" -E copy_directory "${CMAKE_CURRENT_SOURCE_DIR}/shaders" "${PYLDIN_BUILD_APP_DATA_DIR}/shaders"
        COMMENT "Copying Pyldin data resources into the build app bundle"
        VERBATIM
    )

    if(EXISTS "${PYLDIN_HD6303_NATIVE_DIR}/Hd6303")
        add_custom_command(
            TARGET pyldin
            POST_BUILD
            COMMAND "${CMAKE_COMMAND}" -E copy_directory "${PYLDIN_HD6303_NATIVE_DIR}/Hd6303" "${PYLDIN_BUILD_APP_DATA_DIR}/Hd6303"
            COMMENT "Copying HD6303 data resources into the build app bundle"
            VERBATIM
        )
    endif()
else()
    set(PYLDIN_RUNTIME_INSTALL_DESTINATION "${CMAKE_INSTALL_BINDIR}")
    set(PYLDIN_DATA_INSTALL_DESTINATION "${PYLDIN_DATA_INSTALL_DIR}")

    if(WIN32)
        set(PYLDIN_LIBRARY_INSTALL_DESTINATION "${CMAKE_INSTALL_BINDIR}")
    else()
        set(PYLDIN_LIBRARY_INSTALL_DESTINATION "${CMAKE_INSTALL_LIBDIR}")
    endif()
endif()

set(PYLDIN_RUNTIME_DEPENDENCY_ARGS "")
if(PYLDIN_BUNDLE_RUNTIME_DEPS)
    if(APPLE)
        list(
            APPEND PYLDIN_RUNTIME_DEPENDENCY_ARGS
                RUNTIME_DEPENDENCIES
                    POST_EXCLUDE_REGEXES
                        ".*/System/Library/.*"
                        ".*/usr/lib/.*"
        )
    elseif(WIN32)
        list(
            APPEND PYLDIN_RUNTIME_DEPENDENCY_ARGS
                RUNTIME_DEPENDENCIES
                    PRE_EXCLUDE_REGEXES
                        "api-ms-.*"
                        "ext-ms-.*"
                    POST_EXCLUDE_REGEXES
                        ".*/[Ww]indows/[Ss]ystem32/.*\\.dll"
        )
    elseif(UNIX)
        list(
            APPEND PYLDIN_RUNTIME_DEPENDENCY_ARGS
                RUNTIME_DEPENDENCIES
                    POST_EXCLUDE_REGEXES
                        "^/lib.*/ld-linux-.*"
                        "^/lib.*/libc\\.so(\\..*)?"
                        "^/lib.*/libdl\\.so(\\..*)?"
                        "^/lib.*/libgcc_s\\.so(\\..*)?"
                        "^/lib.*/libm\\.so(\\..*)?"
                        "^/lib.*/libpthread\\.so(\\..*)?"
                        "^/lib.*/librt\\.so(\\..*)?"
                        "^/lib.*/libstdc\\+\\+\\.so(\\..*)?"
                        "^/usr/lib.*/libxcb.*"
                        "^/usr/lib.*/libX11.*"
                        "^/usr/lib.*/libwayland.*"
                        "^/usr/lib.*/libGLX.*"
                        "^/usr/lib.*/libGLdispatch.*"
                        "^/usr/lib.*/libEGL.*"
                        "^/usr/lib.*/libGL\\.so(\\..*)?"
                        "^/usr/lib.*/libasound\\.so(\\..*)?"
                        "^/usr/lib/.*"
                        "^/usr/lib64/.*"
                        "^/lib/.*"
                        "^/lib64/.*"
        )
    endif()
endif()

if(APPLE)
    install(
        TARGETS pyldin
        ${PYLDIN_RUNTIME_DEPENDENCY_ARGS}
        BUNDLE DESTINATION "."
        FRAMEWORK DESTINATION "${PYLDIN_LIBRARY_INSTALL_DESTINATION}"
        LIBRARY DESTINATION "${PYLDIN_LIBRARY_INSTALL_DESTINATION}"
    )
else()
    install(
        TARGETS pyldin
        ${PYLDIN_RUNTIME_DEPENDENCY_ARGS}
        RUNTIME DESTINATION "${PYLDIN_RUNTIME_INSTALL_DESTINATION}"
        LIBRARY DESTINATION "${PYLDIN_LIBRARY_INSTALL_DESTINATION}"
    )
endif()

install(
    DIRECTORY "${PYLDIN_NATIVE_DIR}/Bios/"
    DESTINATION "${PYLDIN_DATA_INSTALL_DESTINATION}/Bios"
    FILES_MATCHING
        PATTERN "*.roz"
)

install(
    DIRECTORY "${PYLDIN_NATIVE_DIR}/Floppy/"
    DESTINATION "${PYLDIN_DATA_INSTALL_DESTINATION}/Floppy"
    FILES_MATCHING
        PATTERN "*.imz"
)

if(PYLDIN_UNIBIOS_ONLY)
    install(
        DIRECTORY "${PYLDIN_NATIVE_DIR}/Rom/"
        DESTINATION "${PYLDIN_DATA_INSTALL_DESTINATION}/Rom"
        FILES_MATCHING
            PATTERN "str*.roz"
    )
else()
    install(
        DIRECTORY "${PYLDIN_NATIVE_DIR}/RAMROMDiskPipnet/"
        DESTINATION "${PYLDIN_DATA_INSTALL_DESTINATION}/Rom"
        FILES_MATCHING
            PATTERN "*.roz"
    )
endif()

if(EXISTS "${PYLDIN_HD6303_NATIVE_DIR}/Hd6303")
    install(
        DIRECTORY "${PYLDIN_HD6303_NATIVE_DIR}/Hd6303/"
        DESTINATION "${PYLDIN_DATA_INSTALL_DESTINATION}/Hd6303"
        FILES_MATCHING
            PATTERN "*.roz"
    )
endif()

install(
    DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/shaders/"
    DESTINATION "${PYLDIN_DATA_INSTALL_DESTINATION}/shaders"
    FILES_MATCHING
        PATTERN "*.frag"
        PATTERN "*.vert"
)

if(UNIX AND NOT APPLE)
    install(
        FILES
            "${CMAKE_CURRENT_SOURCE_DIR}/pyldin.desktop"
        DESTINATION "${CMAKE_INSTALL_DATADIR}/applications"
    )
    install(
        FILES
            "${CMAKE_CURRENT_SOURCE_DIR}/pyldin.png"
        DESTINATION "${CMAKE_INSTALL_DATADIR}/pixmaps"
    )
endif()

add_custom_target(
    bundle
    COMMAND "${CMAKE_COMMAND}" --install "${CMAKE_BINARY_DIR}" --prefix "${PYLDIN_STAGE_DIR}" --config "$<CONFIG>"
    DEPENDS pyldin
    COMMENT "Staging a portable Pyldin-601 bundle in ${PYLDIN_STAGE_DIR}"
    USES_TERMINAL
)

set(CPACK_PACKAGE_NAME "Pyldin-601")
set(CPACK_PACKAGE_VENDOR "pdaXrom")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Portable emulator for the Pyldin-601 computer")
set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
set(CPACK_MONOLITHIC_INSTALL ON)
set(CPACK_PACKAGE_FILE_NAME "pyldin-601-${PYLDIN_BUILD_VERSION}-${CMAKE_SYSTEM_NAME}-${CMAKE_SYSTEM_PROCESSOR}")

if(APPLE)
    set(CPACK_GENERATOR "DragNDrop")
    set(CPACK_DMG_VOLUME_NAME "Pyldin-601")
    set(CPACK_INCLUDE_TOPLEVEL_DIRECTORY OFF)
elseif(WIN32)
    set(CPACK_GENERATOR "ZIP")
    set(CPACK_INCLUDE_TOPLEVEL_DIRECTORY ON)
else()
    set(CPACK_GENERATOR "TGZ")
    set(CPACK_INCLUDE_TOPLEVEL_DIRECTORY ON)
endif()

include(CPack)
