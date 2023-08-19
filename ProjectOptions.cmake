include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(systems_engine_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(systems_engine_setup_options)
  option(systems_engine_ENABLE_HARDENING "Enable hardening" ON)
  option(systems_engine_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    systems_engine_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    systems_engine_ENABLE_HARDENING
    OFF)

  systems_engine_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR systems_engine_PACKAGING_MAINTAINER_MODE)
    option(systems_engine_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(systems_engine_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(systems_engine_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(systems_engine_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(systems_engine_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(systems_engine_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(systems_engine_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(systems_engine_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(systems_engine_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(systems_engine_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(systems_engine_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(systems_engine_ENABLE_PCH "Enable precompiled headers" OFF)
    option(systems_engine_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(systems_engine_ENABLE_IPO "Enable IPO/LTO" ON)
    option(systems_engine_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(systems_engine_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(systems_engine_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(systems_engine_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(systems_engine_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(systems_engine_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(systems_engine_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(systems_engine_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(systems_engine_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(systems_engine_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(systems_engine_ENABLE_PCH "Enable precompiled headers" OFF)
    option(systems_engine_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      systems_engine_ENABLE_IPO
      systems_engine_WARNINGS_AS_ERRORS
      systems_engine_ENABLE_USER_LINKER
      systems_engine_ENABLE_SANITIZER_ADDRESS
      systems_engine_ENABLE_SANITIZER_LEAK
      systems_engine_ENABLE_SANITIZER_UNDEFINED
      systems_engine_ENABLE_SANITIZER_THREAD
      systems_engine_ENABLE_SANITIZER_MEMORY
      systems_engine_ENABLE_UNITY_BUILD
      systems_engine_ENABLE_CLANG_TIDY
      systems_engine_ENABLE_CPPCHECK
      systems_engine_ENABLE_COVERAGE
      systems_engine_ENABLE_PCH
      systems_engine_ENABLE_CACHE)
  endif()

  systems_engine_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (systems_engine_ENABLE_SANITIZER_ADDRESS OR systems_engine_ENABLE_SANITIZER_THREAD OR systems_engine_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(systems_engine_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(systems_engine_global_options)
  if(systems_engine_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    systems_engine_enable_ipo()
  endif()

  systems_engine_supports_sanitizers()

  if(systems_engine_ENABLE_HARDENING AND systems_engine_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR systems_engine_ENABLE_SANITIZER_UNDEFINED
       OR systems_engine_ENABLE_SANITIZER_ADDRESS
       OR systems_engine_ENABLE_SANITIZER_THREAD
       OR systems_engine_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${systems_engine_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${systems_engine_ENABLE_SANITIZER_UNDEFINED}")
    systems_engine_enable_hardening(systems_engine_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(systems_engine_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(systems_engine_warnings INTERFACE)
  add_library(systems_engine_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  systems_engine_set_project_warnings(
    systems_engine_warnings
    ${systems_engine_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(systems_engine_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(systems_engine_options)
  endif()

  include(cmake/Sanitizers.cmake)
  systems_engine_enable_sanitizers(
    systems_engine_options
    ${systems_engine_ENABLE_SANITIZER_ADDRESS}
    ${systems_engine_ENABLE_SANITIZER_LEAK}
    ${systems_engine_ENABLE_SANITIZER_UNDEFINED}
    ${systems_engine_ENABLE_SANITIZER_THREAD}
    ${systems_engine_ENABLE_SANITIZER_MEMORY})

  set_target_properties(systems_engine_options PROPERTIES UNITY_BUILD ${systems_engine_ENABLE_UNITY_BUILD})

  if(systems_engine_ENABLE_PCH)
    target_precompile_headers(
      systems_engine_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(systems_engine_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    systems_engine_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(systems_engine_ENABLE_CLANG_TIDY)
    systems_engine_enable_clang_tidy(systems_engine_options ${systems_engine_WARNINGS_AS_ERRORS})
  endif()

  if(systems_engine_ENABLE_CPPCHECK)
    systems_engine_enable_cppcheck(${systems_engine_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(systems_engine_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    systems_engine_enable_coverage(systems_engine_options)
  endif()

  if(systems_engine_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(systems_engine_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(systems_engine_ENABLE_HARDENING AND NOT systems_engine_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR systems_engine_ENABLE_SANITIZER_UNDEFINED
       OR systems_engine_ENABLE_SANITIZER_ADDRESS
       OR systems_engine_ENABLE_SANITIZER_THREAD
       OR systems_engine_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    systems_engine_enable_hardening(systems_engine_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
