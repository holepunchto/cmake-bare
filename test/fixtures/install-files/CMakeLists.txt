cmake_minimum_required(VERSION 3.25)

find_package(cmake-bare REQUIRED PATHS node_modules/cmake-bare)

project(bare_install_files C)

add_bare_module(addon INSTALL FILE file.txt DIR data PRIVACY_MANIFEST privacy.xcprivacy)

target_sources(
  ${addon}
  PRIVATE
    binding.c
)
