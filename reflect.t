local C = require "c"
local J = require "j"
local JVM = require "jvm"
local declare = require "declare"

local ENV = JVM.ENV

local Array = declare.Array
local String = declare.class("java/lang/String")
local Method = declare.class("java/lang/reflect/Method")
local Class = declare.class("java/lang/Class")

declare.method(Class, Class, "forName", {symbol(String, "className")})
declare.method(Class, Array(Method), "getMethods", {symbol(Class, "self")})
declare.method(Method, String, "getName", {symbol(Method, "self")})

-- declare.method(Runtime, Runtime, "getRuntime", {})
-- declare.method(Runtime, J.long, "maxMemory", {symbol(Runtime, "self")})

local terra blah([ENV] : JVM.Env)
  var jlS = String.this(ENV, ENV:NewStringUTF("java.lang.String"))
  var cls = Class.static(ENV):forName(jlS)
  var methods = cls:getMethods()
  var n = methods:len()
  C.printf("n = %d\n", n)
  for i = 0, n do
    var method = methods:get(i)
    var name = method:getName()
    C.printf("%d %p %p\n", n, method, name)
  end
end

blah(declare.makeinit()())
