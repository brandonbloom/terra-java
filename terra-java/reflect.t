local ffi = require "ffi"
local jni = require "terra-java/jni"
local jvm = require "terra-java/jvm"
local declare = require "terra-java/declare"

local ENV = declare.ENV


-- Manually declare enough reflection APIs so we can automate declarations.

local Array = declare.Array
local String = declare.class("java.lang.String")
local Class = declare.class("java.lang.Class")
local Method = declare.class("java.lang.reflect.Method")
local Constructor = declare.class("java.lang.reflect.Constructor")

declare.methods(Class, {
  {Class, "forName", {symbol(String, "className")}},
  {Array(Constructor), "getConstructors", {symbol(Class, "self")}},
  {Array(Method), "getMethods", {symbol(Class, "self")}},
  {String, "getName", {symbol(Class, "self")}}
})

--TODO: Consider inheritence when declaring these.

declare.methods(Constructor, {
  {String, "getName", {symbol(Constructor, "self")}},
  {Array(Class), "getParameterTypes", {symbol(Constructor, "self")}},
})

declare.methods(Method, {
  {String, "getName", {symbol(Method, "self")}},
  {Class, "getReturnType", {symbol(Method, "self")}},
  {Array(Class), "getParameterTypes", {symbol(Method, "self")}},
  {jni.int, "getModifiers", {symbol(Method, "self")}},
})


-- Callback functions called during type visitation.

local class = nil
local subject = nil

local function visit_class(chars, len)
  class = declare.class(ffi.string(chars, len))
end

local function begin_method(static)
  subject = {
    params = static and {} or {symbol(class, "self")}
  }
end

local function finish_method()
  declare.method(class, subject.returns, subject.name, subject.params)
end

local function begin_constructor()
  subject = {params = {}}
end

local function finish_constructor()
  declare.constructor(class, subject.params)
end

local function set_name(chars, len)
  subject.name = ffi.string(chars, len)
end

local function set_returns(chars, len)
  subject.returns = declare.type(ffi.string(chars, len))
end

local function add_param(chars, len)
  local typ = declare.type(ffi.string(chars, len))
  local name = "arg" .. #subject.params - 1
  local param = symbol(typ, name)
  table.insert(subject.params, param)
end


-- Via Java reflection, visit a type with above callbacks.

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

local terra visit(class : Class) : {}

  doname(class, visit_class)

  var ctors = class:getConstructors()
  for i = 0, ctors:len() do
    visit(ctors:get(i))
  end

  var methods = class:getMethods()
  for i = 0, methods:len() do
    visit(methods:get(i))
  end

end
and
local terra visit(ctor : Constructor) : {}

  begin_constructor()
  doname(ctor, set_name)

  var params = ctor:getParameterTypes()
  for i = 0, params:len() do
    doname(params:get(0), add_param)
  end

  finish_constructor()

end
and
local terra visit(method : Method) : {}

  var modifiers = method:getModifiers()
  var static = (modifiers and 8) ~= 0 --XXX 8 is static, use real constant.

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
  var jlS = String.this(ENV:NewStringUTF(name))
  var class = Class.static():forName(jlS)
  visit(class)
end


local P = {}

function P.class(name)
  doreflect(name)
  local ret = class
  subject = nil
  class = nil
  return ret
end

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
