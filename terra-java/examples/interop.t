local J = require "terra-java"
local C = terralib.includec("stdio.h")

local lang = J.package("java.lang")
local util = J.package("java.util")
local Math = lang.Math

terra pi()
  J.embedded()
  return J.static(Math):toRadians(180)
end

terra minute()
  J.embedded()
  var now = J.new(util.Date)
  defer J.release(now)
  return now:getMinutes()
end

J.load()

print(pi())
print(minute())
