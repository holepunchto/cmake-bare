include_guard()

find_package(cmake-npm REQUIRED PATHS node_modules/cmake-npm)

set(bare_module_dir "${CMAKE_CURRENT_LIST_DIR}")

function(download_bare result)
  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "" "DESTINATION;IMPORT_FILE;VERSION" ""
  )

  if(NOT ARGV_DESTINATION)
    set(ARGV_DESTINATION "${CMAKE_CURRENT_BINARY_DIR}/_bare")
  endif()

  if(NOT ARGV_VERSION)
    set(ARGV_VERSION "latest")
  endif()

  if(NOT EXISTS "${ARGV_DESTINATION}/package.json")
    file(WRITE "${ARGV_DESTINATION}/package.json" "{}")
  endif()

  bare_target(target)

  install_node_module(
    bare-runtime-${target}
    VERSION ${ARGV_VERSION}
    WORKING_DIRECTORY "${ARGV_DESTINATION}"
    FORCE
  )

  resolve_node_module(
    bare-runtime-${target}
    output
    WORKING_DIRECTORY "${ARGV_DESTINATION}"
  )

  set(import_file ${ARGV_IMPORT_FILE})

  if(target MATCHES "win32")
    cmake_path(APPEND output bin bare.exe OUTPUT_VARIABLE ${result})

    if(import_file)
      cmake_path(APPEND output lib bare.lib OUTPUT_VARIABLE ${import_file})
    endif()
  else()
    cmake_path(APPEND output bin bare OUTPUT_VARIABLE ${result})

    if(import_file)
      if(target MATCHES "darwin|ios")
        cmake_path(APPEND output lib libbare.tbd OUTPUT_VARIABLE ${import_file})
      else()
        set(${import_file} ${import_file}-NOTFOUND)
      endif()
    endif()
  endif()

  return(PROPAGATE ${result} ${import_file})
endfunction()

function(download_bare_headers result)
  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "" "DESTINATION;VERSION" ""
  )

  if(NOT ARGV_DESTINATION)
    set(ARGV_DESTINATION "${CMAKE_CURRENT_BINARY_DIR}/_bare")
  endif()

  if(NOT ARGV_VERSION)
    set(ARGV_VERSION "latest")
  endif()

  if(NOT EXISTS "${ARGV_DESTINATION}/package.json")
    file(WRITE "${ARGV_DESTINATION}/package.json" "{}")
  endif()

  install_node_module(
    bare-headers
    VERSION ${ARGV_VERSION}
    WORKING_DIRECTORY "${ARGV_DESTINATION}"
    FORCE
  )

  resolve_node_module(
    bare-headers
    output
    WORKING_DIRECTORY "${ARGV_DESTINATION}"
  )

  cmake_path(APPEND output include OUTPUT_VARIABLE ${result})

  return(PROPAGATE ${result})
endfunction()

function(bare_platform result)
  set(platform ${CMAKE_SYSTEM_NAME})

  if(NOT platform)
    set(platform ${CMAKE_HOST_SYSTEM_NAME})
  endif()

  string(TOLOWER "${platform}" platform)

  if(platform MATCHES "darwin|ios|linux|android")
    set(${result} ${platform})
  elseif(platform MATCHES "windows")
    set(${result} "win32")
  else()
    set(${result} "unknown")
  endif()

  return(PROPAGATE ${result})
endfunction()

function(bare_arch result)
  if(APPLE AND CMAKE_OSX_ARCHITECTURES)
    set(arch ${CMAKE_OSX_ARCHITECTURES})
  elseif(MSVC AND CMAKE_GENERATOR_PLATFORM)
    set(arch ${CMAKE_GENERATOR_PLATFORM})
  elseif(ANDROID AND CMAKE_ANDROID_ARCH_ABI)
    set(arch ${CMAKE_ANDROID_ARCH_ABI})
  else()
    set(arch ${CMAKE_SYSTEM_PROCESSOR})
  endif()

  if(NOT arch)
    set(arch ${CMAKE_HOST_SYSTEM_PROCESSOR})
  endif()

  string(TOLOWER "${arch}" arch)

  if(arch MATCHES "arm64|aarch64")
    set(${result} "arm64")
  elseif(arch MATCHES "armv7-a|armeabi-v7a")
    set(${result} "arm")
  elseif(arch MATCHES "x64|x86_64|amd64")
    set(${result} "x64")
  elseif(arch MATCHES "x86|i386|i486|i586|i686")
    set(${result} "ia32")
  else()
    set(${result} "unknown")
  endif()

  return(PROPAGATE ${result})
endfunction()

function(bare_simulator result)
  set(sysroot ${CMAKE_OSX_SYSROOT})

  if(sysroot MATCHES "iPhoneSimulator")
    set(${result} YES)
  else()
    set(${result} NO)
  endif()

  return(PROPAGATE ${result})
endfunction()

function(bare_target result)
  bare_platform(platform)
  bare_arch(arch)
  bare_simulator(simulator)

  set(target ${platform}-${arch})

  if(simulator)
    set(target ${target}-simulator)
  endif()

  set(${result} ${target})

  return(PROPAGATE ${result})
endfunction()

function(bare_module_target directory result)
  cmake_parse_arguments(
    PARSE_ARGV 2 ARGV "" "NAME;VERSION;HASH" ""
  )

  set(package_path package.json)

  cmake_path(ABSOLUTE_PATH directory NORMALIZE)

  cmake_path(ABSOLUTE_PATH package_path BASE_DIRECTORY "${directory}" NORMALIZE)

  file(READ "${package_path}" package)

  string(JSON name GET "${package}" "name")

  string(REGEX REPLACE "/" "+" name ${name})

  string(JSON version GET "${package}" "version")

  string(SHA256 hash "bare ${package_path}")

  string(SUBSTRING "${hash}" 0 8 hash)

  set(${result} "${name}-${version}-${hash}")

  if(ARGV_NAME)
    set(${ARGV_NAME} ${name})
  endif()

  if(ARGV_VERSION)
    set(${ARGV_VERSION} ${version})
  endif()

  if(ARGV_HASH)
    set(${ARGV_HASH} ${hash})
  endif()

  return(PROPAGATE ${result} ${ARGV_NAME} ${ARGV_VERSION} ${ARGV_HASH})
endfunction()

function(add_bare_module result)
  download_bare(bare_bin IMPORT_FILE bare_lib)

  download_bare_headers(bare_headers)

  bare_module_target("." target NAME name)

  add_library(${target} OBJECT)

  set_target_properties(
    ${target}
    PROPERTIES
    C_STANDARD 11
    CXX_STANDARD 20
    POSITION_INDEPENDENT_CODE ON
  )

  target_include_directories(
    ${target}
    PRIVATE
      ${bare_headers}
  )

  set(${result} ${target})

  bare_target(host)

  add_executable(${target}_import_library IMPORTED)

  set_target_properties(
    ${target}_import_library
    PROPERTIES
    ENABLE_EXPORTS ON
    IMPORTED_LOCATION "${bare_bin}"
    IMPORTED_IMPLIB "${bare_lib}"
  )

  add_library(${target}_module SHARED)

  set_target_properties(
    ${target}_module
    PROPERTIES
    OUTPUT_NAME ${name}
    PREFIX ""
    SUFFIX ".bare"
    IMPORT_PREFIX ""
    IMPORT_SUFFIX ".bare.lib"
    INSTALL_RPATH ""
    INSTALL_NAME_DIR ""

    # Automatically export all available symbols on Windows. Without this,
    # module authors would have to explicitly export public symbols.
    WINDOWS_EXPORT_ALL_SYMBOLS ON
  )

  if(host MATCHES "win32")
    if(NOT TARGET bare_delay_load)
      add_library(bare_delay_load STATIC)

      target_sources(
        bare_delay_load
        PRIVATE
          "${bare_module_dir}/win32/delay-load.c"
      )

      target_link_libraries(
        bare_delay_load
        INTERFACE
          delayimp
      )

      target_link_options(
        bare_delay_load
        INTERFACE
          /DELAYLOAD:bare.exe
          /DELAYLOAD:bare.dll
      )
    endif()

    target_link_libraries(
      ${target}_module
      PUBLIC
        bare_delay_load
    )

    target_link_options(
      ${target}_module
      INTERFACE
        /DELAYLOAD:${name}.bare
    )
  endif()

  target_link_libraries(
    ${target}_module
    PRIVATE
      ${target}
      ${target}_import_library
  )

  if(host MATCHES "win32")
    install(
      TARGETS ${target}_module
      RUNTIME DESTINATION ${host}
    )
  else()
    install(
      TARGETS ${target}_module
      LIBRARY DESTINATION ${host}
    )
  endif()

  return(PROPAGATE ${result})
endfunction()

function(include_bare_module specifier result)
  cmake_parse_arguments(
    PARSE_ARGV 2 ARGV "" "SOURCE_DIR;BINARY_DIR;WORKING_DIRECTORY" ""
  )

  if(ARGV_WORKING_DIRECTORY)
    cmake_path(ABSOLUTE_PATH ARGV_WORKING_DIRECTORY BASE_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}" NORMALIZE)
  else()
    set(ARGV_WORKING_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}")
  endif()

  resolve_node_module(
    ${specifier}
    source_dir
    WORKING_DIRECTORY "${ARGV_WORKING_DIRECTORY}"
  )

  bare_module_target("${source_dir}" target)

  set(${result} ${target})

  cmake_path(RELATIVE_PATH source_dir BASE_DIRECTORY "${ARGV_WORKING_DIRECTORY}" OUTPUT_VARIABLE binary_dir)

  if(ARGV_SOURCE_DIR)
    set(${ARGV_SOURCE_DIR} "${source_dir}" PARENT_SCOPE)
  endif()

  if(ARGV_BINARY_DIR)
    set(${ARGV_BINARY_DIR} "${binary_dir}" PARENT_SCOPE)
  endif()

  if(NOT TARGET ${target})
    add_subdirectory("${source_dir}" "${binary_dir}" EXCLUDE_FROM_ALL)
  endif()

  return(PROPAGATE ${result})
endfunction()

function(link_bare_module receiver specifier)
  cmake_parse_arguments(
    PARSE_ARGV 2 ARGV "SHARED" "WORKING_DIRECTORY" ""
  )

  if(ARGV_WORKING_DIRECTORY)
    cmake_path(ABSOLUTE_PATH ARGV_WORKING_DIRECTORY BASE_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}" NORMALIZE)
  else()
    set(ARGV_WORKING_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}")
  endif()

  include_bare_module(
    ${specifier}
    target
    SOURCE_DIR source_dir
    WORKING_DIRECTORY "${ARGV_WORKING_DIRECTORY}"
  )

  if(ARGV_SHARED)
    target_link_libraries(
      ${receiver}
      PRIVATE
        ${target}_module
    )
  else()
    bare_module_target("${source_dir}" target NAME name VERSION version HASH hash)

    string(MAKE_C_IDENTIFIER ${target} id)

    target_compile_definitions(
      ${target}
      PRIVATE
        BARE_MODULE_FILENAME="${name}@${version}"
        BARE_MODULE_REGISTER_CONSTRUCTOR
        BARE_MODULE_CONSTRUCTOR_VERSION=${hash}

        NAPI_MODULE_FILENAME="${name}@${version}"
        NAPI_MODULE_REGISTER_CONSTRUCTOR
        NAPI_MODULE_CONSTRUCTOR_VERSION=${hash}

        NODE_GYP_MODULE_NAME=${id}
    )

    target_link_libraries(
      ${receiver}
      PRIVATE
        $<TARGET_OBJECTS:${target}>
      PRIVATE
        ${target}
    )
  endif()
endfunction()

function(link_bare_modules receiver)
  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "" "WORKING_DIRECTORY" ""
  )

  if(ARGV_WORKING_DIRECTORY)
    cmake_path(ABSOLUTE_PATH ARGV_WORKING_DIRECTORY BASE_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}" NORMALIZE)
  else()
    set(ARGV_WORKING_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}")
  endif()

  list_node_modules(
    packages
    WORKING_DIRECTORY "${ARGV_WORKING_DIRECTORY}"
  )

  foreach(base ${packages})
    cmake_path(APPEND base package.json OUTPUT_VARIABLE package_path)

    file(READ "${package_path}" package)

    string(JSON addon ERROR_VARIABLE error GET "${package}" "addon")

    if(error MATCHES "NOTFOUND")
      link_bare_module(
        ${receiver}
        ${base}
        WORKING_DIRECTORY "${ARGV_WORKING_DIRECTORY}"
      )
    endif()
  endforeach()
endfunction()
