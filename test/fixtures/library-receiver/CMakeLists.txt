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

add_library(other_static STATIC)

add_library(other::static ALIAS other_static)

target_sources(
  other_static
  PRIVATE
    host.c
)

link_bare_modules(other::<TYPE> FROM modules.json EXCLUDE_FROM host::<TYPE>)

get_target_property(modules other_static BARE_MODULES)

if(modules)
  message(FATAL_ERROR "Linked ${modules} despite being linked into host::static")
endif()

add_library(stale_static STATIC)

add_library(stale::static ALIAS stale_static)

target_sources(
  stale_static
  PRIVATE
    host.c
)

set_property(TARGET stale_static PROPERTY BARE_MODULES "a@1.0.0")

add_library(newer_static STATIC)

add_library(newer::static ALIAS newer_static)

target_sources(
  newer_static
  PRIVATE
    host.c
)

link_bare_modules(newer::<TYPE> FROM modules.json EXCLUDE_FROM stale::<TYPE>)

get_target_property(modules newer_static BARE_MODULES)

if(NOT modules STREQUAL "a@1.2.3")
  message(FATAL_ERROR "Skipped a@1.2.3 despite only a@1.0.0 being linked into stale::static")
endif()
