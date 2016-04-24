local types = require "terra-java/types"
local declare = require "terra-java/declare"
local reflect = require "terra-java/reflect"
local ref = require "terra-java/ref"

local P = {
  load = declare.load,
  embedded = declare.embedded,
  Array = declare.Array,
  null = declare.null,
  new = declare.new,
  class = declare.getclass,
  package = reflect.package,
  retain = ref.retain,
  release = ref.release
}

for k, v in pairs(types.java_primitives) do
  P[k] = v
end

return P
