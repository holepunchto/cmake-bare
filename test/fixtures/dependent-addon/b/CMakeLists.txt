cmake_minimum_required(VERSION 3.25)

find_package(cmake-bare REQUIRED PATHS node_modules/cmake-bare)

project(bare_addon_b C)

add_bare_module(addon_b)

target_sources(
  ${addon_b}
  PRIVATE
    binding.c
)

link_bare_modules(${addon_b} SHARED FROM modules.json EXCLUDE excluded EXCLUDE_FROM excluded.json)
