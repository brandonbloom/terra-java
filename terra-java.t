local types = require "terra-java/types"
local declare = require "terra-java/declare"
local reflect = require "terra-java/reflect"
local define = require "terra-java/define"
local ref = require "terra-java/ref"

local P = {
  embedded = declare.embedded,
  Array = declare.Array,
  new = declare.new,
  class = declare.getclass,
  package = reflect.package,
  implement = define.implement,
  retain = ref.retain,
  release = ref.release
}

for k, v in pairs(types.java_primitives) do
  P[k] = v
end

return P
