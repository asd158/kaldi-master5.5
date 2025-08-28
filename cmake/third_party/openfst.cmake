CMAKE_MINIMUM_REQUIRED(VERSION 3.14)

SET(openfst_SOURCE_DIR ${CMAKE_CURRENT_LIST_DIR}/openfst-src)
SET(openfst_BINARY_DIR ${CMAKE_BINARY_DIR}/openfst-build)
INCLUDE_DIRECTORIES(${openfst_SOURCE_DIR}/src/include)

ADD_SUBDIRECTORY(${openfst_SOURCE_DIR} ${openfst_BINARY_DIR})

IF (CONDA_ROOT)
    IF (MSVC)
        INSTALL(TARGETS fstarcsort fstclosure fstcompile fstcompose fstconcat fstconnect fstconvert fstdeterminize
                fstdifference fstdisambiguate fstdraw fstencode fstepsnormalize fstequal fstequivalent
                fstinfo fstintersect fstinvert fstisomorphic fstmap fstminimize fstprint fstproject fstprune
                fstpush fstrandgen fstrelabel fstreplace fstreverse fstreweight fstrmepsilon fstshortestdistance
                fstshortestpath fstsymbols fstsynchronize fsttopsort fstunion
                RUNTIME
                DESTINATION ${CMAKE_INSTALL_BINDIR}
                COMPONENT kaldi
                )
        INSTALL(TARGETS farcompilestrings farcreate farequal farextract farinfo farisomorphic farprintstrings
                RUNTIME
                DESTINATION ${CMAKE_INSTALL_BINDIR}
                COMPONENT kaldi
                )
        INSTALL(TARGETS fstlinear fstloglinearapply
                RUNTIME
                DESTINATION ${CMAKE_INSTALL_BINDIR}
                COMPONENT kaldi
                )
        INSTALL(TARGETS mpdtcompose mpdtexpand mpdtinfo mpdtreverse
                RUNTIME
                DESTINATION ${CMAKE_INSTALL_BINDIR}
                COMPONENT kaldi
                )
        INSTALL(TARGETS pdtcompose pdtexpand pdtinfo pdtreplace pdtreverse pdtshortestpath
                RUNTIME
                DESTINATION ${CMAKE_INSTALL_BINDIR}
                COMPONENT kaldi
                )
        INSTALL(TARGETS fstspecial
                RUNTIME
                DESTINATION ${CMAKE_INSTALL_BINDIR}
                COMPONENT kaldi
                )

        INSTALL(DIRECTORY ${openfst_SOURCE_DIR}/src/include/ DESTINATION include/
                COMPONENT kaldi
                FILES_MATCHING PATTERN "*.h")

        INSTALL(TARGETS fst
                EXPORT kaldi-targets
                ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT kaldi
                LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT kaldi NAMELINK_SKIP
                RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT kaldi)
    ELSE ()

        INSTALL(TARGETS fst
                LIBRARY
                DESTINATION ${CMAKE_INSTALL_LIBDIR}
                COMPONENT kaldi
                NAMELINK_SKIP # Link to so with version to avoid conflicts with OpenFst 1.8.1 on conda
                )

    ENDIF ()

ELSE () # Original functionality
    INSTALL(DIRECTORY ${openfst_SOURCE_DIR}/src/include/ DESTINATION include/
            FILES_MATCHING PATTERN "*.h")
    INSTALL(TARGETS fst
            EXPORT kaldi-targets
            ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
            LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
            RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
ENDIF ()
