local declare = require "terra-java/declare"
local reflect = require "terra-java/reflect"

return {
  embedded = declare.embedded,
  package = reflect.package
}
