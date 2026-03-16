cmake_minimum_required(VERSION 3.20)
project(metal_host LANGUAGES CXX OBJCXX)

set(CMAKE_CXX_STANDARD 17)

find_library(METAL_FRAMEWORK Metal REQUIRED)
find_library(METALKIT_FRAMEWORK MetalKit REQUIRED)
find_library(COCOA_FRAMEWORK Cocoa REQUIRED)

add_executable(metal_host main.mm)
target_link_libraries(metal_host PRIVATE
    gonodes
    ${METAL_FRAMEWORK}
    ${METALKIT_FRAMEWORK}
    ${COCOA_FRAMEWORK}
)
target_include_directories(metal_host PRIVATE ${CMAKE_SOURCE_DIR}/include)
