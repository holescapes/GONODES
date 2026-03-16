cmake_minimum_required(VERSION 3.20)
project(vulkan_host LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)

find_package(Vulkan REQUIRED)

add_executable(vulkan_host main.cpp)
target_link_libraries(vulkan_host PRIVATE gonodes Vulkan::Vulkan)
target_include_directories(vulkan_host PRIVATE ${CMAKE_SOURCE_DIR}/include)
