cmake_minimum_required(VERSION 3.20)
project(midi_osc_host LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)

add_executable(midi_osc_host main.cpp)
target_include_directories(midi_osc_host PRIVATE ${CMAKE_SOURCE_DIR}/include)
target_link_libraries(midi_osc_host PRIVATE gonodes)
