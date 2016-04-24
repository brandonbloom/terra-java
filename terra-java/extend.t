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

  -- XXX: accumulate terra functions from methods on class objects in pkg

  return exports

end

function P.savelib(dirname, package)
  local exports = P.exports(package)
  local name = "BLAH" --XXX get from package
  local filename = dirname .. "/" .. name .. ".jnilib"
  terralib.saveobj(filename, "sharedlibrary", exports)
end

return P
