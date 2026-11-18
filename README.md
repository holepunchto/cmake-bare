# cmake-bare

Bare utilities for CMake.

```
npm i cmake-bare
```

```cmake
find_package(cmake-bare REQUIRED PATHS node_modules/cmake-bare)
```

## API

#### `bare_platform(<result> [HOST])`

Write the current compilation target platform to the `<result>` variable. Pass the `HOST` option to write the build host platform instead.

#### `bare_arch(<result> [HOST])`

Write the current compilation target architecture to the `<result>` variable. Pass the `HOST` option to write the build host architecture instead.

#### `bare_simulator(<result> [HOST])`

Write whether or not the current compilation target is a simulator to the `<result>` variable. Pass the `HOST` option to write whether the build host is a simulator instead, which it never is.

#### `bare_environment(<result> [HOST])`

Write the current compilation target environment to the `<result>` variable. Pass the `HOST` option to write the build host environment instead.

#### `bare_target(<result> [HOST])`

Write the current compilation target to the `<result>` variable. Pass the `HOST` option to write the build host target instead.

#### `bare_module_target(<directory> <result> [NAME <var>] [VERSION <var>] [HASH <var>])`

Determine the CMake library target name of the module in `<directory>` and write the result to the `<result>` variable. The `NAME`, `VERSION`, and `HASH` arguments can be passed to access specific portions of the target name which will be of the format `${name}-${version}-${hash}`.

#### `add_bare_module(<result> [SOURCES <files>...] [LINK <libraries>...] [EXPORTS [<symbols>...]] [EXPORTS_FROM <path>] [NAME <name>] [INSTALL OFF | INSTALL [TARGET <target> | FILE <path> | DIR <path> | PRIVACY_MANIFEST <path>]...])`

Add a Bare native addon target and write the target name to the `<result>` variable. Pass `INSTALL OFF` to add no install rules for the native addon, such as when it's only used by tests.

`SOURCES` are compiled into the native addon, like those added with `target_sources(<result> PRIVATE ...)`. `LINK` lists the libraries it links. Entries of the form `<package>::<TYPE>` link `<package>::static`, as created by `add_library_targets()` from `cmake-prelude`, so that the native addon is self-contained, both as a shared library and when linked into another target.

To ship other files with the native addon, pass them to `INSTALL`. They're installed into a `<name>` directory next to the native addon. `TARGET` installs the file built by a target, such as a shared library the native addon links. `FILE` installs a single file. `DIR` installs a directory the same way as `install(DIRECTORY)`, so a trailing slash installs only its contents. `PRIVACY_MANIFEST` installs an Apple privacy manifest as `PrivacyInfo.xcprivacy`, but only for Apple targets. WebAssembly addons accept `FILE` and `DIR`, but not `TARGET`.

By default, the native addon exports only the symbols that Bare needs to load it. To let other native addons link against it, list the symbols to export with `EXPORTS`, or with `EXPORTS_FROM`, which takes a JSON array of strings or a file with one symbol per line:

```json
["addon_fn", "addon_other_fn"]
```

A lone `EXPORTS`, without any symbols, exports all symbols of the native addon instead.

#### `include_bare_module(<specifier> <result> [PREBUILD] [SOURCE_DIR <var>] [BINARY_DIR <var>] [WORKING_DIRECTORY <path>])`

Include the Bare native addon identified by `<specifier>` and write its library target name to the `<result>` variable. If `PREBUILD` is passed then the native addon prebuild will be included as an imported target. The `SOURCE_DIR` and `BINARY_DIR` arguments can be passed to access the source and binary directories of the included addon.

To change the working directory from which `<specifier>` is resolved, pass the `WORKING_DIRECTORY` argument.

#### `link_bare_module(<receiver> <specifier> [SHARED] [WORKING_DIRECTORY <path>])`

Link the Bare native addon identified by `<specifier>` to the library target identified by `<receiver>`. By default, the objects of the native addon will be linked, effectively embedding the addon in `<receiver>`. To instead link the shared library target of the native addon, such as when `<receiver>` is itself another native addon, pass the `SHARED` option.

`<receiver>` may be an alias. A receiver of the form `<name>::<TYPE>` links each of the `<name>::static` and `<name>::shared` libraries that exist, as created by `add_library_targets()` from `cmake-prelude`.

To change the working directory from which `<specifier>` is resolved, pass the `WORKING_DIRECTORY` argument.

The package name of the native addon is appended to the `BARE_MODULES` property of each library it's linked to.

#### `link_bare_modules(<receiver> [SHARED] [FROM <path>] [EXCLUDE <name...>] [EXCLUDE_FROM <path> | <target>] [WORKING_DIRECTORY <path>])`

Link all Bare native addons declared as dependencies in the `package.json` manifest of the current source directory to the library target identified by `<receiver>`. Arguments are the same of for `link_bare_module()`. To skip some of the native addons, pass their package names with `EXCLUDE`.

To instead link the native addons from a list of builtins, pass `FROM` with the path to a JSON file holding an array of module specifiers. Entries may use conditions, with the same syntax as the `"exports"` and `"imports"` fields of `package.json`. The conditions are the platform, architecture, and environment of the target, such as `"darwin"` and `"arm64"`, and `"addon"`. Only the entries matched through the `"addon"` condition are linked:

```json
[{ "addon": "bare-buffer" }, { "linux": { "addon": "bare-linux-only" } }, "bare-javascript-only"]
```

To skip the native addons already linked into a library that `<receiver>` links, pass `EXCLUDE_FROM` with that library, which may be an alias or of the form `<name>::<TYPE>`. The native addons recorded in its `BARE_MODULES` property are then skipped. `EXCLUDE_FROM` also accepts the path of another list of builtins, whose native addons are skipped instead. Exclusions match package names, so a specifier such as `bare-fs@4` is skipped by excluding `bare-fs`.

#### `link_bare_headers(<target>)`

Make the Bare headers available to `<target>`. If a `bare::headers` target exists it is linked, otherwise the `bare-headers` package is downloaded.

### Providing Bare

By default, native addons are compiled against a download of the `bare-headers` package and, on Windows, linked against the import library of a download of the `bare-runtime` package. A build that provides its own Bare, such as Bare itself or an embedder compiling Bare from source, can instead define the following targets before adding any native addons:

- `bare::headers`: An interface library that provides the Bare headers as include directories.
- `bare::shared`: On Windows, the shared library of the Bare runtime, whose import library native addons link against.

As target names containing `::` are reserved for aliases and imported targets, define each as either an alias of a regular target or a global imported target. Native addons will then be compiled and linked against the provided Bare without downloading anything.

## License

Apache-2.0
