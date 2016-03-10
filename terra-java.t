local declare = require "terra-java/declare"
local reflect = require "terra-java/reflect"
local define = require "terra-java/define"

return {
  embedded = declare.embedded,
  package = reflect.package,
  Array = declare.Array,
  new = declare.new,
  class = declare.class,
  define = define
}
