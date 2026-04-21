cmake_minimum_required(VERSION 3.20)

# ── Read LIBGONODES_VERSION from versions.env (single source of truth) ────
file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/../versions.env" _ver_lines)
foreach(_line IN LISTS _ver_lines)
    if(_line MATCHES "^LIBGONODES_VERSION=(.+)$")
        set(_lib_ver "${CMAKE_MATCH_1}")
    endif()
endforeach()
if(NOT _lib_ver)
    message(FATAL_ERROR "LIBGONODES_VERSION not found in versions.env")
endif()

project(libgonodes VERSION ${_lib_ver} LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ═══════════════════════════════════════════════════════════════════════════════
# Options
# ═══════════════════════════════════════════════════════════════════════════════

option(GONODES_BUILD_EXAMPLES  "Build example host applications" ON)
option(GONODES_BUILD_SHARED    "Build as shared library (DLL)"   ON)
option(GONODES_BUILD_TESTS     "Build API test suite"            ON)

# ═══════════════════════════════════════════════════════════════════════════════
# Library
# ═══════════════════════════════════════════════════════════════════════════════

set(GONODES_SOURCES
    src/gonodes_bootstrap.cpp
    src/gonodes_host.cpp
)

set(GONODES_HEADERS
    include/gonodes_host.h
    src/gonodes_bootstrap.h
)

if(GONODES_BUILD_SHARED)
    add_library(gonodes SHARED ${GONODES_SOURCES} ${GONODES_HEADERS})
    target_compile_definitions(gonodes PRIVATE GONODES_BUILDING_LIBRARY)
else()
    add_library(gonodes STATIC ${GONODES_SOURCES} ${GONODES_HEADERS})
    target_compile_definitions(gonodes PRIVATE GONODES_BUILDING_LIBRARY)
endif()

# Pass version from CMake (sourced from versions.env) so the library
# can static_assert consistency with the header macros.
target_compile_definitions(gonodes PRIVATE
    GONODES_VERSION_FROM_CMAKE_MAJOR=${PROJECT_VERSION_MAJOR}
    GONODES_VERSION_FROM_CMAKE_MINOR=${PROJECT_VERSION_MINOR}
    GONODES_VERSION_FROM_CMAKE_PATCH=${PROJECT_VERSION_PATCH}
)

target_include_directories(gonodes PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

# Platform-specific link libraries.
if(WIN32)
    # No extra libs needed — LoadLibrary is part of kernel32.
elseif(APPLE)
    target_link_libraries(gonodes PRIVATE dl)
else()
    target_link_libraries(gonodes PRIVATE dl)
endif()

# ═══════════════════════════════════════════════════════════════════════════════
# Install
# ═══════════════════════════════════════════════════════════════════════════════

install(TARGETS gonodes
    RUNTIME DESTINATION bin
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
)

install(FILES include/gonodes_host.h DESTINATION include)

# ═══════════════════════════════════════════════════════════════════════════════
# Examples
# ═══════════════════════════════════════════════════════════════════════════════

if(GONODES_BUILD_EXAMPLES)
    # SDL Host Example
    add_subdirectory(examples/sdl_host EXCLUDE_FROM_ALL)

    # Vulkan Host Example
    add_subdirectory(examples/vulkan_host EXCLUDE_FROM_ALL)

    # OpenGL Host Example
    add_subdirectory(examples/opengl_host EXCLUDE_FROM_ALL)

    # Metal Host Example (macOS only)
    if(APPLE)
        add_subdirectory(examples/metal_host EXCLUDE_FROM_ALL)
    endif()

    # Params Demo Example
    add_subdirectory(examples/params_demo EXCLUDE_FROM_ALL)

    # Geometry Host Example
    add_subdirectory(examples/geometry_host EXCLUDE_FROM_ALL)

    # Graph Edit Demo Example
    add_subdirectory(examples/graph_edit_demo EXCLUDE_FROM_ALL)

    # MIDI/OSC Host Example
    add_subdirectory(examples/midi_osc_host EXCLUDE_FROM_ALL)
endif()

# ═══════════════════════════════════════════════════════════════════════════════
# Tests
# ═══════════════════════════════════════════════════════════════════════════════

if(GONODES_BUILD_TESTS)
    add_executable(gonodes_tests tests/test_api.cpp)
    target_link_libraries(gonodes_tests PRIVATE gonodes)
    target_include_directories(gonodes_tests PRIVATE
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    )
    # Pass expected version so tests can verify header matches versions.env.
    target_compile_definitions(gonodes_tests PRIVATE
        EXPECTED_VERSION_MAJOR=${PROJECT_VERSION_MAJOR}
        EXPECTED_VERSION_MINOR=${PROJECT_VERSION_MINOR}
        EXPECTED_VERSION_PATCH=${PROJECT_VERSION_PATCH}
    )
endif()
