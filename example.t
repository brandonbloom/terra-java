local J = require "terra-java"
local C = terralib.includec("stdio.h")

local Math = J.package("java.lang").Math

terra pi()
  J.embedded()
  return Math.static():toRadians(180)
end

print(pi())


local util = J.package("java.util")

terra minute()
  J.embedded()
  var now = J.new(util.Date)
  return now:getMinutes()
end

print(minute())


local Foo = J.class("example.Foo")
