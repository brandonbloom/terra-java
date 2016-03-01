local J = require "terra-java"
local C = terralib.includec("stdio.h")

local Math = J.package("java.lang").Math

terra pi()
  return Math.static(J.env):toRadians(180)
end

print(pi())
