local C = require "c"
local J = require "j"
local JVM = require "jvm"
local jtypes = require "types"
local util = require "util"

local ENV = JVM.ENV
local inits = {}

local function pushinit(q)
  if not inits then
    error "Cannot declare JNI element after initialization"
  end
  table.insert(inits, q)
end

local P = {}

P.class = terralib.memoize(function(name)

  local struct T {
    _obj : JVM.Object;
  }

  T.metamethods.__typename = function(self)
    return name
  end

  local java_name = name:gsub("/", ".")
  local jvm_name = "L" .. name .. ";"
  jtypes.register(java_name, jvm_name, T)

  local clazz = global(J.class)
  pushinit(quote
    clazz = ENV:FindClass(name)
    if clazz == nil then
      util.fatal(["Class not found: " .. name])
    end
  end)

  -- These special methods are all reserved words in Java, so it's OK :-)

  T.methods.this = terra(env : JVM.Env, this : J.object)
    return T{JVM.Object{env = env, this = this}}
  end

  T.methods.static = terra(env : JVM.Env) : T
    return T{JVM.Object{env = env, this = nil}}
  end

  -- Like the ".class" syntax in Java, but with parens.
  T.methods.class = terra()
    return clazz
  end

  T.metamethods.__cast = function(from, to, expr)
    if to == J.object then
      return `expr._obj.this
    end
    --TODO: Allow up casts.
    util.errorf("Unable to cast %s", name)
  end

  return T

end)

local convert = macro(function(T, expr)
  if jtypes.primitive(T) then
    return expr
  end
  return `T.this(ENV, expr)
end)

P.method = terralib.memoize(function(T, ret, name, params)

  local static = (#params == 0 or params[1].displayname ~= "self")
  local self = static and symbol(T, "self") or params[1]
  local target = static and (`JVM.Object{[ENV], T.class()}) or (`self._obj)
  params = static and params or util.popl(params)
  local sig = jtypes.jvm_sig(ret, params)
  local modifier = static and "Static" or ""
  local get = "Get" .. modifier .. "MethodID"
  local call = "Call" .. modifier .. jtypes.jni_name(ret) .. "Method"

  local mid = global(J.methodID)
  pushinit(quote
    mid = ENV:[get](T.class(), name, sig)
    if mid == nil then
      util.fatal([("Method not found: %s.%s%s"):format(T, name, sig)])
    end
  end)

  local args = terralib.newlist(params):map(function(param)
    local cast = jtypes.jni_type(param.type)
    return `[cast](param)
  end)

  print("??", ret)
  T.methods[name] = terra([self], [params]) : ret
    var [ENV] = self._obj.env
    return convert(ret, target:[call](mid, [args]))
  end

end)

P.Array = terralib.memoize(function(T)

  local struct A {
    _obj : JVM.Object;
  }

  A.metamethods.__typename = function(self)
    return "Array(" .. tostring(T) .. ")"
  end

  local java_name = jtypes.java_name(T) .. "[]"
  local jvm_name = "[" .. jtypes.jvm_name(T)
  jtypes.register(java_name, jvm_name, A)

  A.methods.this = terra(env : JVM.Env, this : J.object)
    return A{JVM.Object{env = env, this = this}}
  end

  -- TODO array construction
  -- jarray (JNICALL *NewObjectArray)
  --   (JNIEnv *env, jsize len, jclass clazz, jobject init);

  A.methods.len = terra(self : A) : J.int
    return self._obj:GetArrayLength()
  end

  local jnitype = jtypes.jni_name(T)

  A.methods.get = terra(self : A, i : J.int) : T
    var [ENV] = self._obj.env
    return convert(T, self._obj:["Get" .. jnitype .. "ArrayElement"](i))
  end

  A.methods.set = terra(self : A, i : J.int, v : T)
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

--XXX declare_init T.methods.new = ...

--TODO: export JNI_OnLoad when compiling a jnilib, call this.
function P.makeinit()
  local statements = inits
  inits = nil
  return terra()
    var [ENV] = JVM.init()
    [statements]
    return ENV
  end
end

return P
