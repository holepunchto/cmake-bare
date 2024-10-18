# cmake-bare

```
npm i cmake-bare
```

```cmake
find_package(cmake-bare REQUIRED PATHS node_modules/cmake-bare)
```

## API

#### `bare_platform(<result>)`

#### `bare_arch(<result>)`

#### `bare_simulator(<result>)`

#### `bare_target(<result>)`

#### `bare_module_target(<directory> <result>)`

#### `add_bare_module(<result>)`

#### `include_bare_module(<specifier> <result>)`

#### `link_bare_module(<receiver> <specifier> [AMALGAMATE [EXCLUDE <target...>] [RUNTIME_LIBRARIES <target...>]])`

#### `link_bare_modules(<receiver> [AMALGAMATE [EXCLUDE <target...>] [RUNTIME_LIBRARIES <target...>]])`

## License

Apache-2.0
