local C = require "c"
local J = require "j"
local JVM = require "jvm"
local declare = require "declare"

local ENV = JVM.ENV

local String = declare.class("java/lang/String")

local Class = declare.class("java/lang/Class")
declare.method(Class, Class, "forName", {symbol(String, "className")})

-- declare.method(Runtime, Runtime, "getRuntime", {})
-- declare.method(Runtime, J.long, "maxMemory", {symbol(Runtime, "self")})

local terra blah([ENV] : JVM.Env)
  var jlS = ENV:NewStringUTF("java.lang.String")
  var str = Class.static(ENV):forName(jlS)
  C.printf("%p\n", str)
end

blah(declare.makeinit()())
