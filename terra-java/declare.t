local C = require "terra-java/c"
local jni = require "terra-java/jni"
local jvm = require "terra-java/jvm"
local jtypes = require "terra-java/types"
local util = require "terra-java/util"

local P = {}

local ENV = symbol(jvm.Env, "env")
P.ENV = ENV

local inits = {}

-- Returns q, but immediately executes it with the embedded JVM implicit.
local function initq(q)
  (terra()
    var [ENV] = jvm.env
    [q]
  end)()
  return q
end

-- Returns a sequence of all initialization statements for a given class.
local function collectinits(dst, src)
  table.insert(dst, src.class)
  for _, v in pairs(src.members) do
    table.insert(dst, v)
  end
end

local notinherited = {}
notinherited["<init>"] = true
--XXX Eliminate these, just make them J.class, J.static, and J.this
--XXX maybe they can just be metamethods?
notinherited["class"] = true
notinherited["static"] = true
notinherited["this"] = true

local cache = {}
function P.reset()
  cache = {}
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
  inits[T] = {
    class = initq(quote
      clazz = ENV:FindClass(jni_name)
      if clazz == nil then
        util.fatal(["Class not found: " .. name])
      end
    end),
    members = {},
  }

  -- These special methods are all reserved words in Java, so it's OK :-)

  T.methods.this = macro(function(this)
    return `T{jvm.Object{env = ENV, this = this}}
  end)

  T.methods.static = macro(function()
    return `T{jvm.Object{env = ENV, this = nil}}
  end)

  -- Like the ".class" syntax in Java, but with parens.
  T.methods.class = terra()
    return clazz
  end

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
    --TODO: Handle nil?
    util.errorf("Unable to cast %s", name)
  end

  function T.metamethods.__getmethod(self, methodname)
    if notinherited[methodname] then
      return T.methods[methodname]
    end
    -- Walk the super chain from the root to aggregate all method overloads.
    --TODO: Omit overridden overloads.
    local ofn = terralib.overloadedfunction(methodname)
    for _, super in ipairs(chain) do
      local basemethod = super.methods[methodname]
      if basemethod then
        for _, def in ipairs(basemethod:getdefinitions()) do
          ofn:adddefinition(def)
        end
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

local convert = macro(function(T, expr)
  if jtypes.primitive(T:astype()) then
    return expr
  end
  return `T.this(expr)
end)

function P.method(T, ret, name, params)

  local ctor = (name == "<init>")
  local static = (#params == 0 or params[1].displayname ~= "self")
  local self = static and symbol(T, "self") or params[1]
  local target = (ctor or static)
                 and (`jvm.Object{[ENV], T.class()}) or (`self._obj)
  params = static and params or util.popl(params)
  local sig = jtypes.jvm_sig(ret, params)
  local modifier = static and "Static" or ""
  local find = "Get" .. modifier .. "MethodID"
  local call = ctor and "NewObject"
               or "Call" .. modifier .. jtypes.jni_name(ret) .. "Method"

  -- Record an initialization statement for a method ID.
  local mid = global(jni.methodID)
  inits[T].members[name .. sig] = initq(quote
    mid = ENV:[find](T.class(), name, sig)
    if mid == nil then
      util.fatal([
        ("Method not found: %s %s.%s%s\n"):format(T, modifier, name, sig)
      ])
    end
  end)

  local args = terralib.newlist(params):map(function(param)
    local cast = jtypes.jni_type(param.type)
    return `[cast](param)
  end)

  if ctor then
    name = "new"
    ret = T
  end

  local fn = terra([self], [params]) : ret
    var [ENV] = self._obj.env
    return convert(ret, target:[call](mid, [args]))
  end

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

  -- Record an initialization statement for a field ID.
  local fid = global(jni.fieldID)
  inits[T].members[name .. " " .. sig] = initq(quote
    fid = ENV:[find](T.class(), name, sig)
    if fid == nil then
      util.fatal([
        ("Field not found: %s %s.%s%s\n"):format(T, modifier, name, sig)
      ])
    end
  end)

  -- Define accessor methods.
  T.methods[name] = terralib.overloadedfunction(name)
  T.methods[name]:adddefinition(terra(self : T)
    return self._obj:[get](fid)
  end)
  T.methods[name]:adddefinition(terra(self : T, value : typ)
    self._obj:[set](fid, value)
  end)

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
      return convert(T, self._obj:GetObjectArrayElement(i))
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

--XXX: use me by exporting JNI_OnLoad when compiling a jnilib
function allinits()
  local xs = {}
  for _, v in pairs(inits) do
    collectinits(xs, v)
  end
  return terra()
    var [ENV] = jvm.env
    [xs]
  end
end

P.embedded = macro(function()
  return quote var [ENV] = jvm.env end
end)

P.new = macro(function(class, ...)
  local args = {...}
  return `class.static():new(args)
end)

return P
