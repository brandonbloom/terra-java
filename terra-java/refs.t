
XXX Implicit conversion from Ref(T) to T

local P = {}

P.retain = macro(function(x)
  ref = NewGlobalRef(ENV, x)
end)

P.release = macro(function(x)
  if TYPEOF x IS A ref then
    Use ENV to DeleteGlobalRef
  else
    x._obj:DeleteLocalRef()
  end
end)

return P
