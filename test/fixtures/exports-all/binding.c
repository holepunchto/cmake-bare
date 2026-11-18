#include <bare.h>
#include <js.h>

static __attribute__((noinline)) js_value_t *
exports_all_kept(js_env_t *env) {
  js_value_t *result;
  js_create_object(env, &result);
  return result;
}

static js_value_t *
exports_all_exports(js_env_t *env, js_value_t *exports) {
  return exports_all_kept(env);
}

BARE_MODULE(exports_all, exports_all_exports)
