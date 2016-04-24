local types = require "terra-java/types"
local declare = require "terra-java/declare"
local reflect = require "terra-java/reflect"
local ref = require "terra-java/ref"
local extend = require "terra-java/extend"

local P = {
  load = declare.load,
  embedded = declare.embedded,
  Array = declare.Array,
  null = declare.null,
  new = declare.new,
  class = declare.getclass,
  static = declare.static,
  package = reflect.package,
  retain = ref.retain,
  release = ref.release,
  exports = extend.exports,
  savelib = extend.savelib,
}

for k, v in pairs(types.java_primitives) do
  P[k] = v
end

return P
