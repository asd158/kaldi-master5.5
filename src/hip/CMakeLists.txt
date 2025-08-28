# generated with cmake/gen_cmake_skeleton.py, DO NOT MODIFY.
set(PUBLIC_HEADERS
    hipify.h
)

add_library(kaldi-hip INTERFACE)
target_include_directories(kaldi-hip INTERFACE 
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/..>
    $<INSTALL_INTERFACE:include/kaldi>
)


install(TARGETS kaldi-hip EXPORT kaldi-targets)

install(FILES ${PUBLIC_HEADERS} DESTINATION include/kaldi/hip COMPONENT kaldi)

