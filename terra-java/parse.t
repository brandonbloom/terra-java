-- Parses Java class files.
-- Spec: https://docs.oracle.com/javase/specs/jvms/se7/html/jvms-4.html

local C = require "terra-java/c"
local util = require "terra-java/util"

local file = global(&C.FILE)

local read = terralib.overloadedfunction("read")
local free = terralib.overloadedfunction("free")

read:adddefinition(terra(x : &uint8) : {}
  var nr = C.fread(x, sizeof(uint8), 1, file)
  if nr ~= 1 then
    util.fatal("Error reading: %d", C.ferror(file))
  end
end)

free:adddefinition(terra(x : &uint8) : {}
  -- nop
end)

for _, T in ipairs({uint16, int16, uint32, int32, uint64, int64}) do
  read:adddefinition(terra(x : &T) : {}
    for i = sizeof(T) - 1, -1, -1 do
      read([&uint8](x) + i)
    end
  end)
  free:adddefinition(terra(x : &T) : {}
    -- nop
  end)
end

local VarArr = terralib.memoize(function(N, T)
  local A = struct {
    length : N;
    elements : &T;
  }
  read:adddefinition(terra(x : &A) : {}
    read(&x.length)
    x.elements = [&T](C.malloc(x.length))
    for i = 0, x.length do
      read(&x.elements[i])
    end
  end)
  free:adddefinition(terra(x : &A) : {}
    for i = 0, x.length do
      free(&x.elements[i])
    end
    C.free(x.elements)
  end)
  return A
end)

local UTF8 = VarArr(uint16, uint8)

local function defread(T)
  local x = symbol(&T)
  local read_stmts = T.entries:map(function(e)
    return `read(&x.[e.field])
  end)
  local free_stmts = T.entries:map(function(e)
    return `free(&x.[e.field])
  end)
  read:adddefinition(terra([x]) : {}
    [read_stmts]
  end)
  free:adddefinition(terra([x]) : {}
    var [x] = x
    [free_stmts]
  end)
end

local struct Class {
  name_index : uint16;
}

local struct Member {
  class_index : uint16;
  name_and_type_index : uint16;
}

local struct NameAndType {
  name_index : uint16;
  descriptor_index : uint16;
}

local struct String {
  utf8_index : uint16;
}

local struct MethodHandle {
  reference_kind : uint8;
  reference_index : uint16;
}

local struct MethodType {
  descriptor_index : uint16;
}

local struct InvokeDynamic {
  bootstrap_method_attr_index : uint16;
  name_and_type_index : uint16;
}

local struct Attribute {
  name_index : uint16;
  info : VarArr(uint32, uint8);
}

for _, T in ipairs({Class, Member, NameAndType, String,
                    MethodHandle, MethodType, InvokeDynamic, Attribute}) do
  defread(T)
end

local struct Field {
  access_flags : uint16;
  name_index : uint16;
  descriptor_index : uint16;
  attributes : VarArr(uint16, Attribute);
}
defread(Field)

local struct Method {
  access_flags : uint16;
  name_index : uint16;
  descriptor_index : uint16;
  attributes : VarArr(uint16, Attribute);
}
defread(Method)

local struct Constant {
  tag : uint8;
  union {
    class : Class;
    member : Member;
    i32 : int32;
    i64 : int64;
    f32 : float;
    f64 : double;
    name_and_type : NameAndType;
    string : String;
    utf8 : UTF8;
    handle : MethodHandle;
    type : MethodType;
    invoke_dynamic : InvokeDynamic;
  }
}

local struct ConstantTable {
  length : uint16;
  elements : &Constant;
}

read:adddefinition(terra(x : &ConstantTable) : {}

  read(&x.length)
  x.length = x.length - 1
  x.elements = [&Constant](C.calloc(x.length, sizeof(Constant)))
  C.printf("num consts = %d\n", x.length)

  -- See Table 4.4. The Constant Pool.
  for i = 0, x.length do
    var k = &x.elements[i]
    read(&k.tag)
    C.printf("const %d has tag %d\n", i, k.tag)

    if k.tag == 1 then read(&k.utf8)
    elseif k.tag == 3 or k.tag == 4 then read(&k.i32) -- Also Float
    elseif k.tag == 5 or k.tag == 6 then
      read(&k.i64) -- Also Double
      i = i + 1 -- Section 4.4.5 - "a poor choice".
    elseif k.tag == 7 then read(&k.class)
    elseif k.tag == 8 then read(&k.string)
    elseif k.tag == 9 or k.tag == 10 or k.tag == 11 then read(&k.member)
    elseif k.tag == 12 then read(&k.name_and_type)
    elseif k.tag == 15 then read(&k.handle)
    elseif k.tag == 16 then read(&k.type)
    elseif k.tag == 18 then read(&k.invoke_dynamic)
    else util.fatal("unknown tag: %d", k.tag) --TODO return error
    end
  end

end)

free:adddefinition(terra(x : &ConstantTable) : {}
  for i = 0, x.length do
    var const = x.elements[i]
    if const.tag == 1 then
      free(&const.utf8)
    end
  end
  C.free(x.elements)
end)

local struct ClassFile {
  magic : uint32;
  minor_version : uint16;
  major_version : uint16;
  constants : ConstantTable;
  access_flags : uint16;
  this_class : uint16;
  super_class : uint16;
  interfaces : VarArr(uint16, uint16);
  fields : VarArr(uint16, Field);
  methods : VarArr(uint16, Method);
  attributes : VarArr(uint16, Attribute);
}
defread(ClassFile)

terra ClassFile:free()
  free(self)
end


local terra decode()

  file = C.fopen("./Foo.class", "rb")
  defer C.fclose(file)

  var cls : ClassFile
  read(&cls)

  return cls

end

local cls = decode()
cls:free()
