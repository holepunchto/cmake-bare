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

const bundle = require('bare-dev/bundle')

bundle(entry, {
  cwd,
  config: config === '0' ? undefined : config,
  format: format === '0' ? undefined : format,
  prebuilds: prebuilds === '1',
  out,
  platform,
  arch,
  simulator: simulator === '1'
})
