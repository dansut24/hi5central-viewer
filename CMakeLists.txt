cmake_minimum_required(VERSION 3.22)

project(hi5central_viewer LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(HI5CENTRAL_VIEWER_VERSION "0.2.0" CACHE STRING "Hi5Central Viewer version")

if (APPLE)
    enable_language(OBJCXX)
endif()

include(FetchContent)

# Use WebKitGTK 4.1 / GTK 3 on Linux. This is broadly available on supported
# Debian/Ubuntu desktops and also gives the native shell a stable GTK clipboard API.
if (UNIX AND NOT APPLE)
    set(WEBVIEW_WEBKITGTK_API "4.1" CACHE STRING "" FORCE)
endif()

FetchContent_Declare(
    webview
    GIT_REPOSITORY https://github.com/webview/webview.git
    GIT_TAG 0.12.0
)

set(WEBVIEW_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(WEBVIEW_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(WEBVIEW_BUILD_DOCS OFF CACHE BOOL "" FORCE)
set(WEBVIEW_BUILD_AMALGAMATION OFF CACHE BOOL "" FORCE)

FetchContent_MakeAvailable(webview)

add_executable(hi5tech-viewer
    src/main.cpp
    src/app/viewer_app.cpp
    src/core/logger.cpp
    src/core/deep_link.cpp
)

target_include_directories(hi5tech-viewer PRIVATE
    src
)

target_link_libraries(hi5tech-viewer PRIVATE
    webview::core
)

if (WIN32)
    # Keep the console subsystem for the exact URL-protocol argv behaviour used
    # by the last known-good Viewer builds. main() hides/detaches the console
    # immediately on startup so no background CMD window remains.
    target_compile_definitions(hi5tech-viewer PRIVATE
        WIN32_LEAN_AND_MEAN
        NOMINMAX
        _CRT_SECURE_NO_WARNINGS
    )
elseif (APPLE)
    target_compile_definitions(hi5tech-viewer PRIVATE HI5_VIEWER_MACOS=1)
else()
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(GTK3 REQUIRED IMPORTED_TARGET gtk+-3.0)
    pkg_check_modules(WEBKIT41 REQUIRED IMPORTED_TARGET webkit2gtk-4.1)
    target_link_libraries(hi5tech-viewer PRIVATE PkgConfig::GTK3 PkgConfig::WEBKIT41)
    target_compile_definitions(hi5tech-viewer PRIVATE HI5_VIEWER_LINUX=1)
endif()

# Keep the viewer web shell adjacent to the native executable for Windows/Linux
# development builds. The macOS launcher target copies the same assets into its
# .app Resources directory below.
add_custom_command(TARGET hi5tech-viewer POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_FILE_DIR:hi5tech-viewer>/web"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${CMAKE_SOURCE_DIR}/web/index.html"
        "$<TARGET_FILE_DIR:hi5tech-viewer>/web/index.html"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${CMAKE_SOURCE_DIR}/web/renderer.js"
        "$<TARGET_FILE_DIR:hi5tech-viewer>/web/renderer.js"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${CMAKE_SOURCE_DIR}/web/file_browser.html"
        "$<TARGET_FILE_DIR:hi5tech-viewer>/web/file_browser.html"
)

if (APPLE)
    # The visible .app is a tiny LaunchServices URL handler. macOS delivers
    # custom URL schemes as application events rather than argv, so the launcher
    # starts a separate viewer core process with the URL as argv[1]. This also
    # keeps concurrent remote sessions possible.
    add_executable(hi5central-viewer-launcher MACOSX_BUNDLE
        installer/macos/launcher.mm
    )
    target_link_libraries(hi5central-viewer-launcher PRIVATE "-framework Cocoa")
    add_dependencies(hi5central-viewer-launcher hi5tech-viewer)

    set_target_properties(hi5tech-viewer PROPERTIES
        OUTPUT_NAME "Hi5CentralViewerCore"
    )

    set_target_properties(hi5central-viewer-launcher PROPERTIES
        OUTPUT_NAME "Hi5CentralViewer"
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_BUNDLE_NAME "Hi5Central Viewer"
        MACOSX_BUNDLE_GUI_IDENTIFIER "com.hi5central.viewer"
        MACOSX_BUNDLE_BUNDLE_VERSION "${HI5CENTRAL_VIEWER_VERSION}"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "${HI5CENTRAL_VIEWER_VERSION}"
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_SOURCE_DIR}/installer/macos/Info.plist.in"
    )

    add_custom_command(TARGET hi5central-viewer-launcher POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "$<TARGET_FILE:hi5tech-viewer>"
            "$<TARGET_BUNDLE_DIR:hi5central-viewer-launcher>/Contents/MacOS/Hi5CentralViewerCore"
        COMMAND ${CMAKE_COMMAND} -E make_directory
            "$<TARGET_BUNDLE_DIR:hi5central-viewer-launcher>/Contents/Resources/web"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${CMAKE_SOURCE_DIR}/web/index.html"
            "$<TARGET_BUNDLE_DIR:hi5central-viewer-launcher>/Contents/Resources/web/index.html"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${CMAKE_SOURCE_DIR}/web/renderer.js"
            "$<TARGET_BUNDLE_DIR:hi5central-viewer-launcher>/Contents/Resources/web/renderer.js"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${CMAKE_SOURCE_DIR}/web/file_browser.html"
            "$<TARGET_BUNDLE_DIR:hi5central-viewer-launcher>/Contents/Resources/web/file_browser.html"
    )
else()
    # Hi5Central rebrand: keep internal target for compatibility, but output the
    # product name used by the existing Windows installer and Linux package.
    set_target_properties(hi5tech-viewer PROPERTIES
        OUTPUT_NAME "Hi5CentralViewer"
    )
endif()
