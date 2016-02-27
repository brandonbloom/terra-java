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

  local struct Class {
    _obj : JVM.Object;
  }

  jtypes.register(name, Class)

  local clazz = global(J.class)
  pushinit(quote
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
    if to == J.object then
      return `expr._obj.this
    end
    if from == J.object then
      return `Class{JVM.Object{env = ENV, this = expr}}
    end
    util.errorf("Unable to cast to or from %s", name)
  end

  return Class

end)

P.method = terralib.memoize(function(Class, ret, name, params)

  local static = (#params == 0 or params[1].displayname ~= "self")
  local self = static and symbol(Class, "self") or params[1]
  local target = static and (`JVM.Class{[ENV], Class.class()}) or `self
  params = static and params or util.popl(params)
  local sig = jtypes.jvm_sig(ret, params)
  local modifier = static and "Static" or ""
  local get = "Get" .. modifier .. "MethodID"
  local call = "Call" .. modifier .. jtypes.jni_name(ret) .. "Method"

  local mid = global(J.methodID)
  pushinit(quote
    mid = ENV:[get](Class.class(), name, sig)
    if mid == nil then
      util.fatal([("Method not found: %s.%s%s"):format(Class, name, sig)])
    end
  end)

  local args = terralib.newlist(params):map(function(param)
    local cast = jtypes.jni_type(param.type)
    return `[cast](param)
  end)

  Class.methods[name] = terra([self], [params]) : ret
    var [ENV] = self._obj.env
    return [ret](target:[call](mid, [args]))
  end

end)

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
