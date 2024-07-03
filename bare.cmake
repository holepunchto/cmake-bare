include(npm)

set(BARE_SCRIPT_INTERPRETER "node" CACHE STRING "The script interpreter to use")

set(BARE_SCRIPT_INTERPRETER_ARGS "" CACHE STRING "Arguments to pass to the script interpreter")

set(bare_module_dir "${CMAKE_CURRENT_LIST_DIR}")

function(find_bare result)
  if(CMAKE_HOST_WIN32)
    find_program(
      bare_bin
      NAMES bare.cmd bare
      REQUIRED
    )
  else()
    find_program(
      bare_bin
      NAMES bare
      REQUIRED
    )
  endif()

  execute_process(
    COMMAND "${bare_bin}" -p "Bare.argv[0]"
    OUTPUT_VARIABLE bare
    OUTPUT_STRIP_TRAILING_WHITESPACE
    COMMAND_ERROR_IS_FATAL ANY
  )

  set(${result} "${bare}")

  return(PROPAGATE ${result})
endfunction()

function(find_bare_dev result)
  resolve_node_module(bare-dev resolved)

  if(NOT resolved MATCHES "NOTFOUND")
    cmake_path(GET resolved PARENT_PATH node_modules)

    cmake_path(APPEND node_modules ".bin" OUTPUT_VARIABLE bin)

    list(APPEND hints "${bin}")
  endif()

  if(CMAKE_HOST_WIN32)
    find_program(
      bare_dev
      NAMES bare-dev.cmd bare-dev
      HINTS ${hints}
      REQUIRED
    )
  else()
    find_program(
      bare_dev
      NAMES bare-dev
      HINTS ${hints}
      REQUIRED
    )
  endif()

  set(${result} "${bare_dev}")

  return(PROPAGATE ${result})
endfunction()

function(find_bare_script_interpreter result)
  if(CMAKE_HOST_WIN32)
    find_program(
      script_interpreter
      NAMES "${BARE_SCRIPT_INTERPRETER}.cmd" "${BARE_SCRIPT_INTERPRETER}"
      REQUIRED
    )
  else()
    find_program(
      script_interpreter
      NAMES "${BARE_SCRIPT_INTERPRETER}"
      REQUIRED
    )
  endif()

  if(BARE_SCRIPT_INTERPRETER_ARGS)
    separate_arguments(BARE_SCRIPT_INTERPRETER_ARGS)

    set(script_interpreter ${script_interpreter} ${BARE_SCRIPT_INTERPRETER_ARGS})
  endif()

  set(${result} "${script_interpreter}")

  return(PROPAGATE ${result})
endfunction()

function(bare_platform result)
  set(platform ${CMAKE_SYSTEM_NAME})

  if(NOT platform)
    set(platform ${CMAKE_HOST_SYSTEM_NAME})
  endif()

  string(TOLOWER ${platform} platform)

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
  else()
    set(arch ${CMAKE_SYSTEM_PROCESSOR})
  endif()

  if(NOT arch)
    set(arch ${CMAKE_HOST_SYSTEM_PROCESSOR})
  endif()

  string(TOLOWER ${arch} arch)

  if(arch MATCHES "arm64|aarch64")
    set(${result} "arm64")
  elseif(arch MATCHES "armv7-a")
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
  bare_module_target("." target NAME name)

  bare_include_directories(includes)

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
      ${includes}
  )

  set(${result} ${target})

  if(IOS OR ANDROID)
    return(PROPAGATE ${result})
  endif()

  if(TARGET bare_bin)
    add_executable(${target}_import_lib ALIAS bare_bin)
  else()
    find_bare(bare)

    add_executable(${target}_import_lib IMPORTED)

    set_target_properties(
      ${target}_import_lib
      PROPERTIES
      ENABLE_EXPORTS ON
      IMPORTED_LOCATION "${bare}"
    )

    if(MSVC)
      cmake_path(GET bare PARENT_PATH root)
      cmake_path(GET root PARENT_PATH root)

      cmake_path(APPEND root "lib" OUTPUT_VARIABLE lib)

      find_library(
        bare_lib
        NAMES bare
        HINTS "${lib}"
      )

      set_target_properties(
        ${target}_import_lib
        PROPERTIES
        IMPORTED_IMPLIB "${bare_lib}"
      )

      target_link_options(
        ${target}_import_lib
        INTERFACE
          /DELAYLOAD:bare.exe
      )
    endif()
  endif()

  add_library(${target}_module MODULE)

  set_target_properties(
    ${target}_module
    PROPERTIES
    OUTPUT_NAME ${name}
    PREFIX ""
    SUFFIX ".bare"

    # Automatically export all available symbols on Windows. Without this,
    # module authors would have to explicitly export public symbols.
    WINDOWS_EXPORT_ALL_SYMBOLS ON
  )

  if(MSVC)
    target_sources(
      ${target}_module
      PRIVATE
        "${bare_module_dir}/win32/delay-load.c"
    )
  endif()

  target_link_libraries(
    ${target}_module
    PUBLIC
      ${target}
    PRIVATE
      ${target}_import_lib
  )

  return(PROPAGATE ${result})
endfunction()

function(include_bare_module specifier result)
  cmake_parse_arguments(
    PARSE_ARGV 2 ARGV "" "WORKING_DIRECTORY" ""
  )

  if(ARGV_WORKING_DIRECTORY)
    cmake_path(ABSOLUTE_PATH ARGV_WORKING_DIRECTORY BASE_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}" NORMALIZE)
  else()
    set(ARGV_WORKING_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}")
  endif()

  resolve_node_module(
    ${specifier} source_dir
    WORKING_DIRECTORY "${ARGV_WORKING_DIRECTORY}"
  )

  bare_module_target("${source_dir}" target)

  file(READ "${source_dir}/package.json" package)

  string(JSON name GET "${package}" "name")

  string(JSON version GET "${package}" "version")

  cmake_path(RELATIVE_PATH source_dir BASE_DIRECTORY "${ARGV_WORKING_DIRECTORY}" OUTPUT_VARIABLE binary_dir)

  add_subdirectory("${source_dir}" "${binary_dir}" EXCLUDE_FROM_ALL)

  string(MAKE_C_IDENTIFIER ${name} id)

  string(
    RANDOM
    LENGTH 8
    ALPHABET "ybndrfg8ejkmcpqxot1uwisza345h769" # z-base-32
    constructor
  )

  target_compile_definitions(
    ${target}
    PRIVATE
      BARE_MODULE_FILENAME="${name}@${version}"
      BARE_MODULE_REGISTER_CONSTRUCTOR
      BARE_MODULE_CONSTRUCTOR_VERSION=${constructor}

      NAPI_MODULE_FILENAME="${name}@${version}"
      NAPI_MODULE_REGISTER_CONSTRUCTOR
      NAPI_MODULE_CONSTRUCTOR_VERSION=${constructor}

      NODE_GYP_MODULE_NAME=${id}
  )

  set(${result} ${target})

  return(PROPAGATE ${result})
endfunction()

function(link_bare_module receiver specifier)
  cmake_parse_arguments(
    PARSE_ARGV 2 ARGV "AMALGAMATE" "WORKING_DIRECTORY" "EXCLUDE;RUNTIME_LIBRARIES"
  )

  if(ARGV_WORKING_DIRECTORY)
    cmake_path(ABSOLUTE_PATH ARGV_WORKING_DIRECTORY BASE_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}" NORMALIZE)
  else()
    set(ARGV_WORKING_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}")
  endif()

  include_bare_module(
    ${specifier} target
    WORKING_DIRECTORY "${ARGV_WORKING_DIRECTORY}"
  )

  target_sources(
    ${receiver}
    PUBLIC
      $<TARGET_OBJECTS:${target}>
  )

  target_link_libraries(
    ${receiver}
    PUBLIC
      ${target}
  )

  if(NOT DEFINED ARGV_RUNTIME_LIBRARIES)
    list(APPEND ARGV_RUNTIME_LIBRARIES uv uv_a napi mem utf url base64 hex)
  endif()

  if(ARGV_AMALGAMATE)
    get_target_property(queue ${target} LINK_LIBRARIES)

    if(NOT "${queue}" MATCHES "NOTFOUND")
      list(LENGTH queue length)

      get_target_property(sources ${receiver} SOURCES)

      list(APPEND seen ${ARGV_EXCLUDE} ${ARGV_RUNTIME_LIBRARIES})

      while(length GREATER 0)
        list(POP_FRONT queue dependency)

        if(TARGET ${dependency} AND NOT ${dependency} IN_LIST seen)
          list(APPEND seen ${dependency})

          if(NOT $<TARGET_OBJECTS:${dependency}> IN_LIST sources)
            target_sources(
              ${receiver}
              PUBLIC
                $<TARGET_OBJECTS:${dependency}>
            )
          endif()

          get_target_property(dependencies ${dependency} LINK_LIBRARIES)

          if(NOT "${dependencies}" MATCHES "NOTFOUND")
            list(APPEND queue ${dependencies})
          endif()
        endif()

        list(LENGTH queue length)
      endwhile()
    endif()
  endif()
endfunction()

function(link_bare_modules receiver)
  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "DEVELOPMENT;AMALGAMATE" "WORKING_DIRECTORY" "EXCLUDE;RUNTIME_LIBRARIES"
  )

  if(ARGV_WORKING_DIRECTORY)
    cmake_path(ABSOLUTE_PATH ARGV_WORKING_DIRECTORY BASE_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}" NORMALIZE)
  else()
    set(ARGV_WORKING_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}")
  endif()

  if(ARGV_DEVELOPMENT)
    set(DEVELOPMENT DEVELOPMENT)
  endif()

  list_node_modules(
    packages ${DEVELOPMENT}
    WORKING_DIRECTORY "${ARGV_WORKING_DIRECTORY}"
  )

  if(ARGV_AMALGAMATE)
    list(APPEND args AMALGAMATE)

    if(DEFINED ARGV_EXCLUDE)
      list(APPEND args EXCLUDE ${ARGV_EXCLUDE})
    endif()

    if(DEFINED ARGV_RUNTIME_LIBRARIES)
      list(APPEND args RUNTIME_LIBRARIES ${ARGV_RUNTIME_LIBRARIES})
    endif()
  endif()

  foreach(base ${packages})
    cmake_path(APPEND base package.json OUTPUT_VARIABLE package_path)

    file(READ "${package_path}" package)

    string(JSON addon ERROR_VARIABLE error GET "${package}" "addon")

    if(error MATCHES "NOTFOUND")
      link_bare_module(${receiver} ${base} ${args})
    endif()
  endforeach()
endfunction()

function(bare_include_directories result)
  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "NAPI" "" ""
  )

  if(ARGV_NAPI)
    set(type napi)
  else()
    set(type bare)
  endif()

  find_bare_script_interpreter(script_interpreter)

  execute_process(
    COMMAND ${script_interpreter} "${bare_module_dir}/include-directories.js" ${type}
    OUTPUT_VARIABLE include_directories
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )

  list(APPEND ${result} "${include_directories}")

  return(PROPAGATE ${result})
endfunction()

function(add_bare_bundle)
  cmake_parse_arguments(
    PARSE_ARGV 0 ARGV "" "ENTRY;OUT;CONFIG;FORMAT;TARGET;NAME;WORKING_DIRECTORY" "DEPENDS"
  )

  if(ARGV_WORKING_DIRECTORY)
    cmake_path(ABSOLUTE_PATH ARGV_WORKING_DIRECTORY BASE_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}" NORMALIZE)
  else()
    set(ARGV_WORKING_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}")
  endif()

  list(APPEND args --cwd "${ARGV_WORKING_DIRECTORY}")

  if(ARGV_CONFIG)
    cmake_path(ABSOLUTE_PATH ARGV_CONFIG BASE_DIRECTORY "${ARGV_WORKING_DIRECTORY}" NORMALIZE)

    list(APPEND args --config "${ARGV_CONFIG}")

    list(APPEND ARGV_DEPENDS "${ARGV_CONFIG}")
  endif()

  list(APPEND args_bundle ${args})

  list(APPEND args_dependencies ${args})

  if(ARGV_FORMAT)
    string(TOLOWER ${ARGV_FORMAT} ARGV_FORMAT)

    list(APPEND args_bundle --format ${ARGV_FORMAT})
  endif()

  if(ARGV_TARGET)
    string(TOLOWER ${ARGV_TARGET} ARGV_TARGET)

    list(APPEND args_bundle --target ${ARGV_TARGET})
  endif()

  if(ARGV_NAME)
    list(APPEND args_bundle --name ${ARGV_NAME})
  endif()

  cmake_path(ABSOLUTE_PATH ARGV_OUT BASE_DIRECTORY "${ARGV_WORKING_DIRECTORY}" NORMALIZE)

  list(APPEND args_bundle --out "${ARGV_OUT}")

  list(APPEND args_dependencies --out "${ARGV_OUT}.d")

  cmake_path(ABSOLUTE_PATH ARGV_ENTRY BASE_DIRECTORY "${ARGV_WORKING_DIRECTORY}" NORMALIZE)

  list(APPEND ARGV_DEPENDS "${ARGV_ENTRY}")

  list(APPEND args_bundle "${ARGV_ENTRY}")

  list(APPEND args_dependencies "${ARGV_ENTRY}")

  find_bare_dev(bare_dev)

  list(REMOVE_DUPLICATES ARGV_DEPENDS)

  add_custom_command(
    COMMAND "${bare_dev}" dependencies ${args_dependencies}
    WORKING_DIRECTORY "${ARGV_WORKING_DIRECTORY}"
    OUTPUT "${ARGV_OUT}.d"
    DEPENDS ${ARGV_DEPENDS}
    VERBATIM
  )

  add_custom_command(
    COMMAND "${bare_dev}" bundle ${args_bundle}
    WORKING_DIRECTORY "${ARGV_WORKING_DIRECTORY}"
    OUTPUT "${ARGV_OUT}"
    DEPENDS "${ARGV_OUT}.d"
    DEPFILE "${ARGV_OUT}.d"
    VERBATIM
  )

  if(DEFINED ARGV_UNPARSED_ARGUMENTS)
    list(POP_FRONT ARGV_UNPARSED_ARGUMENTS target)

    add_custom_target(
      ${target}
      ALL
      DEPENDS "${ARGV_OUT}"
    )
  endif()
endfunction()

function(import_bare_dependencies)
  bare_include_directories(includes)

  if(NOT TARGET uv)
    add_library(uv INTERFACE IMPORTED)

    target_include_directories(
      uv
      INTERFACE
        ${includes}
    )
  endif()

  if(NOT TARGET js)
    add_library(js INTERFACE IMPORTED)

    target_include_directories(
      js
      INTERFACE
        ${includes}
    )
  endif()

  if(NOT TARGET utf)
    add_library(utf INTERFACE IMPORTED)

    target_include_directories(
      utf
      INTERFACE
        ${includes}
    )
  endif()
endfunction()

function(mirror_drive)
  cmake_parse_arguments(
    PARSE_ARGV 0 ARGV "" "SOURCE;DESTINATION;PREFIX;CHECKOUT;WORKING_DIRECTORY" ""
  )

  if(ARGV_WORKING_DIRECTORY)
    cmake_path(ABSOLUTE_PATH ARGV_WORKING_DIRECTORY BASE_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}" NORMALIZE)
  else()
    set(ARGV_WORKING_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}")
  endif()

  if(NOT ARGV_PREFIX)
    set(ARGV_PREFIX /)
  endif()

  if(NOT ARGV_CHECKOUT)
    set(ARGV_CHECKOUT 0)
  endif()

  list(APPEND args
    "${ARGV_WORKING_DIRECTORY}"
    "${ARGV_PREFIX}"
    "${ARGV_CHECKOUT}"
    "${ARGV_SOURCE}"
    "${ARGV_DESTINATION}"
  )

  find_bare_script_interpreter(script_interpreter)

  message(STATUS "Mirroring drive ${ARGV_SOURCE} into ${ARGV_DESTINATION}")

  execute_process(
    COMMAND ${script_interpreter} "${bare_module_dir}/mirror.js" ${args}
    OUTPUT_VARIABLE output
    OUTPUT_STRIP_TRAILING_WHITESPACE
    WORKING_DIRECTORY "${ARGV_WORKING_DIRECTORY}"
  )

  message(CONFIGURE_LOG
    "Mirrored drive ${ARGV_SOURCE} into ${ARGV_DESTINATION}\n"
    "${output}"
  )
endfunction()

if(NOT CMAKE_PROJECT_NAME STREQUAL "bare")
  import_bare_dependencies()
endif()
