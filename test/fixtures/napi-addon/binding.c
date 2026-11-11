#include <assert.h>
#include <node_api.h>

static napi_value
addon_exports(napi_env env, napi_value exports) {
  napi_status status = napi_create_string_utf8(env, "Hello from addon", NAPI_AUTO_LENGTH, &exports);
  assert(status == napi_ok);

  return exports;
}

NAPI_MODULE(addon, addon_exports)
