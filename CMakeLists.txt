CMAKE_MINIMUM_REQUIRED(VERSION 3.16)
PROJECT(kaldi)

IF (CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    SET(CMAKE_INSTALL_PREFIX ${CMAKE_CURRENT_SOURCE_DIR}/src CACHE PATH "Install path prefix." FORCE)
ENDIF (CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
SET(CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake;${CMAKE_MODULE_PATH}")
INCLUDE(GNUInstallDirs)
INCLUDE(Utils)

IF (CONDA_ROOT)
    MESSAGE(STATUS "Adding ${CONDA_ROOT} directories")
    SET(CMAKE_INCLUDE_PATH "${CONDA_ROOT}/include")
    SET(CMAKE_LIBRARY_PATH "${CONDA_ROOT}/lib")
    LINK_DIRECTORIES("${CONDA_ROOT}/lib")
    INCLUDE_DIRECTORIES("${CONDA_ROOT}/include")
    IF (NOT CUDA_TOOLKIT_ROOT_DIR)
        SET(CUDA_TOOLKIT_ROOT_DIR "${CONDA_ROOT}")
    ENDIF ()

ENDIF ()

OPTION(BuildForFedora "Build for Fedora. Means that everything is build with Border tools" NO)

IF (BuildForFedora)

    # You also need to install sudo dnf install lapack-devel openfst-devel
    SET(CMAKE_CXX_STANDARD 17)
    SET(CMAKE_CXX_STANDARD_REQUIRED ON)
    SET(CMAKE_CXX_EXTENSIONS OFF)

    #find_package(PkgConfig REQUIRED)

    #pkg_check_modules(FST REQUIRED fst)

ELSE ()
        INCLUDE(cmake/third_party/openfst.cmake)
ENDIF ()

FIND_PACKAGE(Python3 COMPONENTS Interpreter)
IF (Python3_FOUND)
    SET(PYTHON_EXECUTABLE ${Python3_EXECUTABLE})
ENDIF ()

MESSAGE(STATUS "Running gen_cmake_skeleton.py")
OPTION(BUILD_SHARED_LIBS "Build shared Kaldi libraries." OFF)
SET(IS_LIB_SHARE "")
IF (BUILD_SHARED_LIBS)
    SET(IS_LIB_SHARE "--shared")
ENDIF ()
EXECUTE_PROCESS(COMMAND ${PYTHON_EXECUTABLE}
                "${CMAKE_CURRENT_SOURCE_DIR}/cmake/gen_cmake_skeleton.py"
                "${CMAKE_CURRENT_SOURCE_DIR}/src"
                "--quiet"
                ${IS_LIB_SHARE}
                )
UNSET(IS_LIB_SHARE)

IF (BuildForFedora)
ELSE ()
    SET(CMAKE_CXX_STANDARD 14)
    SET(CMAKE_CXX_EXTENSIONS OFF)
ENDIF ()
SET(CMAKE_INSTALL_MESSAGE LAZY) # hide "-- Up-to-date: ..."
IF (BUILD_SHARED_LIBS)
    SET(CMAKE_POSITION_INDEPENDENT_CODE ON)
    IF (WIN32)
        SET(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)
        MESSAGE(FATAL_ERROR "DLL is not supported currently")
    ELSEIF (APPLE)
        SET(CMAKE_INSTALL_RPATH "@loader_path")
    ELSE ()
        SET(CMAKE_INSTALL_RPATH "$ORIGIN;$ORIGIN/../lib;$ORIGIN/../../tools/openfst/lib")
    ENDIF ()
ENDIF ()

IF (APPLE)
    # Use built-in BLAS on MacOS by default.
    SET(MATHLIB "Accelerate" CACHE STRING "OpenBLAS|MKL|Accelerate")
ELSE ()
    SET(MATHLIB "OpenBLAS" CACHE STRING "OpenBLAS|MKL|Accelerate")
ENDIF ()
OPTION(KALDI_BUILD_EXE "If disabled, will make add_kaldi_executable a no-op" OFF)
OPTION(KALDI_BUILD_TEST "If disabled, will make add_kaldi_test_executable a no-op" OFF)
OPTION(KALDI_USE_PATCH_NUMBER "Use MAJOR.MINOR.PATCH format, otherwise MAJOR.MINOR" OFF)

IF (KALDI_BUILD_TEST)
    INCLUDE(CTest)
    ENABLE_TESTING()
ENDIF ()

LINK_LIBRARIES(${CMAKE_DL_LIBS})

FIND_PACKAGE(Threads)
LINK_LIBRARIES(Threads::Threads)

IF (CONDA_ROOT)
    FIND_PACKAGE(BLAS REQUIRED)
    FIND_PACKAGE(LAPACK REQUIRED)
    LINK_LIBRARIES(BLAS::BLAS)
    LINK_LIBRARIES(LAPACK::LAPACK)
    # OPENBLAS is equivalent to LAPACKE; see
    # https://github.com/kaldi-asr/kaldi/blob/master/src/matrix/kaldi-blas.h#L95-L113
    ADD_DEFINITIONS(-DHAVE_OPENBLAS=1)
    IF (MSVC)
        LINK_LIBRARIES(cblas lapack)
        # necessary macros to compile on windows, from here:
        # https://icl.cs.utk.edu/lapack-for-windows/lapack/
        ADD_DEFINITIONS(-DADD_)
        ADD_DEFINITIONS(-DHAVE_LAPACK_CONFIG_H)
        ADD_DEFINITIONS(-DLAPACK_COMPLEX_STRUCTURE)
    ELSE ()
        INCLUDE_DIRECTORIES($ENV{PREFIX}/include)
    ENDIF ()
ELSE ()
    IF (MATHLIB STREQUAL "OpenBLAS")
        ADD_DEFINITIONS(-DHAVE_CLAPACK=1)
        INCLUDE_DIRECTORIES(${CMAKE_CURRENT_SOURCE_DIR}/tools/CLAPACK)
        LINK_LIBRARIES(${BLAS_LIBRARIES} ${LAPACK_LIBRARIES})
    ELSEIF (MATHLIB STREQUAL "MKL")
        IF (NOT DEFINED ENV{MKLROOT} OR "$ENV{MKLROOT}" STREQUAL "")
            MESSAGE(FATAL_ERROR "Environment variable MKLROOT is not defined")
        ELSE ()
            MESSAGE(STATUS "Finding MKL from \"$ENV{MKLROOT}\"")
        ENDIF ()
        NORMALIZE_ENV_PATH(ENV{MKLROOT})
        SET(BLA_VENDOR "Intel10_64lp_seq") # use the single threaded MKL by default
        FIND_PACKAGE(LAPACK REQUIRED)
        ADD_DEFINITIONS(-DHAVE_MKL=1)
        INCLUDE_DIRECTORIES($ENV{MKLROOT}/include)
        LINK_LIBRARIES(${BLAS_LIBRARIES} ${LAPACK_LIBRARIES})
    ELSEIF (MATHLIB STREQUAL "Accelerate")
        EXECUTE_PROCESS(COMMAND sw_vers -productVersion
                        OUTPUT_VARIABLE MACOS_VERSION)
        IF (MACOS_VERSION VERSION_LESS "10.12" AND MACOS_VERSION VERSION_GREATER_EQUAL "10.11")
            MESSAGE(WARNING
                    "**BAD WARNING**: You are using OS X El Capitan.  Some versions of this OS"
                    " have a bug in the BLAS implementation that affects Kaldi."
                    " After compiling, cd to matrix/ and type 'make test'.  The"
                    " test will fail if the problem exists in your version."
                    " Eventually this issue will be fixed by system updates from"
                    " Apple.  Unexplained crashes with reports of NaNs will"
                    " be caused by this bug, but some recipes will (sometimes) work."
                    )
        ENDIF ()
        SET(BLA_VENDOR "Apple")
        FIND_PACKAGE(BLAS REQUIRED)
        FIND_PACKAGE(LAPACK REQUIRED)
        ADD_DEFINITIONS(-DHAVE_CLAPACK=1)
        LINK_LIBRARIES(${BLAS_LIBRARIES} ${LAPACK_LIBRARIES})
    ELSE ()
        MESSAGE(FATAL_ERROR "${MATHLIB} is not tested and supported, you are on your own now.")
    ENDIF ()
ENDIF ()

IF (MSVC)
    # Added in source, but we actually should do it in build script, whatever...
    # add_definitions(-DWIN32_LEAN_AND_MEAN=1)

    ADD_COMPILE_OPTIONS(/permissive- /FS /wd4819 /EHsc /bigobj)

    # some warnings related with fst
    ADD_COMPILE_OPTIONS(/wd4018 /wd4244 /wd4267 /wd4291 /wd4305)

    SET(CompilerFlags
        CMAKE_CXX_FLAGS
        CMAKE_CXX_FLAGS_DEBUG
        CMAKE_CXX_FLAGS_RELEASE
        CMAKE_C_FLAGS
        CMAKE_C_FLAGS_DEBUG
        CMAKE_C_FLAGS_RELEASE
        )
    FOREACH (CompilerFlag ${CompilerFlags})
        STRING(REPLACE "/MD" "/MT" ${CompilerFlag} "${${CompilerFlag}}")
    ENDFOREACH ()
    SET(CUDA_USE_STATIC_CUDA_RUNTIME OFF CACHE INTERNAL "")
    IF (NOT DEFINED ENV{CUDAHOSTCXX})
        SET(ENV{CUDAHOSTCXX} ${CMAKE_CXX_COMPILER})
    ENDIF ()
    IF (NOT DEFINED CUDA_HOST_COMPILER)
        SET(CUDA_HOST_COMPILER ${CMAKE_CXX_COMPILER})
    ENDIF ()
ENDIF ()

#FIND_PACKAGE(CUDA)
###############################
####先强制关闭cuda编译
SET(CUDA_FOUND OFF)
IF (CUDA_FOUND)
    SET(CUDA_PROPAGATE_HOST_FLAGS ON)
    IF (MSVC)
        SET(KALDI_CUDA_NVCC_FLAGS "--default-stream=per-thread") # Fixes incompatibility with cxx14 and cxx17 for Kaldi vs cuda in VS2019
        LIST(APPEND KALDI_CUDA_NVCC_FLAGS "-Xcompiler /permissive-,/FS,/wd4819,/EHsc,/bigobj")
        LIST(APPEND KALDI_CUDA_NVCC_FLAGS "-Xcompiler /wd4018,/wd4244,/wd4267,/wd4291,/wd4305")
        LIST(APPEND CUDA_NVCC_FLAGS_RELEASE -Xcompiler /MD) # Kaldi will always be dynamically linked to Cuda
        LIST(APPEND CUDA_NVCC_FLAGS_DEBUG -Xcompiler /MDd)
    ELSE ()
        #     list(APPEND KALDI_CUDA_NVCC_FLAGS "-Xcompiler -std=c++${CMAKE_CXX_STANDARD}")
        LIST(APPEND KALDI_CUDA_NVCC_FLAGS "-Xcompiler -fPIC")
        SET(KALDI_CUDA_NVCC_FLAGS "--default-stream=per-thread;-std=c++${CMAKE_CXX_STANDARD}")
    ENDIF ()
    SET(CUDA_NVCC_FLAGS ${KALDI_CUDA_NVCC_FLAGS} ${CUDA_NVCC_FLAGS})

    ADD_DEFINITIONS(-DHAVE_CUDA=1)
    ADD_DEFINITIONS(-DCUDA_API_PER_THREAD_DEFAULT_STREAM=1)
    LINK_LIBRARIES(
            ${CUDA_LIBRARIES}
            ${CUDA_CUDA_LIBRARY}
            ${CUDA_CUBLAS_LIBRARIES}
            ${CUDA_CUFFT_LIBRARIES}
            ${CUDA_curand_LIBRARY}
            ${CUDA_cusolver_LIBRARY}
            ${CUDA_cusparse_LIBRARY})

    FIND_PACKAGE(NvToolExt REQUIRED)
    INCLUDE_DIRECTORIES(${NvToolExt_INCLUDE_DIR})
    LINK_LIBRARIES(${NvToolExt_LIBRARIES})

    FIND_PACKAGE(CUB REQUIRED)
    INCLUDE_DIRECTORIES(${CUB_INCLUDE_DIR})
ENDIF ()

ADD_DEFINITIONS(-DKALDI_NO_PORTAUDIO=1)

IF (KALDI_VERSION)
    MESSAGE(STATUS "KALDI_VERSION set to \"${KALDI_VERSION}\"")
ELSE () # Original functionality
    MESSAGE(STATUS "Setting KALDI_VERSION with get_version...")
    INCLUDE(VersionHelper)
    GET_VERSION() # this will set KALDI_VERSION and KALDI_PATCH_NUMBER
    IF (${KALDI_USE_PATCH_NUMBER})
        SET(KALDI_VERSION "${KALDI_VERSION}.${KALDI_PATCH_NUMBER}")
    ENDIF ()
ENDIF ()

# get_third_party(openfst)
# set(OPENFST_ROOT_DIR ${CMAKE_CURRENT_BINARY_DIR}/openfst)
# include(third_party/openfst_lib_target)
#find_library(OpenFST_LIBRARY
#            NAMES fst
#            PATHS ${CMAKE_CURRENT_SOURCE_DIR}/tools/openfst/lib
#            REQUIRED)
#find_path(OpenFST_INCLUDE_DIR
#            NAMES "fst/fst.h"
#            PATHS "${CMAKE_CURRENT_SOURCE_DIR}/tools/openfst/include"
#            REQUIRED)

IF (BuildForFedora)
    # Version used used by Fedora 41 is 1.83
    # TODO: Detect the right version and put it here.
    ADD_DEFINITIONS(-DOPENFST_VER=18300)
    #    link_directories(/usr/lib64)
    #    include_directories(/usr/include/fst)
ENDIF ()

LINK_LIBRARIES(fst)

# add all native libraries
ADD_SUBDIRECTORY(src/base) # NOTE, we need to patch the target with version from outside
SET_PROPERTY(TARGET kaldi-base PROPERTY COMPILE_DEFINITIONS "KALDI_VERSION=\"${KALDI_VERSION}\"")
ADD_SUBDIRECTORY(src/matrix)
ADD_SUBDIRECTORY(src/cudamatrix)
ADD_SUBDIRECTORY(src/util)
ADD_SUBDIRECTORY(src/feat)
ADD_SUBDIRECTORY(src/tree)
ADD_SUBDIRECTORY(src/gmm)
ADD_SUBDIRECTORY(src/transform)
ADD_SUBDIRECTORY(src/fstext)
ADD_SUBDIRECTORY(src/hmm)
ADD_SUBDIRECTORY(src/lm)
ADD_SUBDIRECTORY(src/decoder)
ADD_SUBDIRECTORY(src/lat)
ADD_SUBDIRECTORY(src/nnet)
ADD_SUBDIRECTORY(src/nnet2)
ADD_SUBDIRECTORY(src/nnet3)
ADD_SUBDIRECTORY(src/rnnlm)
ADD_SUBDIRECTORY(src/chain)
ADD_SUBDIRECTORY(src/ivector)
IF (NOT MSVC)
    ADD_SUBDIRECTORY(src/online)
ENDIF ()
ADD_SUBDIRECTORY(src/online2)
ADD_SUBDIRECTORY(src/kws)

ADD_SUBDIRECTORY(src/itf)

IF (TENSORFLOW_DIR)
    ADD_SUBDIRECTORY(src/tfrnnlm)
    ADD_SUBDIRECTORY(src/tfrnnlmbin)
ENDIF ()

# add all cuda libraries
IF (CUDA_FOUND)
    ADD_SUBDIRECTORY(src/cudafeat)
    ADD_SUBDIRECTORY(src/cudadecoder)
ENDIF ()

# add all native executables
ADD_SUBDIRECTORY(src/bin)
ADD_SUBDIRECTORY(src/gmmbin)
ADD_SUBDIRECTORY(src/featbin)
ADD_SUBDIRECTORY(src/fstbin)
ADD_SUBDIRECTORY(src/lmbin)
ADD_SUBDIRECTORY(src/latbin)
ADD_SUBDIRECTORY(src/nnetbin)
ADD_SUBDIRECTORY(src/nnet2bin)
ADD_SUBDIRECTORY(src/nnet3bin)
ADD_SUBDIRECTORY(src/rnnlmbin)
ADD_SUBDIRECTORY(src/chainbin)
ADD_SUBDIRECTORY(src/ivectorbin)
IF (NOT MSVC)
    ADD_SUBDIRECTORY(src/onlinebin)
    ADD_SUBDIRECTORY(src/online2bin)
ENDIF ()
ADD_SUBDIRECTORY(src/kwsbin)

# add all cuda executables
IF (CUDA_FOUND)
    ADD_SUBDIRECTORY(src/cudafeatbin)
    ADD_SUBDIRECTORY(src/cudadecoderbin)
ENDIF ()

IF (NOT CONDA_ROOT)
    INCLUDE(CMakePackageConfigHelpers)
    # maybe we should put this into subfolder?
    CONFIGURE_PACKAGE_CONFIG_FILE(
            ${CMAKE_CURRENT_SOURCE_DIR}/cmake/kaldi-config.cmake.in
            ${CMAKE_CURRENT_BINARY_DIR}/cmake/kaldi-config.cmake
            INSTALL_DESTINATION lib/cmake/kaldi
            )
    WRITE_BASIC_PACKAGE_VERSION_FILE(
            ${CMAKE_CURRENT_BINARY_DIR}/cmake/kaldi-config-version.cmake
            VERSION ${KALDI_VERSION}
            COMPATIBILITY AnyNewerVersion
            )
    INSTALL(FILES ${CMAKE_CURRENT_BINARY_DIR}/cmake/kaldi-config.cmake ${CMAKE_CURRENT_BINARY_DIR}/cmake/kaldi-config-version.cmake
            DESTINATION lib/cmake/kaldi
            )
    INSTALL(EXPORT kaldi-targets DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/cmake/kaldi)
ENDIF ()
