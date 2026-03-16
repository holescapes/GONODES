cmake_minimum_required(VERSION 3.20)
project(params_demo LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)

add_executable(params_demo main.cpp)
target_link_libraries(params_demo PRIVATE gonodes)
target_include_directories(params_demo PRIVATE ${CMAKE_SOURCE_DIR}/include)
