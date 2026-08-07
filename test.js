const { build } = require('./test/helpers')

build('test/fixtures/addon')
build('test/fixtures/scoped-addon')
build('test/fixtures/runtime-dependency')
build('test/fixtures/dependent-addon/a')
build('test/fixtures/dependent-addon/b')
