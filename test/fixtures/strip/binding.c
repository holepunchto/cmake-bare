#include <bare.h>
#include <js.h>

__attribute__((noinline)) js_value_t *
strip_kept(js_env_t *env) {
  js_value_t *result;
  js_create_object(env, &result);
  return result;
}

static js_value_t *
strip_exports(js_env_t *env, js_value_t *exports) {
  return strip_kept(env);
}

BARE_MODULE(strip, strip_exports)
