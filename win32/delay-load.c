#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#include <windows.h> // Must come first

#include <delayimp.h>
#include <string.h>

static FARPROC WINAPI
bare_delay_load (unsigned int event, DelayLoadInfo *info) {
  if (event != dliNotePreLoadLibrary) return NULL;

  if (_stricmp(info->szDll, "bare.exe") != 0) return NULL;

  return (FARPROC) GetModuleHandle(NULL);
}

const PfnDliHook __pfnDliNotifyHook2 = bare_delay_load;
