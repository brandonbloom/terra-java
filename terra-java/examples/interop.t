local J = require "terra-java"
local C = terralib.includec("stdio.h")

local lang = J.package("java.lang")
local Math = lang.Math

--XXX Add J.release calls as needed to this file.

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
