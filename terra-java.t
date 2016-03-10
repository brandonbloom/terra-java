local types = require "terra-java/types"
local declare = require "terra-java/declare"
local reflect = require "terra-java/reflect"
local define = require "terra-java/define"

local P = {
  embedded = declare.embedded,
  Array = declare.Array,
  new = declare.new,
  class = declare.class,
  package = reflect.package,
  implement = define.implement
}

for k, v in pairs(types.java_primitives) do
  P[k] = v
end

return P
