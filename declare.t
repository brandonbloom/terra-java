local J = require "j"
local JVM = require "jvm"
local jtypes = require "types"
local util = require "util"

local ENV = symbol("env")
local inits = {}

local declare_class = terralib.memoize(function(name)

  local struct Class {
    _obj : JVM.Object;
  }

  jtypes.register(name, Class)

  local clazz = global(J.class)
  table.insert(inits, quote
    clazz = ENV:FindClass(name)
    if clazz == nil then
      util.fatal(["Class not found: " .. name])
    end
  end)

  Class.methods.static = terra(env : JVM.Env) : Class
    return Class{JVM.Object{env = env, this = nil}}
  end

  -- Like the ".class" syntax in Java, but with parens.
  Class.methods.class = terra()
    return clazz
  end

  Class.metamethods.__typename = function(self)
    return name
  end

  Class.metamethods.__cast = function(from, to, expr)
    if from == J.object then
      return `Class{JVM.Object{env = ENV, this = expr}}
    end
    util.errorf("Unable to cast to or from %s", name)
  end

  return Class

end)

local declare_method = terralib.memoize(function(Class, ret, name, params)

  local static = (#params == 0 or params[1].displayname ~= "self")
  local self = static and symbol(Class, "self") or params[1]
  local args = static and params or util.popl(params)
  local sig = jtypes.jvm_sig(ret, args)
  local modifier = static and "Static" or ""
  local get = "Get" .. modifier .. "MethodID"
  local call = "Call" .. modifier .. jtypes.jni_name(ret) .. "Method"

  local mid = global(J.methodID)
  table.insert(inits, quote
    mid = ENV:[get](Class.class(), name, sig)
    if mid == nil then
      util.fatal([("Method not found: %s.%s%s"):format(Class, name, sig)])
    end
  end)

  Class.methods[name] = terra([self], [args]) : ret
    var [ENV] = self._obj.env
    return [ret](self._obj:[call](mid, args))
  end

end)

local Runtime = declare_class("java/lang/Runtime")
declare_method(Runtime, Runtime, "getRuntime", {})
declare_method(Runtime, J.long, "maxMemory", {symbol(Runtime, "self")})

local init = terra()
  var [ENV] = JVM.init()
  [inits]
  return ENV
end

local terra blah()
  var env = init()
  print(Runtime.class())
  var rt = Runtime.static(env):getRuntime()
  print(rt:maxMemory())
end

blah()

--TODO: export JNI_OnLoad when compiling a jnilib, call init
