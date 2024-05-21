const [
  type
] = process.argv.slice(2)

const paths = require('bare-dev/paths')

switch (type) {
  case 'napi':
    console.log(paths['compat/napi'])
    break
  default:
    console.log(paths.include)
}
