const test = require('brittle')
const fs = require('fs')
const path = require('path')
const make = require('bare-make')

const modules = path.resolve(__dirname, '..', 'node_modules')

const isBare = typeof Bare !== 'undefined'

exports.build = function build(fixture, opts = {}) {
  const { install = true, files = () => ({}), binary, contains = () => ({}) } = opts

  test(fixture, { timeout: 300000 }, async (t) => {
    const cwd = path.resolve(__dirname, '..', fixture)

    await make.generate({
      cwd,
      source: '.',
      build: 'build',
      cache: false,
      define: [`CMAKE_PREFIX_PATH=${modules}`],
      stdio: 'inherit'
    })

    await make.build({ cwd, build: 'build', clean: true, stdio: 'inherit' })

    await make.install({ cwd, build: 'build', prefix: 'prebuilds', stdio: 'inherit' })

    const prebuilds = path.join(cwd, 'prebuilds')

    if (!install) {
      t.absent(fs.existsSync(prebuilds), 'installs nothing')
      return
    }

    for (const host of fs.readdirSync(prebuilds)) {
      for (const [file, expected] of Object.entries(files(host))) {
        t.is(
          fs.existsSync(path.join(prebuilds, host, file)),
          expected,
          `${expected ? 'installs' : 'skips'} ${file}`
        )
      }

      const texts = Object.entries(contains(host))

      if (texts.length === 0) continue

      const data = fs.readFileSync(path.join(prebuilds, host, binary))

      for (const [text, expected] of texts) {
        t.is(data.includes(text), expected, `${expected ? 'keeps' : 'removes'} ${text}`)
      }
    }

    if (isBare) {
      t.ok(require(path.join(cwd, 'index.js')), 'loads')
    } else {
      t.pass('built')
    }
  })
}
