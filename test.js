const { build } = require('./test/helpers')

build('test/fixtures/addon')
build('test/fixtures/comma,path')
build('test/fixtures/napi-addon')
build('test/fixtures/install-off', { install: false })
build('test/fixtures/install-files', {
  files: (host) => ({
    'install-files/file.txt': true,
    'install-files/data/nested/file.txt': true,
    'install-files/PrivacyInfo.xcprivacy': /^(darwin|ios|watchos)-/.test(host)
  })
})
build('test/fixtures/unused-code', {
  binary: 'unused-code.bare',
  contains: (host) =>
    host.startsWith('win32-') ? {} : { 'unused code marker': false, unused_code_kept: true }
})
build('test/fixtures/strip', {
  binary: 'strip.bare',
  contains: (host) => (host.startsWith('win32-') ? {} : { strip_kept: false })
})
build('test/fixtures/cxx-runtime-off', {
  binary: 'cxx-runtime-off.bare',
  contains: (host) =>
    host.startsWith('win32-')
      ? {}
      : { __cxa_guard_acquire: false, 'libc++': false, 'libstdc++': false }
})
build('test/fixtures/exports-all', {
  binary: 'exports-all.bare',
  contains: (host) => (host.startsWith('win32-') ? {} : { exports_all_kept: true })
})
build('test/fixtures/scoped-addon')
build('test/fixtures/provided-headers')
build('test/fixtures/runtime-dependency')
build('test/fixtures/transitive-dependency')
build('test/fixtures/dependent-addon/a')
build('test/fixtures/dependent-addon/b')
build('test/fixtures/library-receiver')
