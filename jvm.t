local util = require "util"
local C = require "c"
local J = require "j"
local jtypes = require "types"

local P = {}

local struct Env {
  jenv : &J.Env;
}

local struct Object {
  env : Env;
  this : J.object;
}

Env.metamethods.__methodmissing = macro(function(name, self, ...)
  local args = terralib.newlist({...})
  return `(@self.jenv).[name](self.jenv, [args])
end)

Object.metamethods.__methodmissing = macro(function(name, self, ...)
  local args = {...}
  return `self.env:[name](self.this, [args])
end)

local ENV = symbol("env")

P.ENV = ENV
P.Env = Env
P.Object = Object

--XXX duplicate in declare -- fix up
local convert = macro(function(T, expr)
  if jtypes.primitive(T) then
    return expr
  end
  return `T.this(ENV, expr)
end)

P.Array = terralib.memoize(function(T)

  local struct A {
    _obj : Object;
  }

  A.metamethods.__typename = function(self)
    return "Array(" .. tostring(T) .. ")"
  end

  local java_name = jtypes.java_name(T) .. "[]"
  local jvm_name = "[" .. jtypes.jvm_name(T)
  jtypes.register(java_name, jvm_name, A)

  A.methods.this = terra(env : Env, this : J.object)
    return A{Object{env = env, this = this}}
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


terra P.init() : Env

  var args : J.VMInitArgs
  var options : J.VMOption[0]
  args.version = J.VERSION_1_6
  args.options = options
  args.nOptions = 0
  var res = J.GetDefaultJavaVMInitArgs(&args)
  if res < 0 then
    util.fatal("error getting default JVM initialization arguments: %d", res)
  end

  var jvm : &J.VM
  var env : &J.Env
  res = J.CreateJavaVM(&jvm, [&&opaque](&env), &args)
  if res < 0 then
    util.fatal("error creating JVM: %d", res)
  end

  return Env{env}

end

return P
