local J = require "terra-java"

local ext = J.package("terrajava.examples.extension")
local Accumulator = ext.Accumulator

-- Return values and Java method interop.
terra Accumulator:isPos() : J.boolean
  return [J.boolean](self:sign() == 1.0)
end

-- C interop.
local C = terralib.includec("math.h")
terra Accumulator:sqrt()
  self:value(C.sqrt(self:value()))
end

-- Parameters and overloading.
Accumulator.methods.add = terralib.overloadedfunction("add", {

  terra(self : Accumulator, x : J.double)
    self:value(self:value() + x)
  end,

  terra(self : Accumulator, x : J.int)
    self:add([double](x)) -- XXX huh, broken?
  end

})

-- Compile the package's native extensions to `libextension.jnilib`.
J.savelib("./obj", "extension", ext)


-- Use the extension immediately.

terra f()
  J.embedded()
  var acc = J.new(Accumulator)
  acc:add(5)
  acc:add(2.5)
  return acc:getValue()
end

J.load()
print(f())
