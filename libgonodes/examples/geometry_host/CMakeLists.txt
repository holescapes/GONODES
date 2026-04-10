cmake_minimum_required(VERSION 3.20)
project(geometry_host LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)

add_executable(geometry_host main.cpp)
target_include_directories(geometry_host PRIVATE ${CMAKE_SOURCE_DIR}/include)
target_link_libraries(geometry_host PRIVATE gonodes)
