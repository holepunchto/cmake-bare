// Delay loader implementation for Windows. This is used to support loading
// native addons from binaries that don't declare themselves as "bare.exe" as
// well as loading dynamically linked native addons and their dependencies.
//
// See https://learn.microsoft.com/en-us/cpp/build/reference/understanding-the-helper-function

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#include <windows.h> // Must come first

#include <delayimp.h>
#include <stdlib.h>
#include <string.h>
#include <uv.h>

typedef uv_lib_t *(*bare__module_find_fn)(const char *name);

static inline int
bare__string_equals(LPCSTR a, LPCSTR b) {
  return _stricmp(a, b) == 0;
}

static inline int
bare__string_ends_with(LPCSTR a, LPCSTR b) {
  size_t a_len = strlen(a);
  size_t b_len = strlen(b);

  if (b_len > a_len) return 0;

  return bare__string_equals(a + a_len - b_len, b);
}

static inline int
bare__string_last_index_of(LPCSTR string, CHAR c) {
  size_t len = strlen(string);

  if (len == 0) return -1;

  for (size_t i = len; i-- > 0;) {
    if (string[i] == c) return i;
  }

  return -1;
}

static HMODULE bare__module_self = NULL;

static inline HMODULE
bare__module_main(void) {
  static HMODULE main = NULL;

  if (main == NULL) main = GetModuleHandle(NULL);

  return main;
}

typedef BOOL(WINAPI *bare__enum_process_modules_fn)(HANDLE process, HMODULE *modules, DWORD size, LPDWORD needed);

// Pinned, so the cached handle stays valid even if the module is freed.
static inline HMODULE
bare__module_pin(HMODULE module, const char *symbol) {
  HMODULE pinned;

  BOOL ok = GetModuleHandleExW(
    GET_MODULE_HANDLE_EX_FLAG_PIN | GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS,
    (LPCWSTR) GetProcAddress(module, symbol),
    &pinned
  );

  return ok ? pinned : module;
}

// The only module exporting the runtime: the binary itself when Bare is linked
// statically, otherwise the shared library it lives in. Two of them means two
// runtimes, and binding an addon to the wrong one silently mixes their state, so
// prefer failing to load.
static inline HMODULE
bare__module_runtime(void) {
  static HMODULE runtime = NULL;

  if (runtime != NULL) return runtime;

  HMODULE main = bare__module_main();

  if (GetProcAddress(main, "bare_module_find") != NULL) {
    runtime = main;

    return runtime;
  }

  HMODULE kernel32 = GetModuleHandleA("kernel32.dll");

  if (kernel32 == NULL) return NULL;

  // Resolved at run time so no addon carries a static psapi import.
  bare__enum_process_modules_fn enum_process_modules =
    (bare__enum_process_modules_fn) GetProcAddress(kernel32, "K32EnumProcessModules");

  if (enum_process_modules == NULL) return NULL;

  HANDLE process = GetCurrentProcess();

  DWORD needed = 0;

  if (!enum_process_modules(process, NULL, 0, &needed) || needed == 0) return NULL;

  HMODULE *modules = malloc(needed);

  if (modules == NULL) return NULL;

  HMODULE found = NULL;

  if (enum_process_modules(process, modules, needed, &needed)) {
    DWORD len = needed / sizeof(HMODULE);

    for (DWORD i = 0; i < len; i++) {
      if (GetProcAddress(modules[i], "bare_module_find") == NULL) continue;

      if (found != NULL) {
        found = NULL;

        break;
      }

      found = modules[i];
    }
  }

  free(modules);

  if (found == NULL) return NULL;

  runtime = bare__module_pin(found, "bare_module_find");

  return runtime;
}

static inline HMODULE
bare__module_find(const char *name) {
  static bare__module_find_fn find = NULL;

  if (find == NULL) {
    HMODULE runtime = bare__module_runtime();

    if (runtime == NULL) return NULL;

    find = (bare__module_find_fn) GetProcAddress(runtime, "bare_module_find");

    if (find == NULL) return NULL;
  }

  uv_lib_t *lib = find(name);

  if (lib == NULL) return NULL;

  return (HMODULE) lib->handle;
}

static inline HMODULE
bare__module_load(const char *dll) {
  if (bare__module_self == NULL) return NULL;

  CHAR path[MAX_PATH];

  DWORD len = GetModuleFileNameA(bare__module_self, path, MAX_PATH);

  if (bare__string_ends_with(path, ".bare")) {
    path[len - 5] = L'\0';
  } else {
    int i = bare__string_last_index_of(path, '\\');

    if (i != -1) path[i] = L'\0';
  }

  strcat_s(path, MAX_PATH, "\\");
  strcat_s(path, MAX_PATH, dll);

  // The libraries installed next to the addon depend on each other by name and
  // PE has no runpath, so the loader is told to resolve whatever it loads here
  // from this directory as well. Without it only the named library is found and
  // its own dependencies fall back to the ambient search order.
  return LoadLibraryExA(
    path,
    NULL,
    LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_DEFAULT_DIRS
  );
}

static FARPROC WINAPI
bare__delay_load(unsigned event, PDelayLoadInfo info) {
  switch (event) {
  case dliNotePreLoadLibrary: {
    LPCSTR dll = info->szDll;

    if (bare__string_equals(dll, "bare.exe") || bare__string_equals(dll, "bare.dll")) {
      return (FARPROC) bare__module_runtime();
    }

    if (bare__string_ends_with(dll, ".bare")) {
      return (FARPROC) bare__module_find(dll);
    }

    if (bare__string_ends_with(dll, ".dll")) {
      return (FARPROC) bare__module_load(dll);
    }

    return NULL;
  }

  default:
    return NULL;
  }
}

const PfnDliHook __pfnDliNotifyHook2 = bare__delay_load;

const PfnDliHook __pfnDliFailureHook2 = bare__delay_load;

BOOL WINAPI
DllMain(HINSTANCE handle, DWORD reason, LPVOID reserved) {
  if (reason == DLL_PROCESS_ATTACH) bare__module_self = handle;

  return TRUE;
}
