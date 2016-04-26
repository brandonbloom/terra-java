-- This package provides the same notational conveniences that jni.h provides
-- to C++ programs. For example, Env and Object can be used in an OOP-style.
-- Also provided is the embedded JVM for metaprogramming and scripting use.

local ffi = require "ffi"
local util = require "terra-java/util"
local jni = require "terra-java/jni"
local C = require "terra-java/c"

local struct VM {
  vm : &jni.VM;
}

local struct Env {
  env : &jni.Env;
}

local struct Object {
  env : Env;
  this : jni.object;
}

VM.metamethods.__methodmissing = macro(function(name, self, ...)
  local args = {...}
  return `(@self.vm).[name](self.vm, [args])
end)

Env.metamethods.__methodmissing = macro(function(name, self, ...)
  local args = {...}
  return `(@self.env).[name](self.env, [args])
end)

Object.metamethods.__methodmissing = macro(function(name, self, ...)
  local args = {...}
  return `self.env:[name](self.this, [args])
end)

-- Compute CLASS_PATH for Terra-Java classes.
local rel = "/terra-java/jvm.t"
local here = package.searchpath("terra-java/jvm", package.terrapath)
local obj = here:sub(1, #here - #rel) .. "/obj"
local classpath = "-Djava.class.path=" .. obj
local libpath = "-Djava.library.path=" .. obj

local version = jni.VERSION_1_6

local terra init() : Env

  var args : jni.VMInitArgs
  args.version = version
  args.nOptions = 2
  var optsSize = sizeof(jni.VMOption) * args.nOptions
  args.options = [&jni.VMOption](C.malloc(optsSize))
  defer C.free(args.options)
  args.options[0].optionString = classpath
  args.options[1].optionString = libpath

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

local ENV = symbol(Env, "env")

return {
  version = version,
  VM = VM,
  Env = Env,
  ENV = ENV,
  Object = Object,
  env = init()
}
