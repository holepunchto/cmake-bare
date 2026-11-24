cmake_minimum_required(VERSION 3.25)

find_package(cmake-bare REQUIRED PATHS node_modules/cmake-bare)

project(bare_cxx_runtime_off C CXX)

add_bare_module(addon SOURCES binding.cc CXX_RUNTIME OFF)
