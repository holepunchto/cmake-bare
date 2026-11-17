cmake_minimum_required(VERSION 4.0)

find_package(cmake-bare REQUIRED PATHS node_modules/cmake-bare)

project(bare_library_receiver C)

add_library(dep_static STATIC)

add_library(dep::static ALIAS dep_static)

set_target_properties(
  dep_static
  PROPERTIES
  POSITION_INDEPENDENT_CODE ON
)

target_sources(
  dep_static
  PRIVATE
    dep.c
)

add_bare_module(
  addon
  SOURCES
    binding.c
  LINK
    dep::<TYPE>
)

add_library(host_static STATIC)

add_library(host::static ALIAS host_static)

target_sources(
  host_static
  PRIVATE
    host.c
)

link_bare_module(host::<TYPE> a)
