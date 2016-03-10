local ffi = require "ffi"
local jvm = require "terra-java/jvm"
local declare = require "terra-java/declare"

local ENV = declare.ENV


-- Manually declare enough reflection APIs so we can automate declarations.

local Array = declare.Array
local String = declare.class("java.lang.String")
local Class = declare.class("java.lang.Class")
local Field = declare.class("java.lang.reflect.Field")
local Method = declare.class("java.lang.reflect.Method")
local Constructor = declare.class("java.lang.reflect.Constructor")
local Modifier = declare.class("java.lang.reflect.Modifier")

declare.methods(Class, {
  {Class, "forName", {symbol(String, "className")}},
  {Array(Constructor), "getConstructors", {symbol(Class, "self")}},
  {Array(Field), "getFields", {symbol(Class, "self")}},
  {Array(Method), "getMethods", {symbol(Class, "self")}},
  {String, "getName", {symbol(Class, "self")}}
})

--TODO: Consider inheritence when declaring these.

declare.methods(Constructor, {
  {String, "getName", {symbol(Constructor, "self")}},
  {Array(Class), "getParameterTypes", {symbol(Constructor, "self")}},
  {int, "getModifiers", {symbol(Constructor, "self")}},
})

declare.methods(Field, {
  {String, "getName", {symbol(Field, "self")}},
  {Class, "getType", {symbol(Field, "self")}},
  {int, "getModifiers", {symbol(Field, "self")}},
})

declare.methods(Method, {
  {String, "getName", {symbol(Method, "self")}},
  {Class, "getReturnType", {symbol(Method, "self")}},
  {Array(Class), "getParameterTypes", {symbol(Method, "self")}},
  {int, "getModifiers", {symbol(Method, "self")}},
})

declare.field(Modifier, true, int, "STATIC")


-- Callback functions called during type visitation.

local T = nil
local member = nil

local function visit_class(chars, len)
  T = declare.class(ffi.string(chars, len))
end

local function begin_field(static)
  member = { static = static }
end

local function finish_field()
  declare.field(T, member.static, member.returns, member.name)
end

local function begin_method(static)
  member = { params = static and {} or {symbol(T, "self")} }
end

local function finish_method()
  declare.method(T, member.returns, member.name, member.params)
end

local function begin_constructor(static)
  member = { params = static and {} or {symbol(T, "self")} }
end

local function finish_constructor()
  declare.constructor(T, member.params)
end

local function set_name(chars, len)
  member.name = ffi.string(chars, len)
end

local function set_returns(chars, len)
  member.returns = declare.type(ffi.string(chars, len))
end

local function add_param(chars, len)
  local typ = declare.type(ffi.string(chars, len))
  local name = "arg" .. #member.params - 1
  local param = symbol(typ, name)
  table.insert(member.params, param)
end


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

local terra visit(T : Class) : {}

  doname(T, visit_class)

  var ctors = T:getConstructors()
  for i = 0, ctors:len() do
    visit(ctors:get(i))
  end

  var fields = T:getFields()
  for i = 0, fields:len() do
    visit(fields:get(i))
  end

  var methods = T:getMethods()
  for i = 0, methods:len() do
    visit(methods:get(i))
  end

end
and
local terra visit(ctor : Constructor) : {}

  var modifiers = ctor:getModifiers()
  var static = (modifiers and STATIC) ~= 0

  begin_constructor(static)

  var params = ctor:getParameterTypes()
  for i = 0, params:len() do
    doname(params:get(0), add_param)
  end

  finish_constructor()

end
and
local terra visit(field : Field) : {}

  var modifiers = field:getModifiers()
  var static = (modifiers and STATIC) ~= 0

  begin_field(static)
  doname(field, set_name)

  doname(field:getType(), set_returns)

  finish_field()

end
and
local terra visit(method : Method) : {}

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
  visit(Class.static():forName(jstr))
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
