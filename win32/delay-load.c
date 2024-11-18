// Delay loader implementation for Windows. This is used to support loading
// native addons from binaries that don't declare themselves as "bare.exe".
//
// See https://learn.microsoft.com/en-us/cpp/build/reference/understanding-the-helper-function

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#include <windows.h> // Must come first

#include <delayimp.h>
#include <string.h>

static inline int
bare__string_equals (LPCSTR a, LPCSTR b) {
  return _stricmp(a, b) == 0;
}

static inline int
bare__string_ends_with (LPCSTR a, LPCSTR b) {
  size_t a_len = strlen(a);
  size_t b_len = strlen(b);

  if (b_len > a_len) return 0;

  return bare__string_equals(a + a_len - b_len, b);
}

static FARPROC WINAPI
bare__delay_load (unsigned event, PDelayLoadInfo info) {
  switch (event) {
  case dliNotePreLoadLibrary:
    LPCSTR dll = info->szDll;

    if (bare__string_equals(dll, "bare.exe") || bare__string_equals(dll, "bare.dll")) {
      return (FARPROC) GetModuleHandle(NULL);
    }

    if (bare__string_ends_with(dll, ".bare")) {
      return NULL; // TODO
    }

    return NULL;

  default:
    return NULL;
  }
}

const PfnDliHook __pfnDliNotifyHook2 = bare__delay_load;

const PfnDliHook __pfnDliFailureHook2 = bare__delay_load;
