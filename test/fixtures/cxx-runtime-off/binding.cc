#include <bare.h>
#include <js.h>

static int
cxx_runtime_off_count() {
  static int count = 0;
  return ++count;
}

static js_value_t *
cxx_runtime_off_exports(js_env_t *env, js_value_t *exports) {
  static int count = cxx_runtime_off_count();

  js_value_t *result;
  js_create_int32(env, count, &result);
  return result;
}

BARE_MODULE(cxx_runtime_off, cxx_runtime_off_exports)
