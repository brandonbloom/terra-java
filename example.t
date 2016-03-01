local J = require "terra-java"
local C = terralib.includec("stdio.h")

local Math = J.package("java.lang").Math

terra pi()
  J.embedded()
  return Math.static():toRadians(180)
end

print(pi())


terra right()
  var rect = J.new(Rectangle, 20, 50, 100, 200)
  return rect:x() + rect:width()
end

ex()
