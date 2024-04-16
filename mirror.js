const [
  cwd,
  prefix,
  checkout,
  source,
  destination
] = process.argv.slice(2)

require('bare-dev/drive').mirror(source, destination, {
  cwd,
  prefix,
  checkout: +checkout,
  quiet: false
})
