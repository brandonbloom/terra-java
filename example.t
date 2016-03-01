
local reflect = require "reflect"
local lang = reflect.package("java.lang")


print(lang.Math)


--[[

local C = terralib.includec("stdio.h")
local J = require("terra-java")
local Math = J.package("java.lang").Math


var pi = Math.toRadians(180)

--]]
