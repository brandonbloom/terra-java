local util = require "util"
local jni = require "jni"
local ffi = require "ffi"

local P = {}

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

local ENV = symbol("env")

P.ENV = ENV
P.Env = Env
P.Object = Object

terra P.init() : Env

  var args : jni.VMInitArgs
  var options : jni.VMOption[0]
  args.version = jni.VERSION_1_6
  args.options = options
  args.nOptions = 0
  var res = jni.GetDefaultJavaVMInitArgs(&args)
  if res < 0 then
    util.fatal("error getting default JVM initialization arguments: %d", res)
  end

  var jvm : &jni.VM
  var env : &jni.Env
  res = jni.CreateJavaVM(&jvm, [&&opaque](&env), &args)
  if res < 0 then
    util.fatal("error creating JVM: %d", res)
  end

  return Env{env}

end

return P
