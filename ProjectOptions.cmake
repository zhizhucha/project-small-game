include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(project_small_game_supports_sanitizers)
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

macro(project_small_game_setup_options)
  option(project_small_game_ENABLE_HARDENING "Enable hardening" ON)
  option(project_small_game_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    project_small_game_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    project_small_game_ENABLE_HARDENING
    OFF)

  project_small_game_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR project_small_game_PACKAGING_MAINTAINER_MODE)
    option(project_small_game_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(project_small_game_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(project_small_game_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(project_small_game_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(project_small_game_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(project_small_game_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(project_small_game_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(project_small_game_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(project_small_game_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(project_small_game_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(project_small_game_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(project_small_game_ENABLE_PCH "Enable precompiled headers" OFF)
    option(project_small_game_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(project_small_game_ENABLE_IPO "Enable IPO/LTO" ON)
    option(project_small_game_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(project_small_game_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(project_small_game_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(project_small_game_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(project_small_game_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(project_small_game_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(project_small_game_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(project_small_game_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(project_small_game_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(project_small_game_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(project_small_game_ENABLE_PCH "Enable precompiled headers" OFF)
    option(project_small_game_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      project_small_game_ENABLE_IPO
      project_small_game_WARNINGS_AS_ERRORS
      project_small_game_ENABLE_USER_LINKER
      project_small_game_ENABLE_SANITIZER_ADDRESS
      project_small_game_ENABLE_SANITIZER_LEAK
      project_small_game_ENABLE_SANITIZER_UNDEFINED
      project_small_game_ENABLE_SANITIZER_THREAD
      project_small_game_ENABLE_SANITIZER_MEMORY
      project_small_game_ENABLE_UNITY_BUILD
      project_small_game_ENABLE_CLANG_TIDY
      project_small_game_ENABLE_CPPCHECK
      project_small_game_ENABLE_COVERAGE
      project_small_game_ENABLE_PCH
      project_small_game_ENABLE_CACHE)
  endif()

  project_small_game_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (project_small_game_ENABLE_SANITIZER_ADDRESS OR project_small_game_ENABLE_SANITIZER_THREAD OR project_small_game_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(project_small_game_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(project_small_game_global_options)
  if(project_small_game_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    project_small_game_enable_ipo()
  endif()

  project_small_game_supports_sanitizers()

  if(project_small_game_ENABLE_HARDENING AND project_small_game_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR project_small_game_ENABLE_SANITIZER_UNDEFINED
       OR project_small_game_ENABLE_SANITIZER_ADDRESS
       OR project_small_game_ENABLE_SANITIZER_THREAD
       OR project_small_game_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${project_small_game_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${project_small_game_ENABLE_SANITIZER_UNDEFINED}")
    project_small_game_enable_hardening(project_small_game_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(project_small_game_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(project_small_game_warnings INTERFACE)
  add_library(project_small_game_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  project_small_game_set_project_warnings(
    project_small_game_warnings
    ${project_small_game_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(project_small_game_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    project_small_game_configure_linker(project_small_game_options)
  endif()

  include(cmake/Sanitizers.cmake)
  project_small_game_enable_sanitizers(
    project_small_game_options
    ${project_small_game_ENABLE_SANITIZER_ADDRESS}
    ${project_small_game_ENABLE_SANITIZER_LEAK}
    ${project_small_game_ENABLE_SANITIZER_UNDEFINED}
    ${project_small_game_ENABLE_SANITIZER_THREAD}
    ${project_small_game_ENABLE_SANITIZER_MEMORY})

  set_target_properties(project_small_game_options PROPERTIES UNITY_BUILD ${project_small_game_ENABLE_UNITY_BUILD})

  if(project_small_game_ENABLE_PCH)
    target_precompile_headers(
      project_small_game_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(project_small_game_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    project_small_game_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(project_small_game_ENABLE_CLANG_TIDY)
    project_small_game_enable_clang_tidy(project_small_game_options ${project_small_game_WARNINGS_AS_ERRORS})
  endif()

  if(project_small_game_ENABLE_CPPCHECK)
    project_small_game_enable_cppcheck(${project_small_game_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(project_small_game_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    project_small_game_enable_coverage(project_small_game_options)
  endif()

  if(project_small_game_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(project_small_game_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(project_small_game_ENABLE_HARDENING AND NOT project_small_game_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR project_small_game_ENABLE_SANITIZER_UNDEFINED
       OR project_small_game_ENABLE_SANITIZER_ADDRESS
       OR project_small_game_ENABLE_SANITIZER_THREAD
       OR project_small_game_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    project_small_game_enable_hardening(project_small_game_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
