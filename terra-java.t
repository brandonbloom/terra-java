local jvm = require "terra-java/jvm"
local reflect = require "terra-java/reflect"

return {
  env = jvm.env,
  package = reflect.package
}
