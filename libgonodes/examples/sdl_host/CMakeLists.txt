cmake_minimum_required(VERSION 3.20)
project(sdl_host LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)

find_package(SDL2 REQUIRED)
find_package(OpenGL REQUIRED)

add_executable(sdl_host main.cpp)
target_link_libraries(sdl_host PRIVATE gonodes SDL2::SDL2 SDL2::SDL2main OpenGL::GL)
target_include_directories(sdl_host PRIVATE ${CMAKE_SOURCE_DIR}/include)
