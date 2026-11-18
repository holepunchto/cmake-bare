#include <bare.h>
#include <js.h>

static const char marker[] = "unused code marker";

int
unused_code_unused(int i) {
  return marker[i];
}

__attribute__((noinline)) js_value_t *
unused_code_kept(js_env_t *env) {
  js_value_t *result;
  js_create_object(env, &result);
  return result;
}

static js_value_t *
unused_code_exports(js_env_t *env, js_value_t *exports) {
  return unused_code_kept(env);
}

BARE_MODULE(unused_code, unused_code_exports)
