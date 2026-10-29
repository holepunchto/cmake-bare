cmake_minimum_required(VERSION 3.25)

find_package(cmake-bare REQUIRED PATHS node_modules/cmake-bare)

project(bare_install_off C)

add_bare_module(addon INSTALL OFF)

target_sources(
  ${addon}
  PRIVATE
    binding.c
)
