local util = require "util"
local J = require "j"
local ffi = require "ffi"

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
