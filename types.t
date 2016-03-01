local util = require "util"
local jni = require "jni"

local P = {}

local java_names = {}
java_names[jni.void] = "void"
java_names[jni.boolean] = "boolean"
java_names[jni.byte] = "byte"
java_names[jni.char] = "char"
java_names[jni.short] = "short"
java_names[jni.int] = "int"
java_names[jni.long] = "long"
java_names[jni.float] = "float"
java_names[jni.double] = "double"
java_names[jni.object] = "Object"

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
jvm_names[jni.void] = "V"
jvm_names[jni.boolean] = "Z"
jvm_names[jni.byte] = "B"
jvm_names[jni.char] = "C"
jvm_names[jni.short] = "S"
jvm_names[jni.int] = "I"
jvm_names[jni.long] = "J"
jvm_names[jni.float] = "F"
jvm_names[jni.double] = "D"
jvm_names[jni.object] = "LObject;"

P.jvm_primitives = {
  Z = jni.boolean,
  B = jni.byte,
  C = jni.char,
  S = jni.short,
  I = jni.int,
  J = jni.long,
  F = jni.float,
  D = jni.double
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
  if typ == jni.void then return "Void" end
  if typ == jni.boolean then return "Boolean" end
  if typ == jni.byte then return "Byte" end
  if typ == jni.char then return "Char" end
  if typ == jni.short then return "Short" end
  if typ == jni.int then return "Int" end
  if typ == jni.long then return "Long" end
  if typ == jni.float then return "Float" end
  if typ == jni.double then return "Double" end
  return "Object"
end

P.java_primitives = {
  boolean = jni.boolean,
  byte = jni.byte,
  char = jni.char,
  short = jni.short,
  int = jni.int,
  long = jni.long,
  float = jni.float,
  double = jni.double
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
  return jni.object
end

function P.register(java_name, jvm_name, typ)
  java_names[typ] = java_name
  jvm_names[typ] = jvm_name
end

return P
