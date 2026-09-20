cmake_minimum_required(VERSION 3.20)

project(calcx_launcher LANGUAGES CXX)

if(NOT WIN32)
  message(FATAL_ERROR "calcx launcher supports Windows only")
endif()

add_executable(calcx main.cpp)
target_compile_features(calcx PRIVATE cxx_std_17)

if(MSVC)
  target_compile_options(calcx PRIVATE /W4 /O2 /utf-8)
else()
  target_compile_options(calcx PRIVATE -Wall -Wextra -Wpedantic -O2)
  if(MINGW)
    target_link_options(calcx PRIVATE -municode -static -static-libgcc -static-libstdc++)
  endif()
endif()
