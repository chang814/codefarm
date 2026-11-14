cmake_minimum_required(VERSION 3.17)
project(codefarm LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE RelWithDebInfo CACHE STRING "Build type" FORCE)
endif()

add_library(codefarm_sim STATIC
    sim/src/world.cpp
    sim/src/world_state.cpp
    sim/src/interpreter.cpp
)
target_include_directories(codefarm_sim PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/sim/include
)
target_compile_options(codefarm_sim PRIVATE -Wall -Wextra -Wpedantic)

add_executable(codefarm_tests tests/test_sim.cpp)
target_link_libraries(codefarm_tests PRIVATE codefarm_sim)
target_compile_options(codefarm_tests PRIVATE -Wall -Wextra -Wpedantic)
# Encode paths as ASCII byte literals: command-line definitions of Chinese
# paths are corrupted by Windows toolchains before the test ever opens them.
string(HEX "${CMAKE_CURRENT_SOURCE_DIR}" _cf_root_hex)
string(REGEX REPLACE "(..)" "0x\\1," _cf_root_bytes "${_cf_root_hex}")
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/codefarm_paths.hpp"
    "#pragma once\nnamespace codefarm_paths {\ninline constexpr unsigned char root[] = {${_cf_root_bytes}0};\n}\n")
target_include_directories(codefarm_tests PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")

option(CODEFARM_BUILD_EXTENSION "Build the Godot 4 GDExtension" ON)
if(CODEFARM_BUILD_EXTENSION)
    set(GODOTCPP_API_VERSION "4.7" CACHE STRING "godot-cpp API version")
    set(GODOTCPP_SYSTEM_HEADERS ON CACHE BOOL "")
    set(GODOTCPP_USE_STATIC_CPP OFF CACHE BOOL "")
    set(GODOTCPP_TARGET "template_debug" CACHE STRING "")
    add_subdirectory(third_party/godot-cpp EXCLUDE_FROM_ALL)

    add_library(codefarm SHARED
        extension/src/register.cpp
        extension/src/codefarm_host.cpp
    )
    target_include_directories(codefarm PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/extension/src
        ${CMAKE_CURRENT_SOURCE_DIR}/sim/include
    )
    target_link_libraries(codefarm PRIVATE godot::cpp codefarm_sim)
    if(WIN32)
        set(_cf_out "codefarm.windows.template_debug.x86_64")
        set(_cf_prefix "")
        set(_cf_suffix ".dll")
    else()
        set(_cf_out "codefarm.linux.template_debug.x86_64")
        set(_cf_prefix "lib")
        set(_cf_suffix ".so")
    endif()
    set_target_properties(codefarm PROPERTIES
        OUTPUT_NAME "${_cf_out}"
        PREFIX "${_cf_prefix}"
        SUFFIX "${_cf_suffix}"
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/game/bin"
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/game/bin"
        ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/game/bin"
    )
endif()

enable_testing()
add_test(NAME codefarm_tests COMMAND codefarm_tests)

# Prints the playthrough route with per-stage game time (docs/playthrough.md).
add_executable(codefarm_playthrough tests/playthrough_dev.cpp)
target_link_libraries(codefarm_playthrough PRIVATE codefarm_sim)
target_include_directories(codefarm_playthrough PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")
