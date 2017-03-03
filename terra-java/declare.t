-- This file generates wrapper objects and initialization logic in response to
-- declarations of classes, their members, and array types. It also provides
-- macros for static operations on JVM types.

local C = require "terra-java/c"
local jni = require "terra-java/jni"
local jvm = require "terra-java/jvm"
local jtypes = require "terra-java/types"
local util = require "terra-java/util"

local P = {}

local ENV = jvm.ENV

-- A map of objects to init list indexes.
local init_map = {}
-- A list of tables consisting of `q`, a quote of initialization code,
-- and boolean `used`.
local init_list = {}

-- Creates an init object, inserts it in to the list, and returns its index.
local function initq(q)
  local init = {used = false, q = q}
  table.insert(init_list, init)
  return #init_list
end

-- Returns all used init quotes.
function P.used_inits()
  local ret = {}
  for _, init in ipairs(init_list) do
    if init.used then
      table.insert(ret, init.q)
    end
  end
  return ret
end

local pending = {}

-- Marks an init as used and adds it t
local function use_init(key)
  local index = init_map[key]
  if not index then
    return
  end
  local init = init_list[index]
  if init.used then
    return
  end
  init.used = true
  table.insert(pending, init.q)
end

-- Runs all pending inits.
function P.load()
  (terra()
    var [ENV] = jvm.env
    [pending]
  end)()
  pending = {}
end

local cache = {}
local classes = {}
function P.reset()
  init_map = {}
  init_list = {}
  cache = {}
  classes = {}
end

function P.class(name, ...)

  local cached = cache[name]
  if cached then
    return cached
  end

  local struct T {
    _obj : jvm.Object;
  }
  cache[name] = T

  -- Get the bases, defaulting to Object if not are specified.
  local bases = {...}
  if #bases == 0 and name ~= "java.lang.Object" then
    bases = {P.class("java.lang.Object")}
  end

  T.metamethods.__typename = function(self)
    return name
  end

  local jni_name = name:gsub("[.]", "/")
  local jvm_name = "L" .. jni_name .. ";"
  jtypes.register(name, jvm_name, T)

  -- Create an initialization record with a statement to find the
  -- Class and slots for member initialization statements.
  local clazz = global(jni.class)
  init_map[T] = initq(quote
    clazz = ENV:FindClass(jni_name)
    if clazz == nil then
      util.fatal(["Cannot find or error loading class: " .. name])
    end
  end)
  classes[T] = clazz

  -- Always load any mentioned class.
  use_init(T)

  -- Build set of super classes and dispatch chain from top of hierarchy down.
  local chain = {}
  local supers = {}
  for _, base in ipairs(bases) do
    for _, super in ipairs(base.metamethods.chain) do
      if not supers[super] then
        table.insert(chain, super)
        supers[super] = true
      end
    end
  end
  table.insert(chain, T)
  T.metamethods.chain = chain

  function T.metamethods.__cast(from, to, expr)
    -- Allow dropping the JNI Environment.
    if to == jni.object then
      return `expr._obj.this
    end
    -- Allow up-casts.
    if supers[to] then
      return `to{expr._obj}
    end
    -- Allow nil.
    if from == niltype then
      return `to{jvm.Object{[ENV], nil}}
    end
    util.errorf("Unable to cast %s", name)
  end

  function T.metamethods.__getmethod(self, methodname)
    local notinherited = (methodname == "<init>")
    local search = notinherited and {T} or chain
    -- Walk the search chain from the root to aggregate all method overloads.
    --XXX Omit overridden overloads.
    local ofn = terralib.overloadedfunction(methodname)
    for _, super in ipairs(chain) do
      local basemethod = super.methods[methodname]
      -- No init will be found if the method is overridden, which is
      -- expected when defining extensions.
      local defs = {}
      if terralib.type(basemethod) == "overloadedterrafunction" then
        defs = basemethod:getdefinitions()
      elseif terralib.type(basemethod) == "terrafunction" then
        -- While all reflected methods are overloaded,
        -- native extension definitions are not required to be.
        defs = {basemethod}
      end
      for _, def in ipairs(defs) do
        ofn:adddefinition(def)
        -- Mark associated initialization statements as in use.
        -- Native extension definitions don't need an init.
        use_init(def)
      end
    end
    return #ofn:getdefinitions() > 0 and ofn or nil
  end

  return T

end

-- Declares a type with a kind inferred from its name.
P.type = function(name)
  if name:sub(1, 1) == "L" then
    return P.type(name:sub(2, #name - 1))
  end
  if name:sub(1, 1) == "[" then
    return P.Array(P.type(name:sub(2)))
  end
  return jtypes.java_primitives[name]
      or jtypes.jvm_primitives[name]
      or P.class(name)
end

P.wrap = macro(function(T, expr)
  if jtypes.primitive(T:astype()) then
    return expr
  end
  return `P.this(T, expr)
end)

P.unwrap = macro(function(expr)
  if jtypes.primitive(expr:gettype()) then
    return expr
  end
  return `expr._obj.this
end)

function P.method(T, ret, name, params)

  local ctor = (name == "<init>")
  local static = (#params == 0 or params[1].displayname ~= "self")
  local self = static and symbol(T, "self") or params[1]
  local target = (ctor or static)
                 and (`jvm.Object{[ENV], [classes[T]]}) or (`self._obj)
  params = static and params or util.popl(params)
  local param_types = terralib.newlist(params):map(function(param)
    return param.type
  end)
  local sig = jtypes.jvm_sig(ret, param_types)
  local modifier = static and "Static" or ""
  local find = "Get" .. modifier .. "MethodID"
  local call = ctor and "NewObject"
               or "Call" .. modifier .. jtypes.jni_name(ret) .. "Method"

  local args = terralib.newlist(params):map(function(param)
    local cast = jtypes.jni_type(param.type)
    return `[cast](param)
  end)

  if ctor then
    ret = T
  end

  local mid = global(jni.methodID)
  local fn = terra([self], [params]) : ret
    var [ENV] = self._obj.env
    return P.wrap(ret, target:[call](mid, [args]))
  end

  -- Record an initialization statement for a method ID.
  local clazz = classes[T]
  init_map[fn] = initq(quote
    mid = ENV:[find](clazz, name, sig)
    if mid == nil then
      util.fatal([
        ("Method not found in %s: %s%s%s"):format(
          T, modifier == '' and '' or 'static ', name, sig)
      ])
    end
  end)

  if not T.methods[name] then
    T.methods[name] = terralib.overloadedfunction(name)
  end
  T.methods[name]:adddefinition(fn)

end

P.constructor = function(T, params)
  P.method(T, jni.void, "<init>", params)
end

P.field = function(T, static, typ, name)

  local sig = jtypes.jvm_name(typ)
  local modifier = static and "Static" or ""
  local find = "Get" .. modifier .. "FieldID"
  local get = "Get" .. modifier .. jtypes.jni_name(typ) .. "Field"
  local set = "Set" .. modifier .. jtypes.jni_name(typ) .. "Field"

  -- Define accessor methods.
  local fid = global(jni.fieldID)
  local getter = terra(self : T)
    return self._obj:[get](fid)
  end
  local setter = terra(self : T, value : typ)
    self._obj:[set](fid, value)
  end
  T.methods[name] = terralib.overloadedfunction(name, {getter, setter})

  -- Record an initialization statement for a field ID.
  local clazz = classes[T]
  local init = initq(quote
    fid = ENV:[find](clazz, name, sig)
    if fid == nil then
      util.fatal([
        ("%s field not found in %s: %s %s"):format(
          modifier == "" and 'instance' or modifier,
          T, jtypes.java_name(typ), name)
      ])
    end
  end)
  init_map[getter] = init
  init_map[setter] = init

end

--XXX should this be a macro? Ref(T) too?
P.Array = terralib.memoize(function(T)

  local struct A {
    _obj : jvm.Object;
  }

  A.metamethods.__typename = function(self)
    return "Array(" .. tostring(T) .. ")"
  end

  local java_name = jtypes.java_name(T) .. "[]"
  local jvm_name = "[" .. jtypes.jvm_name(T)
  jtypes.register(java_name, jvm_name, A)

  A.methods.this = macro(function(this)
    return `A{jvm.Object{env = ENV, this = this}}
  end)

  -- TODO array construction
  -- jarray (JNICALL *NewObjectArray)
  --   (JNIEnv *env, jsize len, jclass clazz, jobject init);

  A.methods.len = terra(self : A) : jni.int
    return self._obj:GetArrayLength()
  end

  local jnitype = jtypes.jni_name(T)

  if jnitype == "Object" then

    A.methods.get = terra(self : A, i : jni.int) : T
      var [ENV] = self._obj.env
      return P.wrap(T, self._obj:GetObjectArrayElement(i))
    end

    A.methods.set = terra(self : A, i : jni.int, v : T)
      self._obj:SetObjectArrayElement(i, v)
    end

  else

    local struct Pinned {
      _obj : jvm.Object;
      is_copy : jni.boolean;
      len : jni.int;
      elements : &T;
    }

    local retain = "Get" .. jnitype .. "ArrayElements"
    local release = "Release" .. jnitype .. "ArrayElements"

    local releasef = terralib.overloadedfunction("release")
    Pinned.methods.release = releasef
    releasef:adddefinition(terra(self : &Pinned, mode : jni.int)
      self._obj:[release](self.elements, mode)
    end)
    releasef:adddefinition(terra(self : &Pinned)
      self:release(0)
    end)

    terra A:retain() : Pinned
      var ret = Pinned{
        _obj = self._obj,
        len = self:len()
      }
      ret.elements = self._obj:[retain](&ret.is_copy)
      return ret
    end

  end

  A.metamethods.__cast = function(from, to, expr)
    if to == jni.object then
      return `expr._obj.this
    end
    util.errorf("Unable to cast %s", java_name)
  end

  return A

end)

-- Pre-declare primitive array types to fill the types lookup tables.
for name, T in pairs(jtypes.java_primitives) do
  if name ~= "void" then
    P.Array(T)
  end
end

function P.generated(f)
  return init_map[f] ~= nil
end

P.embedded = macro(function()
  return quote var [ENV] = jvm.env end
end)

P.envof = macro(function(x)
  return quote var [ENV] = x._obj.env end
end)

P.null = macro(function(x)
  return `x._obj.this == nil
end)

P.this = macro(function(T, this)
  return `T{jvm.Object{env = ENV, this = this}}
end)

P.static = macro(function(T)
  return `P.this(T, nil)
end)

P.new = macro(function(T, ...)
  local args = {...}
  --XXX Handle T being an array type.
  return `P.static(T):["<init>"](args)
end)

P.getclass = macro(function(T)
  return classes[T]
end)

return P
