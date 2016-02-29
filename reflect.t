local ffi = require "ffi"
local C = require "c"
local J = require "j"
local JVM = require "jvm"
local declare = require "declare"

local ENV = JVM.ENV


-- Manually declare enough reflection APIs so we can automate declarations.

local Array = declare.Array
local String = declare.class("java.lang.String")
local Class = declare.class("java.lang.Class")
local Method = declare.class("java.lang.reflect.Method")

declare.methods(Class, {
  {Class, "forName", {symbol(String, "className")}},
  {Array(Method), "getMethods", {symbol(Class, "self")}},
  {String, "getName", {symbol(Class, "self")}}
})

declare.methods(Method, {
  {String, "getName", {symbol(Method, "self")}},
  {Class, "getReturnType", {symbol(Method, "self")}},
})


-- Callback functions for building up the description of a reflected class.

local stack = {}     -- Things that are being built.
local subject = nil  -- Top of the stack.
local built = nil    -- Most recently finished thing.

local function begin(kind)
  if subject then
    table.insert(stack, subject)
  end
  subject = {kind = kind}
end

local function finish()
  built = subject
  subject = table.remove(stack)
end

local function begin_class()
  begin("class")
  subject.methods = {}
end

local function finish_class()
  finish()
end

local function begin_method()
  begin("method")
  subject.params = {}
end

local function finish_method()
  finish()
  table.insert(subject.methods, built)
end

local function set_name(chars, len)
  subject.name = ffi.string(chars, len)
  print(subject.name)
end

local function set_returns(chars, len)
  subject.returns = ffi.string(chars, len)
  print("", subject.returns)
end

-- Via Java reflection, visit a type and call the above builders.

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

local terra visit(class : Class) : {}
  begin_class()
  var name = class:getName()
  var chars, len = unpackstr(name)
  set_name(chars, len)
  var methods = class:getMethods()
  var n = methods:len()
  for i = 0, n do
    visit(methods:get(i))
  end
  finish_class()
end
and
local terra visit(method : Method) : {}
  begin_method()
  do
    var name = method:getName()
    var chars, len = unpackstr(name)
    set_name(chars, len)
  end
  do
    var returns = method:getReturnType()
    var name = returns:getName()
    var chars, len = unpackstr(name)
    set_returns(chars, len)
  end
  finish_method()
end

local terra doreflect([ENV] : JVM.Env, name : rawstring)
  var jlS = String.this(ENV, ENV:NewStringUTF(name))
  var class = Class.static(ENV):forName(jlS)
  visit(class)
end


-- Lua entry point to class reflection.
local function reflect(env, name)
  doreflect(env, name)
  assert(built and not subject and #stack == 0)
  local ret = built
  built = nil
  return ret
end

reflect(declare.makeinit()(), "java.lang.String")
