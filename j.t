local ffi = require("ffi")

local JDK_HOME = os.getenv("JDK_HOME")
if not JDK_HOME then
  error "JDK_HOME not set"
end

terralib.includepath = terralib.includepath
  .. ";" .. JDK_HOME .. "/include/"

if ffi.os == "OSX" then

  terralib.includepath = terralib.includepath
    .. ";" .. JDK_HOME .. "/include/darwin/"

  terralib.linklibrary(JDK_HOME .. "/jre/lib/server/libjvm.dylib")

end

local J = {}
for k, v in pairs(terralib.includec("jni.h")) do
  -- Ignore private definitions.
  if k:sub(k:len()) == "_" then
    k = nil
  -- Strip prefixes from names.
  elseif k:sub(1, 1) == "j" then
    k = k:sub(2)
  elseif k:sub(1,3) == "JNI" then
    k = k:sub(4)
  elseif k:sub(1, 4) == "Java" then
    k = k:sub(5)
  -- Ignore unprefixed definitions.
  else
    k = nil
  end
  if k then
    -- Strip leading underscores.
    while k:sub(1,1) == "_" do
      k = k:sub(2)
    end
    -- Store in the J table.
    if J[k] then
      error("duplicate key: " .. k)
    end
    J[k] = v
  end
end

-- For completeness.
J.void = terralib.types.unit

return J
