cmake_minimum_required(VERSION 3.10)

set(PROJECT_NAME "flutter_rar")
project(${PROJECT_NAME} LANGUAGES CXX)

add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../src" "${CMAKE_CURRENT_BINARY_DIR}/shared")

set(flutter_rar_bundled_libraries
  $<TARGET_FILE:flutter_rar>
  PARENT_SCOPE
)
