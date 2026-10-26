cmake_minimum_required(VERSION 3.25)

find_package(cmake-bare REQUIRED PATHS node_modules/cmake-bare)

project(bare_addon C)

download_bare_headers(include_dir)

add_library(bare_headers INTERFACE)

add_library(bare::headers ALIAS bare_headers)

target_include_directories(
  bare_headers
  INTERFACE
    "${include_dir}"
)

add_bare_module(addon)

target_sources(
  ${addon}
  PRIVATE
    binding.c
)
