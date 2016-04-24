local ffi = require "ffi"
local jvm = require "terra-java/jvm"
local declare = require "terra-java/declare"
local parse = require "terra-java/parse"
local util = require "terra-java/util"
local C = require "terra-java/c"
local ref = require "terra-java/ref"

local ENV = declare.ENV


-- Manually declare enough reflection APIs so we can automate declarations.
local String = declare.class("java.lang.String")
local Lib = declare.class("terrajava.Lib")

declare.method(Lib,
  declare.Array(int8), "getClassBytes", {
    symbol(String, "className")
  }
)


-- Caller must :free() the result.
terra parse_classfile(name : rawstring) : parse.ClassFile
  declare.embedded()

  -- Get classfile bytes.
  var lib = declare.static(Lib)
  var jname = declare.this(String, ENV:NewStringUTF(name)) --XXX String factory
  defer ref.release(jname)
  var byteArr = lib:getClassBytes(jname)
  if declare.null(byteArr) then
    util.fatal("Cannot find class file for name: %s", name)
  end
  defer ref.release(byteArr)
  var bs = byteArr:retain()
  defer bs:release()

  -- Interpret classfile.
  return parse.from_bytes([&uint8](bs.elements))
end

declare.load()
declare.reset()


-- Looks up a value in the constant table and coerces it to a Lua string.
function getstr(cf, i)
  if i == 0 then
    return nil
  end
  local k = cf.constants.elements[i - 1]
  if k.tag == 1 then
    return ffi.string(k.utf8.elements, k.utf8.length)
  elseif k.tag == 7 then
    return getstr(cf, k.class.name_index)
  else
    util.errorf("cannot convert const %d with tag %d to string", i, k.tag)
  end
end

function getclassname(cf, i)
  local name = getstr(cf, i)
  return name and name:gsub("/", ".")
end

-- Pairs of ClassFile and Terra struct type to have their members reflected.
local todo = {}

-- Recursively declare class and supers; enqueue for member reflection.
-- Returns the declared type.
local visit_class = nil
visit_class = terralib.memoize(function(name)

  local cf = parse_classfile(name)

  local bases = terralib.newlist({})

  local super = getclassname(cf, cf.super_class)
  if super then
    table.insert(bases, super)
  end

  for i = 0, cf.interfaces.length - 1 do
    local iface = cf.interfaces.elements[i]
    table.insert(bases, getclassname(cf, iface))
  end

  bases = bases:map(visit_class)

  local this = getclassname(cf, cf.this_class)
  local T = declare.class(this)
  table.insert(todo, {cf, T})

  return T

end)

-- Parses a JNI type signature; returns an array of
-- parameter types, and the return type.
local function parse_sig(sig)
  local params = {}
  local ret = {}
  local array = false
  local target = params
  local typ = nil
  local i = 2 -- Skip "("
  while i <= #sig do
    local c = sig:sub(i, i)
    i = i + 1
    if c == ")" then
      target = ret
    elseif c == "[" then
      array = true
    elseif c == "L" then
      local j = sig:find(";", i)
      typ = declare.type(sig:sub(i, j - 1))
      i = j + 1
    else
      typ = declare.type(c)
    end
    if typ then
      if array then
        typ = declare.Array(typ)
        array = false
      end
      table.insert(target, typ)
      typ = nil
    end
  end
  return params, ret[1]
end

-- Declares all the members of a type.
local function visit_members(cf, T)

  local function member_name(m)
    return getstr(cf, m.name_index)
  end

  -- Declare fields.
  for i = 0, cf.fields.length - 1 do
    local f = cf.fields.elements[i]
    local name = member_name(f)
    local desc = getclassname(cf, f.descriptor_index)
    local typ = declare.type(desc)
    local static = f.access_flags:is_static()
    declare.field(T, static, typ, name)
  end

  -- Declare methods, including constructors.
  for i = 0, cf.methods.length - 1 do
    local m = cf.methods.elements[i]
    local name = member_name(m)
    if name ~= "<clinit>" then -- Skip class initializers.
      local desc = getclassname(cf, m.descriptor_index)
      local static = m.access_flags:is_static()
      local params, ret = parse_sig(desc)
      for i = 1, #params do
        params[i] = symbol(params[i], "arg" .. i - 1)
      end
      if not static then
        table.insert(params, 1, symbol(T, "self"))
      end
      declare.method(T, ret, name, params)
    end
  end

end


local P = {}

-- Reflects on a class by fully qualified name.
function P.class(name)
  -- Visit the inheritence DAG, returning the root.
  local T = visit_class(name)
  -- While there are newly encountered classes, reflect their members.
  while #todo > 0 do
    local cf, T = unpack(table.remove(todo))
    visit_members(cf, T)
    cf:free()
  end
  return T
end

-- Creates a table with a namespace to implicit prefix reflected entries.
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
