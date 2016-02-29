local util = require "util"
local J = require "j"

local P = {}

local java_names = {}
java_names[J.boolean] = "boolean"
java_names[J.byte] = "byte"
java_names[J.char] = "char"
java_names[J.short] = "short"
java_names[J.int] = "int"
java_names[J.long] = "long"
java_names[J.float] = "float"
java_names[J.double] = "double"
java_names[J.object] = "Object"

function P.java_name(typ)
  if not typ then
    return "void"
  end
  local ret = java_names[typ]
  if not ret then
    util.errorf("cannot map %s to Java type", typ)
  end
  return ret
end

function P.java_sig(params)
  local sig = ""
  local sep = ""
  for i, param in ipairs(params) do
    sig = sig .. sep .. P.java_name(param.type) .. " " .. param.name
    sep = ", "
  end
  return sig
end

local jvm_names = {}
jvm_names[J.boolean] = "Z"
jvm_names[J.byte] = "B"
jvm_names[J.char] = "C"
jvm_names[J.short] = "S"
jvm_names[J.int] = "I"
jvm_names[J.long] = "J"
jvm_names[J.float] = "F"
jvm_names[J.double] = "D"
jvm_names[J.object] = "LObject;"

P.jvm_primitives = {
  Z = J.boolean,
  B = J.byte,
  C = J.char,
  S = J.short,
  I = J.int,
  J = J.long,
  F = J.float,
  D = J.double
}

function P.jvm_name(typ)
  if not typ then
    return "V"
  end
  local ret = jvm_names[typ]
  if not ret then
    util.errorf("cannot map %s to JVM type", typ)
  end
  return ret
end

function P.jvm_sig(ret, params)
  local sig = "("
  for i, sym in ipairs(params) do
    sig = sig .. P.jvm_name(sym.type)
  end
  sig = sig .. ")" .. P.jvm_name(ret)
  return sig
end

function P.jni_name(typ)
  if not typ then return "Void" end
  if typ == J.boolean then return "Boolean" end
  if typ == J.byte then return "Byte" end
  if typ == J.char then return "Char" end
  if typ == J.short then return "Short" end
  if typ == J.int then return "Int" end
  if typ == J.long then return "Long" end
  if typ == J.float then return "Float" end
  if typ == J.double then return "Double" end
  return "Object"
end

P.java_primitives = {
  boolean = J.boolean,
  byte = J.byte,
  char = J.char,
  short = J.short,
  int = J.int,
  long = J.long,
  float = J.float,
  double = J.double
}

function P.primitive(typ)
  for _, T in pairs(P.java_primitives) do
    if typ == T then return true end
  end
  return false
end

function P.jni_type(typ)
  if P.primitive(typ) then
    return typ
  end
  return J.object
end

function P.register(java_name, jvm_name, typ)
  java_names[typ] = java_name
  jvm_names[typ] = jvm_name
end

return P
