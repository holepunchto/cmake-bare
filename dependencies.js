const [
  cwd,
  config,
  format,
  prebuilds,
  out,
  entry,
  platform,
  arch,
  simulator
] = process.argv.slice(2)

const dependencies = require('bare-dev/dependencies')

dependencies(entry, {
  cwd,
  out: `${out}.d`
})
