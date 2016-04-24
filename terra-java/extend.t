-- This file generates JNI extension libraries from Terra methods.

local jni = require "terra-java/jni"
local jvm = require "terra-java/jvm"
local util = require "terra-java/util"
local declare = require "terra-java/declare"

local ENV = declare.ENV

local P = {}

function P.exports(package)

  local exports = {}

  terra exports.JNI_OnLoad(vm : &jni.VM, reserved : &opaque)
    var [ENV]
    var vm = jvm.VM{vm}
    var res = vm:GetEnv([&&opaque](&[ENV].jni), jvm.version)
    if res < 0 then
      util.fatal("Error getting JVM during extension load: %d", res)
    end
    [declare.used_inits()]
    return jvm.version
  end

  local pkg = getmetatable(package).name
  for cls, T in pairs(package) do
    print(cls, T)
    for name, method in pairs(T.methods) do

      -- Un-overload single-signature methods.
      if terralib.type(method) == "overloadedterrafunction" then
        local defs = method:getdefinitions()
        if #defs == 1 then
          method = defs[1]
        end
      end

      -- Export each overload.
      if terralib.type(method) == "overloadedterrafunction" then
        for _, def in ipairs(method:getdefinitions()) do
          print("", name, def:gettype()) --XXX export
        end

      -- Export the only overload.
      elseif terralib.type(method) == "terrafunction" then
        print("", name) --XXX export

      else
        error("Unexpected type of method: " .. terralib.type(method))
      end

    end
  end

  return exports

end

function P.savelib(dirname, name, package)
  local exports = P.exports(package)
  local filename = dirname .. "/lib" .. name .. ".jnilib"
  terralib.saveobj(filename, "sharedlibrary", exports)
end

return P
