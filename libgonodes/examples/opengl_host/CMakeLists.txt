cmake_minimum_required(VERSION 3.20)
project(opengl_host LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)

find_package(OpenGL REQUIRED)
find_package(glfw3 REQUIRED)

add_executable(opengl_host main.cpp)
target_link_libraries(opengl_host PRIVATE gonodes glfw OpenGL::GL)
target_include_directories(opengl_host PRIVATE ${CMAKE_SOURCE_DIR}/include)
