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

static FARPROC WINAPI
bare_delay_load (unsigned event, PDelayLoadInfo info) {
  switch (event) {
  case dliNotePreLoadLibrary:
    if (_stricmp(info->szDll, "bare.exe") == 0 || _stricmp(info->szDll, "bare.dll") == 0) {
      return (FARPROC) GetModuleHandle(NULL);
    }
    break;

  default:
    return NULL;
  }

  return NULL;
}

const PfnDliHook __pfnDliNotifyHook2 = bare_delay_load;

const PfnDliHook __pfnDliFailureHook2 = bare_delay_load;
