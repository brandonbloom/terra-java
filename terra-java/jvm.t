local ffi = require "ffi"
local util = require "terra-java/util"
local jni = require "terra-java/jni"
local C = require "terra-java/c"

local struct Env {
  jni : &jni.Env;
}

local struct Object {
  env : Env;
  this : jni.object;
}

Env.metamethods.__methodmissing = macro(function(name, self, ...)
  local args = terralib.newlist({...})
  return `(@self.jni).[name](self.jni, [args])
end)

Object.metamethods.__methodmissing = macro(function(name, self, ...)
  local args = {...}
  return `self.env:[name](self.this, [args])
end)

local terra init() : Env

  var args : jni.VMInitArgs
  args.version = jni.VERSION_1_6
  args.nOptions = 1
  var optsSize = sizeof(jni.VMOption) * args.nOptions
  args.options = [&jni.VMOption](C.malloc(optsSize))
  defer C.free(args.options)
  args.options[0].optionString = "-Djava.class.path=./obj" --XXX absolute path.

  var res = jni.GetDefaultJavaVMInitArgs(&args)
  if res < 0 then
    util.fatal("error getting default JVM initialization arguments: %d", res)
  end

  var vm : &jni.VM
  var env : &jni.Env
  res = jni.CreateJavaVM(&vm, [&&opaque](&env), &args)
  if res < 0 then
    util.fatal("error creating JVM: %d", res)
  end

  return Env{env}

end

return {
  Env = Env,
  Object = Object,
  env = init()
}
