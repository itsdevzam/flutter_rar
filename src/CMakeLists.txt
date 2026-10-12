cmake_minimum_required(VERSION 3.10)

project(flutter_rar_library VERSION 0.2.0 LANGUAGES CXX)

set(UNRAR_DIR "${CMAKE_CURRENT_SOURCE_DIR}/unrar")
file(GLOB UNRAR_ALL "${UNRAR_DIR}/*.cpp")

set(UNRAR_EXCLUDE
  arccmt.cpp
  blake2s_sse.cpp
  blake2sp.cpp
  cmdfilter.cpp
  cmdmix.cpp
  coder.cpp
  crypt1.cpp
  crypt2.cpp
  crypt3.cpp
  crypt5.cpp
  hardlinks.cpp
  log.cpp
  model.cpp
  recvol3.cpp
  recvol5.cpp
  suballoc.cpp
  threadmisc.cpp
  uicommon.cpp
  uiconsole.cpp
  uisilent.cpp
  ulinks.cpp
  unpack15.cpp
  unpack20.cpp
  unpack30.cpp
  unpack50.cpp
  unpack50frag.cpp
  unpack50mt.cpp
  unpackinline.cpp
  uowners.cpp
  win32acl.cpp
  win32lnk.cpp
  win32stm.cpp
)

set(UNRAR_SOURCES)
foreach(src ${UNRAR_ALL})
  get_filename_component(name "${src}" NAME)
  list(FIND UNRAR_EXCLUDE "${name}" excluded)
  if(excluded EQUAL -1)
    list(APPEND UNRAR_SOURCES "${src}")
  endif()
endforeach()

add_library(flutter_rar SHARED
  flutter_rar.cpp
  ${UNRAR_SOURCES}
)

set_target_properties(flutter_rar PROPERTIES
  OUTPUT_NAME "flutter_rar"
  CXX_STANDARD 14
  CXX_STANDARD_REQUIRED YES
)

target_include_directories(flutter_rar PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${UNRAR_DIR}"
)

target_compile_definitions(flutter_rar PRIVATE
  RARDLL
  SILENT
  _FILE_OFFSET_BITS=64
  _LARGEFILE_SOURCE
)

if(MSVC)
  target_compile_options(flutter_rar PRIVATE /EHsc /GR)
else()
  target_compile_options(flutter_rar PRIVATE
    -O2
    -fexceptions
    -frtti
    -fvisibility=hidden
    -Wno-dangling-else
    -Wno-unused-function
    -Wno-unused-variable
    -Wno-deprecated-declarations
  )
endif()

if(ANDROID)
  target_link_options(flutter_rar PRIVATE "-Wl,-z,max-page-size=16384")
  target_link_libraries(flutter_rar PRIVATE log)
endif()

find_package(Threads REQUIRED)
target_link_libraries(flutter_rar PRIVATE Threads::Threads)
