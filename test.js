const { build } = require('./test/helpers')

build('test/fixtures/addon')
build('test/fixtures/napi-addon')
build('test/fixtures/install-off', { install: false })
build('test/fixtures/install-files', {
  files: (host) => ({
    'install-files/file.txt': true,
    'install-files/data/nested/file.txt': true,
    'install-files/PrivacyInfo.xcprivacy': /^(darwin|ios|watchos)-/.test(host)
  })
})
build('test/fixtures/scoped-addon')
build('test/fixtures/provided-headers')
build('test/fixtures/runtime-dependency')
build('test/fixtures/transitive-dependency')
build('test/fixtures/dependent-addon/a')
build('test/fixtures/dependent-addon/b')
build('test/fixtures/library-receiver')
