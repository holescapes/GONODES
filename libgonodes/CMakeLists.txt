cmake_minimum_required(VERSION 3.20)
project(libgonodes VERSION 1.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ═══════════════════════════════════════════════════════════════════════════════
# Options
# ═══════════════════════════════════════════════════════════════════════════════

option(GONODES_BUILD_EXAMPLES  "Build example host applications" ON)
option(GONODES_BUILD_SHARED    "Build as shared library (DLL)"   ON)

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

    # v1.1.0: Geometry Host Example
    add_subdirectory(examples/geometry_host EXCLUDE_FROM_ALL)

    # v1.1.0: Graph Edit Demo Example
    add_subdirectory(examples/graph_edit_demo EXCLUDE_FROM_ALL)

    # v1.1.0: MIDI/OSC Host Example
    add_subdirectory(examples/midi_osc_host EXCLUDE_FROM_ALL)
endif()
