# cmake-bare

## API

#### `find_bare(<result>)`

#### `find_bare_dev(<result>)`

#### `bare_platform(<result>)`

#### `bare_arch(<result>)`

#### `bare_simulator(<result>)`

#### `bare_target(<result>)`

#### `bare_module_target(<directory> <result>)`

#### `add_bare_module(<result>)`

#### `include_bare_module(<specifier> <result>)`

#### `link_bare_module(<receiver> <specifier> [AMALGAMATE [EXCLUDE <target...>] [RUNTIME_LIBRARIES <target...>]])`

#### `link_bare_modules(<receiver> [AMALGAMATE [EXCLUDE <target...>] [RUNTIME_LIBRARIES <target...>]])`

#### `bare_include_directories(<result> [NAPI])`

#### `add_bare_bundle(ENTRY <path> OUT <path> [CONFIG <path>] [FORMAT BUNDLE|JS] [TARGET JS|C] [NAME <string>] [WORKING_DIRECTORY <path>] [DEPENDS <path...>])`

#### `mirror_drive(SOURCE <key | path> DESTINATION <key | path> [PREFIX <path>] [CHECKOUT <length>] [WORKING_DIRECTORY <path>])`

## License

Apache-2.0
