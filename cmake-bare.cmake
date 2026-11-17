include_guard()

find_package(cmake-npm REQUIRED PATHS node_modules/cmake-npm)

set(bare_module_dir "${CMAKE_CURRENT_LIST_DIR}")

function(download_bare result)
  set(one_value_keywords
    DESTINATION
    VERSION
    IMPORT_FILE
  )

  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "" "${one_value_keywords}" ""
  )

  if(NOT ARGV_DESTINATION)
    set(ARGV_DESTINATION "${CMAKE_BINARY_DIR}/_bare")
  endif()

  if(NOT ARGV_VERSION)
    set(ARGV_VERSION "latest")
  endif()

  bare_target(target)

  set(key "bare_runtime:${ARGV_DESTINATION}:${ARGV_VERSION}")

  get_property(output GLOBAL PROPERTY "${key}")

  if(NOT output)
    if(NOT EXISTS "${ARGV_DESTINATION}/package.json")
      file(WRITE "${ARGV_DESTINATION}/package.json" "{}")
    endif()

    install_node_module(
      bare-runtime-${target}
      VERSION ${ARGV_VERSION}
      SAVE
      FORCE
      WORKING_DIRECTORY "${ARGV_DESTINATION}"
    )

    resolve_node_module(
      bare-runtime-${target}
      output
      WORKING_DIRECTORY "${ARGV_DESTINATION}"
    )

    set_property(GLOBAL PROPERTY "${key}" "${output}")
  endif()

  set(import_file ${ARGV_IMPORT_FILE})

  if(target MATCHES "win32")
    cmake_path(APPEND output bin bare.exe OUTPUT_VARIABLE ${result})

    if(import_file)
      cmake_path(APPEND output lib bare.lib OUTPUT_VARIABLE ${import_file})
    endif()
  else()
    cmake_path(APPEND output bin bare OUTPUT_VARIABLE ${result})

    if(import_file)
      if(target MATCHES "darwin|ios|watchos")
        cmake_path(APPEND output lib libbare.tbd OUTPUT_VARIABLE ${import_file})
      else()
        set(${import_file} ${import_file}-NOTFOUND)
      endif()
    endif()
  endif()

  return(PROPAGATE ${result} ${import_file})
endfunction()

function(download_bare_headers result)
  set(one_value_keywords
    DESTINATION
    VERSION
  )

  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "" "${one_value_keywords}" ""
  )

  if(NOT ARGV_DESTINATION)
    set(ARGV_DESTINATION "${CMAKE_BINARY_DIR}/_bare")
  endif()

  if(NOT ARGV_VERSION)
    set(ARGV_VERSION "latest")
  endif()

  set(key "bare_headers:${ARGV_DESTINATION}:${ARGV_VERSION}")

  get_property(output GLOBAL PROPERTY "${key}")

  if(NOT output)
    if(NOT EXISTS "${ARGV_DESTINATION}/package.json")
      file(WRITE "${ARGV_DESTINATION}/package.json" "{}")
    endif()

    install_node_module(
      bare-headers
      VERSION ${ARGV_VERSION}
      SAVE
      FORCE
      WORKING_DIRECTORY "${ARGV_DESTINATION}"
    )

    resolve_node_module(
      bare-headers
      output
      WORKING_DIRECTORY "${ARGV_DESTINATION}"
    )

    set_property(GLOBAL PROPERTY "${key}" "${output}")
  endif()

  cmake_path(APPEND output include OUTPUT_VARIABLE ${result})

  return(PROPAGATE ${result})
endfunction()

# A build that provides its own Bare defines a `bare::headers` target so that
# addons are compiled against the headers of that Bare rather than a download.
function(link_bare_headers target)
  if(TARGET bare::headers)
    target_link_libraries(
      ${target}
      PRIVATE
        bare::headers
    )
  else()
    download_bare_headers(include_dir)

    target_include_directories(
      ${target}
      PRIVATE
        "${include_dir}"
    )
  endif()
endfunction()

function(bare_platform result)
  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "HOST" "" ""
  )

  if(ARGV_HOST)
    set(platform ${CMAKE_HOST_SYSTEM_NAME})
  else()
    set(platform ${CMAKE_SYSTEM_NAME})

    if(NOT platform)
      set(platform ${CMAKE_HOST_SYSTEM_NAME})
    endif()
  endif()

  string(TOLOWER "${platform}" platform)

  if(platform MATCHES "darwin|ios|watchos|linux|android|wasi|freertos")
    set(${result} ${platform})
  elseif(platform MATCHES "windows")
    set(${result} "win32")
  else()
    set(${result} "unknown")
  endif()

  return(PROPAGATE ${result})
endfunction()

function(bare_arch result)
  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "HOST" "" ""
  )

  if(ARGV_HOST)
    set(arch ${CMAKE_HOST_SYSTEM_PROCESSOR})
  else()
    if(APPLE AND CMAKE_OSX_ARCHITECTURES)
      set(arch ${CMAKE_OSX_ARCHITECTURES})
    elseif(MSVC AND CMAKE_GENERATOR_PLATFORM)
      set(arch ${CMAKE_GENERATOR_PLATFORM})
    elseif(ANDROID AND CMAKE_ANDROID_ARCH_ABI)
      set(arch ${CMAKE_ANDROID_ARCH_ABI})
    else()
      set(arch ${CMAKE_SYSTEM_PROCESSOR})
    endif()

    if(NOT arch AND NOT CMAKE_CROSSCOMPILING)
      set(arch ${CMAKE_HOST_SYSTEM_PROCESSOR})
    endif()
  endif()

  string(TOLOWER "${arch}" arch)

  if(arch MATCHES "arm64_32")
    set(${result} "arm64-32")
  elseif(arch MATCHES "arm64|aarch64")
    set(${result} "arm64")
  elseif(arch MATCHES "armv8m")
    set(${result} "armv8m")
  elseif(arch MATCHES "armv7-a|armeabi-v7a")
    set(${result} "arm")
  elseif(arch MATCHES "x64|x86_64|amd64")
    set(${result} "x64")
  elseif(arch MATCHES "x86|i386|i486|i586|i686")
    set(${result} "ia32")
  elseif(arch MATCHES "riscv64")
    set(${result} "riscv64")
  elseif(arch MATCHES "riscv32")
    set(${result} "riscv32")
  elseif(arch MATCHES "mipsel")
    set(${result} "mipsel")
  elseif(arch MATCHES "mips(eb)?")
    set(${result} "mips")
  elseif(arch MATCHES "wasm32")
    set(${result} "wasm32")
  else()
    set(${result} "unknown")
  endif()

  return(PROPAGATE ${result})
endfunction()

function(bare_simulator result)
  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "HOST" "" ""
  )

  if(ARGV_HOST)
    set(sysroot "")
  else()
    set(sysroot ${CMAKE_OSX_SYSROOT})
  endif()

  if(sysroot MATCHES "iPhoneSimulator|WatchSimulator")
    set(${result} YES)
  else()
    set(${result} NO)
  endif()

  return(PROPAGATE ${result})
endfunction()

function(bare_environment result)
  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "HOST" "" ""
  )

  set(environment "")

  if(NOT ARGV_HOST)
    if(APPLE AND CMAKE_OSX_SYSROOT MATCHES "iPhoneSimulator|WatchSimulator")
      set(environment "simulator")
    elseif(LINUX AND CMAKE_C_COMPILER_TARGET MATCHES "-linux-(musl(sf)?)")
      set(environment "${CMAKE_MATCH_1}")
    endif()
  endif()

  set(${result} ${environment})

  return(PROPAGATE ${result})
endfunction()

function(bare_target result)
  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "HOST" "" ""
  )

  if(ARGV_HOST)
    set(host HOST)
  else()
    set(host)
  endif()

  bare_platform(platform ${host})
  bare_arch(arch ${host})
  bare_environment(environment ${host})

  set(target ${platform}-${arch})

  if(environment)
    set(target ${target}-${environment})
  endif()

  set(${result} ${target})

  return(PROPAGATE ${result})
endfunction()

function(bare_module_target directory result)
  set(one_value_keywords
    NAME
    VERSION
    HASH
  )

  cmake_parse_arguments(
    PARSE_ARGV 2 ARGV "" "${one_value_keywords}" ""
  )

  set(package_path package.json)

  cmake_path(ABSOLUTE_PATH directory NORMALIZE)

  cmake_path(ABSOLUTE_PATH package_path BASE_DIRECTORY "${directory}" NORMALIZE)

  file(READ "${package_path}" package)

  string(JSON name GET "${package}" "name")

  if(name MATCHES "__")
    message(FATAL_ERROR "Package name '${name}' is invalid")
  endif()

  string(REGEX REPLACE "/" "__" name ${name})
  string(REGEX REPLACE "^@" "" name ${name})

  string(JSON version GET "${package}" "version")

  string(SHA256 hash "bare ${package_path}")

  string(SUBSTRING "${hash}" 0 8 hash)

  set(${result} "${name}-${version}-${hash}")

  if(ARGV_NAME)
    set(${ARGV_NAME} ${name} PARENT_SCOPE)
  endif()

  if(ARGV_VERSION)
    set(${ARGV_VERSION} ${version} PARENT_SCOPE)
  endif()

  if(ARGV_HASH)
    set(${ARGV_HASH} ${hash} PARENT_SCOPE)
  endif()

  return(PROPAGATE ${result})
endfunction()

function(add_bare_module result)
  set(single_value_keywords
    NAME
    EXPORTS_FROM
  )

  set(multi_value_keywords
    SOURCES
    LINK
    EXPORTS
    INSTALL
  )

  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "" "${single_value_keywords}" "${multi_value_keywords}"
  )

  set(symbols ${ARGV_EXPORTS})

  if(ARGV_EXPORTS_FROM)
    read_bare_module_symbols("${ARGV_EXPORTS_FROM}" file_symbols)

    list(APPEND symbols ${file_symbols})
  endif()

  # A lone EXPORTS exports every symbol, while a list of symbols exports only
  # those. Either way, other addons can link against the addon.
  if(symbols)
    set(exports ON)
    set(exports_all OFF)
  elseif("EXPORTS" IN_LIST ARGV_KEYWORDS_MISSING_VALUES)
    set(exports ON)
    set(exports_all ON)
  else()
    set(exports OFF)
    set(exports_all OFF)
  endif()

  bare_module_target("." target NAME name VERSION version)

  if(ARGV_NAME)
    set(name "${ARGV_NAME}")
  endif()

  if(ARGV_INSTALL STREQUAL "OFF")
    set(install OFF)
    set(ARGV_INSTALL)
  else()
    set(install ON)
  endif()

  string(REGEX MATCH "^[0-9]+" major "${version}")

  add_library(${target} OBJECT)

  set_target_properties(
    ${target}
    PROPERTIES
    C_STANDARD 11
    CXX_STANDARD 20
    POSITION_INDEPENDENT_CODE ON
  )

  target_compile_definitions(
    ${target}
    PRIVATE
      BARE_MODULE_NAME="${name}@${version}"
  )

  link_bare_headers(${target})

  target_sources(
    ${target}
    PRIVATE
      ${ARGV_SOURCES}
  )

  # Addons link the static variant of libraries, so that they are self-contained
  # both as shared libraries and when linked into another target.
  list(TRANSFORM ARGV_LINK REPLACE "::<TYPE>$" "::static")

  target_link_libraries(
    ${target}
    PRIVATE
      ${ARGV_LINK}
  )

  set(${result} ${target})

  bare_target(host)

  if(host MATCHES "^wasi-")
    add_bare_wasm_module(${target} ${name} ${major} ${host} ${install} ${ARGV_INSTALL})

    return(PROPAGATE ${result})
  endif()

  # FreeRTOS has no dynamic loader, so addons are only ever linked statically
  # from the object library.
  if(host MATCHES "^freertos-")
    set_target_properties(
      ${target}
      PROPERTIES
      POSITION_INDEPENDENT_CODE OFF
    )

    return(PROPAGATE ${result})
  endif()

  add_library(${target}_module SHARED)

  if(APPLE)
    set(${target}_rpath "@loader_path/${name}@${version};@loader_path/${name}")
  elseif(LINUX)
    set(${target}_rpath "$ORIGIN/${name}@${version};$ORIGIN/${name}")
  else()
    set(${target}_rpath "")
  endif()

  set_target_properties(
    ${target}_module
    PROPERTIES

    ENABLE_EXPORTS ${exports}

    # Set the logical name of the addon which is tied to its major version. This
    # is NOT the name of the addon as it will be installed, but is the name that
    # the linker will use to refer to the corresponding binary.
    OUTPUT_NAME ${name}@${major}
    PREFIX ""
    SUFFIX ".bare"
    IMPORT_PREFIX ""
    IMPORT_SUFFIX ".bare.exports"

    # Set the runpath of the addon to support loading of runtime dependencies
    # located in a named directory next to the addon prebuilds.
    INSTALL_RPATH "${${target}_rpath}"
    BUILD_WITH_INSTALL_RPATH ON

    # Remove the directory portion of the install name for Mach-O binaries. This
    # ensures that the addon is identified by the linker only by its logical name.
    INSTALL_NAME_DIR ""
    BUILD_WITH_INSTALL_NAME_DIR ON

    # Set the Mach-O compatibility versions for macOS and iOS. This is mostly
    # for debugging purposes as the addon version is already encoded in its
    # logical name.
    MACHO_CURRENT_VERSION ${version}
    MACHO_COMPATIBILITY_VERSION ${major}

    # Automatically export all available symbols on Windows. Without this,
    # module authors would have to explicitly export public symbols.
    WINDOWS_EXPORT_ALL_SYMBOLS ON
  )

  target_link_libraries(
    ${target}_module
    PRIVATE
      ${target}
  )

  bare_target(host)

  if(host MATCHES "win32")
    if(NOT TARGET bare::shared)
      download_bare(bare_bin IMPORT_FILE bare_lib)

      add_library(bare::shared SHARED IMPORTED GLOBAL)

      set_target_properties(
        bare::shared
        PROPERTIES
        IMPORTED_LOCATION "${bare_bin}"
        IMPORTED_IMPLIB "${bare_lib}"
      )
    endif()

    target_link_libraries(
      ${target}_module
      PRIVATE
        bare::shared
    )

    if(NOT TARGET bare_delay_load)
      add_library(bare_delay_load STATIC)

      target_sources(
        bare_delay_load
        PRIVATE
          "${bare_module_dir}/win32/delay-load.c"
      )

      link_bare_headers(bare_delay_load)

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
        /DELAYLOAD:${name}@${major}.bare
    )
  else()
    target_link_options(
      ${target}_module
      PRIVATE
        -Wl,-undefined,dynamic_lookup
    )
  endif()

  if(NOT exports_all)
    restrict_bare_module_exports(${target} ${symbols})
  endif()

  if(NOT install)
    return(PROPAGATE ${result})
  endif()

  install(
    FILES $<TARGET_FILE:${target}_module>
    DESTINATION ${host}
    RENAME ${name}.bare
  )

  if(exports)
    install(
      FILES $<TARGET_IMPORT_FILE:${target}_module>
      DESTINATION ${host}
      RENAME ${name}.bare.exports
    )
  endif()

  install_bare_module_files(${host} ${name} ${ARGV_INSTALL})

  return(PROPAGATE ${result})
endfunction()

function(install_bare_module_files host name)
  while(TRUE)
    list(LENGTH ARGN len)

    if(len EQUAL 0)
      break()
    endif()

    if(len EQUAL 1)
      message(FATAL_ERROR "INSTALL ${ARGN} requires a value")
    endif()

    list(POP_FRONT ARGN type value)

    if(type STREQUAL "TARGET")
      get_target_property(target_type ${value} TYPE)

      if(target_type MATCHES "SHARED_LIBRARY" AND NOT WIN32)
        install(
          FILES $<TARGET_FILE:${value}>
          DESTINATION ${host}/${name}
          RENAME $<TARGET_SONAME_FILE_NAME:${value}>
        )
      else()
        install(
          FILES $<TARGET_FILE:${value}>
          DESTINATION ${host}/${name}
        )
      endif()
    elseif(type STREQUAL "FILE")
      install(
        FILES ${value}
        DESTINATION ${host}/${name}
      )
    elseif(type STREQUAL "DIR")
      install(
        DIRECTORY ${value}
        DESTINATION ${host}/${name}
      )
    elseif(type STREQUAL "PRIVACY_MANIFEST")
      if(host MATCHES "^(darwin|ios|watchos)-")
        install(
          FILES ${value}
          DESTINATION ${host}/${name}
          RENAME PrivacyInfo.xcprivacy
        )
      endif()
    else()
      message(FATAL_ERROR "Unknown INSTALL type '${type}'")
    endif()
  endwhile()
endfunction()

# Read the symbols in a JSON array of strings, or in a file with one symbol per
# line.
function(read_bare_module_symbols path result)
  cmake_path(ABSOLUTE_PATH path BASE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" NORMALIZE)

  set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${path}")

  set(${result})

  if(NOT path MATCHES "\\.json$")
    file(STRINGS "${path}" ${result})

    return(PROPAGATE ${result})
  endif()

  file(READ "${path}" json)

  string(JSON type TYPE "${json}")

  if(NOT type STREQUAL "ARRAY")
    message(FATAL_ERROR "Exports file '${path}' must contain a JSON array")
  endif()

  string(JSON length LENGTH "${json}")

  if(length GREATER 0)
    math(EXPR last "${length} - 1")

    foreach(i RANGE ${last})
      string(JSON symbol GET "${json}" ${i})

      list(APPEND ${result} ${symbol})
    endforeach()
  endif()

  return(PROPAGATE ${result})
endfunction()

# Export only the given symbols from the shared library of the addon `target`,
# along with the symbols that Bare looks up when loading the addon.
#
# Hiding symbols also matters for correctness on ELF platforms. There, every
# exported symbol is subject to interposition from Bare's global scope, so an
# addon that vendors symbols Bare also provides would otherwise bind to Bare's
# copies instead of its own.
function(restrict_bare_module_exports target)
  set(symbols ${ARGN})

  set(base "${CMAKE_CURRENT_BINARY_DIR}/${target}")

  if(WIN32)
    # The Bare headers declare the loader symbols with `__declspec(dllexport)`,
    # so only the given symbols need listing.
    set_target_properties(
      ${target}_module
      PROPERTIES
      WINDOWS_EXPORT_ALL_SYMBOLS OFF
    )

    if(NOT symbols)
      return()
    endif()

    set(exports_file "${base}.def")

    list(TRANSFORM symbols PREPEND "  ")
    list(JOIN symbols "\n" symbols)

    file(CONFIGURE OUTPUT "${exports_file}" CONTENT "EXPORTS\n${symbols}\n" @ONLY)

    target_link_options(
      ${target}_module
      PRIVATE
        "/DEF:${exports_file}"
    )
  else()
    list(APPEND symbols
      bare_get_module_name_v*
      bare_register_module_v*
      napi_register_module_v*
    )

    if(APPLE)
      set(exports_file "${base}.exp")

      list(TRANSFORM symbols PREPEND "_")
      list(JOIN symbols "\n" symbols)

      file(CONFIGURE OUTPUT "${exports_file}" CONTENT "${symbols}\n" @ONLY)

      target_link_options(
        ${target}_module
        PRIVATE
          "-Wl,-exported_symbols_list,${exports_file}"
      )
    else()
      set(exports_file "${base}.map")

      list(TRANSFORM symbols PREPEND "    ")
      list(JOIN symbols ";\n" symbols)

      file(CONFIGURE OUTPUT "${exports_file}" CONTENT "{\n  global:\n${symbols};\n\n  local:\n    *;\n};\n" @ONLY)

      target_link_options(
        ${target}_module
        PRIVATE
          "-Wl,--version-script=${exports_file}"
      )
    endif()
  endif()

  set_property(
    TARGET ${target}_module
    APPEND
    PROPERTY LINK_DEPENDS "${exports_file}"
  )
endfunction()

# A WebAssembly addon is a reactor module rather than a shared library.
function(add_bare_wasm_module target name major host install)
  if("TARGET" IN_LIST ARGN)
    message(FATAL_ERROR "WebAssembly addons cannot install runtime dependencies")
  endif()

  set_target_properties(
    ${target}
    PROPERTIES
    POSITION_INDEPENDENT_CODE OFF
  )

  add_executable(${target}_module)

  set_target_properties(
    ${target}_module
    PROPERTIES
    OUTPUT_NAME ${name}@${major}
    SUFFIX ".wasm"
  )

  target_link_libraries(
    ${target}_module
    PRIVATE
      ${target}
  )

  target_link_options(
    ${target}_module
    PRIVATE
      -mexec-model=reactor
      -Wl,--allow-undefined
      -Wl,--export=bare_register_module_v0
      -Wl,--export-if-defined=bare_get_module_name_v0
      -Wl,--export=malloc
      -Wl,--export=free
      -Wl,--export-table
  )

  if(install)
    install(
      FILES $<TARGET_FILE:${target}_module>
      DESTINATION ${host}
      RENAME ${name}.wasm
    )

    install_bare_module_files(${host} ${name} ${ARGN})
  endif()
endfunction()

function(include_bare_module specifier result)
  set(option_keywords
    PREBUILD
  )

  set(one_value_keywords
    SOURCE_DIR
    BINARY_DIR
    WORKING_DIRECTORY
  )

  cmake_parse_arguments(
    PARSE_ARGV 2 ARGV "${option_keywords}" "${one_value_keywords}" ""
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

  bare_module_target("${source_dir}" target NAME name VERSION version)

  string(REGEX MATCH "^[0-9]+" major "${version}")

  set(${result} ${target})

  cmake_path(RELATIVE_PATH source_dir BASE_DIRECTORY "${ARGV_WORKING_DIRECTORY}" OUTPUT_VARIABLE binary_dir)

  if(ARGV_SOURCE_DIR)
    set(${ARGV_SOURCE_DIR} "${source_dir}" PARENT_SCOPE)
  endif()

  if(ARGV_BINARY_DIR)
    set(${ARGV_BINARY_DIR} "${binary_dir}" PARENT_SCOPE)
  endif()

  if(ARGV_PREBUILD)
    bare_target(host)

    cmake_path(APPEND source_dir "prebuilds" "${host}" "${name}.bare" OUTPUT_VARIABLE prebuild)

    add_library(${target}_module SHARED IMPORTED)

    set_target_properties(
      ${target}_module
      PROPERTIES
      IMPORTED_LOCATION "${prebuild}"
      IMPORTED_IMPLIB "${prebuild}.exports"
    )

    if(host MATCHES "win32")
      target_link_options(
        ${target}_module
        INTERFACE
          /DELAYLOAD:${name}@${major}.bare
      )
    endif()
  elseif(NOT TARGET ${target})
    add_subdirectory("${source_dir}" "${binary_dir}" EXCLUDE_FROM_ALL)
  endif()

  return(PROPAGATE ${result})
endfunction()

function(link_bare_module receiver specifier)
  set(option_keywords
    SHARED
  )

  set(one_value_keywords
    WORKING_DIRECTORY
  )

  cmake_parse_arguments(
    PARSE_ARGV 2 ARGV "${option_keywords}" "${one_value_keywords}" ""
  )

  if(ARGV_WORKING_DIRECTORY)
    cmake_path(ABSOLUTE_PATH ARGV_WORKING_DIRECTORY BASE_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}" NORMALIZE)
  else()
    set(ARGV_WORKING_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}")
  endif()

  if(ARGV_SHARED)
    set(PREBUILD PREBUILD)
  else()
    set(PREBUILD)
  endif()

  resolve_bare_module_receivers(${receiver} receivers)

  include_bare_module(
    ${specifier}
    target
    ${PREBUILD}
    SOURCE_DIR source_dir
    WORKING_DIRECTORY "${ARGV_WORKING_DIRECTORY}"
  )

  if(ARGV_SHARED)
    foreach(receiver IN LISTS receivers)
      target_link_libraries(
        ${receiver}
        PRIVATE
          ${target}_module
      )
    endforeach()
  else()
    bare_module_target("${source_dir}" target NAME name VERSION version HASH hash)

    target_compile_definitions(
      ${target}
      PRIVATE
        BARE_MODULE_NAME="${name}@${version}"
        BARE_MODULE_REGISTER_CONSTRUCTOR
        BARE_MODULE_CONSTRUCTOR_VERSION=${hash}
    )

    foreach(receiver IN LISTS receivers)
      get_target_property(type ${receiver} TYPE)

      # A static library passes the objects it links on to its consumers on top
      # of archiving them, which would link the addon twice. Linking the object
      # library directly instead archives its objects without passing them on.
      if(type STREQUAL "STATIC_LIBRARY")
        target_link_libraries(
          ${receiver}
          PRIVATE
            ${target}
        )
      else()
        target_link_libraries(
          ${receiver}
          PRIVATE
            $<TARGET_OBJECTS:${target}>
          PRIVATE
            ${target}
        )
      endif()
    endforeach()
  endif()
endfunction()

# Resolve the targets that `<receiver>` names, following aliases, which can't be
# linked to. A receiver of the form `<name>::<TYPE>` names each of the
# `<name>::static` and `<name>::shared` libraries that exist, as created by
# `add_library_targets()` from `cmake-prelude`.
function(resolve_bare_module_receivers receiver result)
  if(receiver MATCHES "^(.+)::<TYPE>$")
    set(candidates)

    foreach(type IN ITEMS static shared)
      if(TARGET ${CMAKE_MATCH_1}::${type})
        list(APPEND candidates ${CMAKE_MATCH_1}::${type})
      endif()
    endforeach()

    if(NOT candidates)
      message(FATAL_ERROR "${receiver} names no libraries")
    endif()
  else()
    set(candidates ${receiver})
  endif()

  set(${result})

  foreach(candidate IN LISTS candidates)
    get_target_property(aliased ${candidate} ALIASED_TARGET)

    if(aliased)
      list(APPEND ${result} ${aliased})
    else()
      list(APPEND ${result} ${candidate})
    endif()
  endforeach()

  return(PROPAGATE ${result})
endfunction()

function(link_bare_modules receiver)
  set(option_keywords
    SHARED
  )

  set(one_value_keywords
    FROM
    EXCLUDE_FROM
    WORKING_DIRECTORY
  )

  set(multi_value_keywords
    EXCLUDE
  )

  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "${option_keywords}" "${one_value_keywords}" "${multi_value_keywords}"
  )

  if(ARGV_EXCLUDE_FROM)
    read_bare_module_list("${ARGV_EXCLUDE_FROM}" excluded)

    list(APPEND ARGV_EXCLUDE ${excluded})
  endif()

  if(ARGV_WORKING_DIRECTORY)
    cmake_path(ABSOLUTE_PATH ARGV_WORKING_DIRECTORY BASE_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}" NORMALIZE)
  else()
    set(ARGV_WORKING_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}")
  endif()

  if(ARGV_SHARED)
    set(SHARED SHARED)
  else()
    set(SHARED)
  endif()

  if(ARGV_FROM)
    read_bare_module_list("${ARGV_FROM}" names)

    foreach(name ${names})
      if("${name}" IN_LIST ARGV_EXCLUDE)
        continue()
      endif()

      link_bare_module(
        ${receiver}
        ${name}
        ${SHARED}
        WORKING_DIRECTORY "${ARGV_WORKING_DIRECTORY}"
      )
    endforeach()

    return()
  endif()

  list_node_modules(
    packages
    WORKING_DIRECTORY "${ARGV_WORKING_DIRECTORY}"
  )

  foreach(base ${packages})
    cmake_path(APPEND base package.json OUTPUT_VARIABLE package_path)

    file(READ "${package_path}" package)

    string(JSON name ERROR_VARIABLE error GET "${package}" "name")

    if("${name}" IN_LIST ARGV_EXCLUDE)
      continue()
    endif()

    string(JSON addon ERROR_VARIABLE error GET "${package}" "addon")

    if(addon)
      link_bare_module(
        ${receiver}
        ${base}
        ${SHARED}
        WORKING_DIRECTORY "${ARGV_WORKING_DIRECTORY}"
      )
    endif()
  endforeach()
endfunction()

# Read a JSON list of module specifiers, such as the builtins list of Bare, and
# write the names of the native addons that it selects for the target host to
# the `<result>` variable. Entries may be conditional, using the same syntax as
# the "exports" and "imports" fields of `package.json`, and only those that are
# matched through the "addon" condition are native addons.
function(read_bare_module_list path result)
  cmake_path(ABSOLUTE_PATH path BASE_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}" NORMALIZE)

  file(READ "${path}" json)

  set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${path}")

  bare_target(host)

  string(REPLACE "-" ";" conditions "${host}")

  list(APPEND conditions addon)

  string(JSON type TYPE "${json}")

  if(NOT type STREQUAL "ARRAY")
    message(FATAL_ERROR "Module list '${path}' must contain a JSON array")
  endif()

  bare_module_list_targets("${json}" "${conditions}" OFF targets)

  set(${result})

  foreach(target ${targets})
    string(REGEX REPLACE "^(@?[^@]+)@.*$" "\\1" name "${target}")

    list(APPEND ${result} ${name})
  endforeach()

  list(REMOVE_DUPLICATES ${result})

  return(PROPAGATE ${result})
endfunction()

function(bare_module_list_targets json conditions addon result)
  set(found)

  string(JSON type TYPE "${json}")

  string(JSON length LENGTH "${json}")

  if(length GREATER 0)
    math(EXPR last "${length} - 1")

    foreach(i RANGE ${last})
      if(type STREQUAL "OBJECT")
        string(JSON key MEMBER "${json}" ${i})

        if(NOT key STREQUAL "default" AND NOT key IN_LIST conditions)
          continue()
        endif()

        if(key STREQUAL "addon")
          set(addon ON)
        endif()
      else()
        set(key ${i})
      endif()

      string(JSON value_type TYPE "${json}" ${key})
      string(JSON value GET "${json}" ${key})

      if(value_type STREQUAL "STRING")
        if(addon)
          list(APPEND found ${value})
        endif()
      elseif(value_type STREQUAL "ARRAY" OR value_type STREQUAL "OBJECT")
        bare_module_list_targets("${value}" "${conditions}" ${addon} nested)

        list(APPEND found ${nested})
      endif()

      # Only the first matching condition of an object applies.
      if(type STREQUAL "OBJECT")
        break()
      endif()
    endforeach()
  endif()

  set(${result} ${found})

  return(PROPAGATE ${result})
endfunction()
