local ffi = require "ffi"
local jvm = require "terra-java/jvm"
local declare = require "terra-java/declare"
local parse = require "terra-java/declare"
local C = require "terra-java/c"

local ENV = declare.ENV


-- Manually declare enough reflection APIs so we can automate declarations.
--XXX Need to un-memoize String so that the parsing will define it fully.
local String = declare.class("java.lang.String")
local Lib = declare.class("terrajava.Lib")

declare.method(Lib, declare.Array(int8), "getClassBytes", {symbol(String, "className")})


terra f()
  declare.embedded()
  var lib = Lib.static()
  var name = String.this(ENV:NewStringUTF("java.util.Date")) --XXX make helper
  var byteArr = lib:getClassBytes(name)
  var bs = byteArr:acquire()
  defer bs:release()
  C.printf("OMG %d\n", bs.len)
end

f()
error("done")


-- Callback functions called during type visitation.

local T = nil
local member = nil

local begin_class = terralib.cast({&int8, int} -> {}, function(chars, len)
  T = declare.class(ffi.string(chars, len))
end)

local begin_field = terralib.cast({bool} -> {}, function(static)
  member = { static = static }
end)

local finish_field = terralib.cast({} -> {}, function()
  declare.field(T, member.static, member.returns, member.name)
end)

local begin_method = terralib.cast({bool} -> {}, function(static)
  member = { params = static and {} or {symbol(T, "self")} }
end)

local finish_method = terralib.cast({} -> {}, function()
  declare.method(T, member.returns, member.name, member.params)
end)

local begin_constructor = terralib.cast({bool} -> {}, function(static)
  member = { params = static and {} or {symbol(T, "self")} }
end)

local finish_constructor = terralib.cast({} -> {}, function()
  declare.constructor(T, member.params)
end)

local set_name = terralib.cast({&int8, int} -> {}, function(chars, len)
  member.name = ffi.string(chars, len)
end)

local set_returns = terralib.cast({&int8, int} -> {}, function(chars, len)
  member.returns = declare.type(ffi.string(chars, len))
end)

local add_param = terralib.cast({&int8, int} -> {}, function(chars, len)
  local typ = declare.type(ffi.string(chars, len))
  local name = "arg" .. #member.params - 1
  local param = symbol(typ, name)
  table.insert(member.params, param)
end)


-- Via Java reflection, visit a type with above callbacks.

local STATIC = (terra()
  declare.embedded()
  return Modifier.static():STATIC()
end)()

--TODO: belongs elsewhere?
local unpackstr = macro(function(s)
  return quote
    var obj = s._obj
    var len = obj:GetStringUTFLength()
    var chars = obj:GetStringUTFChars(nil)
    defer obj:ReleaseStringUTFChars(chars)
  in
    chars, len
  end
end)

local doname = macro(function(obj, f)
  return quote
    do
      var name = obj:getName()
      var chars, len = unpackstr(name)
      f(chars, len)
    end
  end
end)

local terra visit_class(T : Class) : {}

  doname(T, begin_class)

  var ctors = T:getDeclaredConstructors()
  for i = 0, ctors:len() do
    visit_constructor(ctors:get(i))
  end

  var fields = T:getDeclaredFields()
  for i = 0, fields:len() do
    visit_field(fields:get(i))
  end

  var methods = T:getDeclaredMethods()
  for i = 0, methods:len() do
    visit_method(methods:get(i))
  end

end

local terra visit_constructor(ctor : Constructor) : {}

  var modifiers = ctor:getModifiers()
  var static = (modifiers and STATIC) ~= 0

  begin_constructor(static)

  var params = ctor:getParameterTypes()
  for i = 0, params:len() do
    doname(params:get(0), add_param)
  end

  finish_constructor()

end

local terra visit_field(field : Field) : {}

  var modifiers = field:getModifiers()
  var static = (modifiers and STATIC) ~= 0

  begin_field(static)
  doname(field, set_name)

  doname(field:getType(), set_returns)

  finish_field()

end

local terra visit_method(method : Method) : {}

  var modifiers = method:getModifiers()
  var static = (modifiers and STATIC) ~= 0

  begin_method(static)
  doname(method, set_name)

  doname(method:getReturnType(), set_returns)

  var params = method:getParameterTypes()
  for i = 0, params:len() do
    doname(params:get(i), add_param)
  end

  finish_method()

end

local terra doreflect(name : rawstring)
  declare.embedded()
  var jstr = String.this(ENV:NewStringUTF(name))
  visit_class(Class.static():forName(jstr))
end


local P = {}

P.class = terralib.memoize(function(name)
  doreflect(name)
  local ret = T
  member = nil
  T = nil
  return ret
end)

function P.package(name)
  local mt = {
    name = name,
    __index = function(tbl, key)
      return P.class(name .. "." .. key)
    end,
  }
  return setmetatable({}, mt)
end

return P
