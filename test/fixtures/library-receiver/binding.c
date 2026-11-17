#include <assert.h>
#include <bare.h>
#include <js.h>

int
dep_value(void);

static js_value_t *
library_receiver_exports(js_env_t *env, js_value_t *exports) {
  int err = js_create_int32(env, dep_value(), &exports);
  assert(err == 0);

  return exports;
}

BARE_MODULE(library_receiver, library_receiver_exports)
