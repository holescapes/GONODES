cmake_minimum_required(VERSION 3.20)
project(graph_edit_demo LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)

add_executable(graph_edit_demo main.cpp)
target_include_directories(graph_edit_demo PRIVATE ${CMAKE_SOURCE_DIR}/include)
target_link_libraries(graph_edit_demo PRIVATE gonodes)
