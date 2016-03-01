local C = require "terra-java/c"
local jni = require "terra-java/jni"
local jvm = require "terra-java/jvm"
local jtypes = require "terra-java/types"
local util = require "terra-java/util"

local P = {}

local ENV = symbol("env")
P.ENV = ENV

--XXX Eliminate duplicate inits after reflection bootstrap.
local inits = {}

local function pushinit(q)
  -- Execute immediately.
  (terra()
    var [ENV] = jvm.env
    [q]
  end)()
  -- And save for later.
  table.insert(inits, q)
end

P.class = terralib.memoize(function(name)

  local struct T {
    _obj : jvm.Object;
  }

  T.metamethods.__typename = function(self)
    return name
  end

  local jni_name = name:gsub("[.]", "/")
  local jvm_name = "L" .. jni_name .. ";"
  jtypes.register(name, jvm_name, T)

  local clazz = global(jni.class)
  pushinit(quote
    clazz = ENV:FindClass(jni_name)
    if clazz == nil then
      util.fatal(["Class not found: " .. name])
    end
  end)

  -- These special methods are all reserved words in Java, so it's OK :-)

  T.methods.this = macro(function(this)
    return `T{jvm.Object{env = ENV, this = this}}
  end)

  T.methods.static = macro(function()
    return `T{jvm.Object{env = ENV, this = nil}}
  end)

  -- Like the ".class" syntax in Java, but with parens.
  T.methods.class = terra()
    return clazz
  end

  T.metamethods.__cast = function(from, to, expr)
    if to == jni.object then
      return `expr._obj.this
    end
    --TODO: Allow up casts.
    util.errorf("Unable to cast %s", name)
  end

  return T

end)

-- Declares a type with a kind inferred from its name.
P.type = function(name)
  if name:sub(1, 1) == "L" then
    return P.type(name:sub(2, #name - 1))
  end
  if name:sub(1, 1) == "[" then
    return P.Array(P.type(name:sub(2)))
  end
  return jtypes.java_primitives[name]
      or jtypes.jvm_primitives[name]
      or P.class(name)
end

local convert = macro(function(T, expr)
  if jtypes.primitive(T:astype()) then
    return expr
  end
  return `T.this(expr)
end)

function P.method(T, ret, name, params)

  local static = (#params == 0 or params[1].displayname ~= "self")
  local self = static and symbol(T, "self") or params[1]
  local target = static and (`jvm.Object{[ENV], T.class()}) or (`self._obj)
  params = static and params or util.popl(params)
  local sig = jtypes.jvm_sig(ret, params)
  local modifier = static and "Static" or ""
  local find = "Get" .. modifier .. "MethodID"
  local call = "Call" .. modifier .. jtypes.jni_name(ret) .. "Method"

  local mid = global(jni.methodID)
  pushinit(quote
    mid = ENV:[find](T.class(), name, sig)
    if mid == nil then
      util.fatal([
        ("Method not found: %s %s.%s%s\n"):format(T, modifier, name, sig)
      ])
    end
  end)

  local args = terralib.newlist(params):map(function(param)
    local cast = jtypes.jni_type(param.type)
    return `[cast](param)
  end)

  local fn = terra([self], [params]) : ret
    var [ENV] = self._obj.env
    return convert(ret, target:[call](mid, [args]))
  end

  if T.methods[name] then
    T.methods[name]:adddefinition(fn)
  else
    T.methods[name] = fn
  end

end

P.methods = function(T, sigs)
  for _, sig in ipairs(sigs) do
    P.method(T, unpack(sig))
  end
end

P.constructor = function(T, params)
  P.method(T, jni.void, "<init>", params)
  --XXX create a T.new(...) method
end

P.field = function(T, static, typ, name)

  local sig = jtypes.jvm_name(typ)
  local modifier = static and "Static" or ""
  local find = "Get" .. modifier .. "FieldID"
  local get = "Get" .. modifier .. jtypes.jni_name(typ) .. "Field"
  local set = "Set" .. modifier .. jtypes.jni_name(typ) .. "Field"

  local fid = global(jni.fieldID)
  pushinit(quote
    fid = ENV:[find](T.class(), name, sig)
    if fid == nil then
      util.fatal([
        ("Field not found: %s %s.%s%s\n"):format(T, modifier, name, sig)
      ])
    end
  end)

  T.methods[name] = terra(self : T)
    return self._obj:[get](fid)
  end

  T.methods[name]:adddefinition(terra(self : T, value : typ)
    self._obj:[set](fid, value)
  end)

end

P.Array = terralib.memoize(function(T)

  local struct A {
    _obj : jvm.Object;
  }

  A.metamethods.__typename = function(self)
    return "Array(" .. tostring(T) .. ")"
  end

  local java_name = jtypes.java_name(T) .. "[]"
  local jvm_name = "[" .. jtypes.jvm_name(T)
  jtypes.register(java_name, jvm_name, A)

  A.methods.this = macro(function(this)
    return `A{jvm.Object{env = ENV, this = this}}
  end)

  -- TODO array construction
  -- jarray (JNICALL *NewObjectArray)
  --   (JNIEnv *env, jsize len, jclass clazz, jobject init);

  A.methods.len = terra(self : A) : jni.int
    return self._obj:GetArrayLength()
  end

  local jnitype = jtypes.jni_name(T)

  A.methods.get = terra(self : A, i : jni.int) : T
    var [ENV] = self._obj.env
    return convert(T, self._obj:["Get" .. jnitype .. "ArrayElement"](i))
  end

  A.methods.set = terra(self : A, i : jni.int, v : T)
    self._obj:["Set" .. jnitype .. "ArrayElement"](i, v)
  end

  if jtypes.primitive(T) then

    --TODO: A.methods.acquire
    -- NativeType *Get<PrimitiveType>ArrayElements(
    --   JNIEnv *env, ArrayType array, jboolean *isCopy);

    --TODO: A.methods.release
    -- void Release<PrimitiveType>ArrayElements(
    --   JNIEnv *env, ArrayType array, NativeType *elems, jint mode);

  end

  return A

end)

-- Pre-declare primitive array types to fill lookup tables.
for _, T in pairs(jtypes.java_primitives) do
  P.Array(T)
end

--TODO: export JNI_OnLoad when compiling a jnilib, call this.
function P.makeinit()
  return terra()
    var [ENV] = jvm.env
    [inits]
  end
end

P.embedded = macro(function()
  return quote var [ENV] = jvm.env end
end)

return P
