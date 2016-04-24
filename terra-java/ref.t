-- This file implements a generic type for JNI global references.

local jni = require "terra-java/jni"
local declare = require "terra-java/declare"

local ENV = declare.ENV

local Ref = terralib.memoize(function(T)

  local struct R {
    _obj : jni.object;
  }

  R.metamethods.isglobalref = true

  local name = "Ref(" .. tostring(T) .. ")"

  R.metamethods.__typename = function(self)
    return name
  end

  function R.metamethods.__cast(from, to, expr)
    if to == T then
      return `T:this(expr._obj)
    end
    error("unable to cast " .. name)
  end

  R.metamethods.__methodmissing = macro(function(name, self, ...)
    local args = {...}
    return `T:this(self._obj):[name](args)
  end)

end)

local P = {}

P.Ref = Ref

P.retain = macro(function(x)
  local T = x:gettype()
  return `Ref(T){ _obj = ENV:NewGlobalRef(x) }
end)

P.release = macro(function(x)
  local typ = x:gettype()
  if typ.isglobalref then
    return `ENV:DeleteGlobalRef(x._obj)
  else
    return `x._obj:DeleteLocalRef()
  end
end)

return P
