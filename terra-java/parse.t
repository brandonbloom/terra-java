-- Parses Java class files.
-- Spec: https://docs.oracle.com/javase/specs/jvms/se7/html/jvms-4.html

local C = require "terra-java/c"
local util = require "terra-java/util"

local struct Header {
  magic : uint32;
  major_version : uint16;
  minor_version : uint16;
}

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

local struct UTF8 {
  length : uint16;
  bytes : &uint8;
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

local file = global(&C.FILE)

local terra read(x : &uint8) : {}
  var nr = C.fread(x, sizeof(uint8), 1, file)
  if nr ~= 1 then
    util.fatal("Error reading: %d", C.ferror(file))
  end
end

for _, T in ipairs({uint16, int16, uint32, int32, uint64, int64}) do
  terra read(x : &T) : {}
    for i = sizeof(T) - 1, -1, -1 do
      read([&uint8]([&uint8](x) + i))
    end
  end
end

for _, T in ipairs({Header, Class, Member, NameAndType, String,
                    MethodHandle, MethodType, InvokeDynamic}) do
  local x = symbol()
  local stmts = T.entries:map(function(e)
    return `read(&x.[e.field])
  end)
  terra read([x] : &T) : {}
    [stmts]
  end
end

local terra decode()

  file = C.fopen("./Foo.class", "rb")
  defer C.fclose(file)

  var hdr : Header
  read(&hdr)

  C.printf("Header: %x %d %d\n",
    hdr.magic,
    hdr.major_version,
    hdr.minor_version)

  var nconst : uint16
  read(&nconst)
  var constants = [&Constant](C.calloc(nconst, sizeof(Constant)))

  -- See Table 4.4. The Constant Pool.
  for i = 0, nconst do
    var const = &constants[i]
    var tag : uint8
    read(&tag)
    C.printf("const %d has tag %d\n", i, tag)

    -- Class
    if tag == 7 then
      read(&const.class)

    -- Fieldref, MethodRef, InterfaceMethodRef
    elseif tag == 9 or tag == 10 or tag == 11 then
      read(&const.member)

    -- String
    elseif tag == 8 then
      read(&const.string)

    -- Integer, Float
    elseif tag == 3 or tag == 4 then
      read(&const.i32)

    -- Long, Double
    elseif tag == 5 or tag == 6 then
      read(&const.i64)

    -- NameAndType
    elseif tag == 12 then
      read(&const.name_and_type)

    -- Utf8
    elseif tag == 1 then
      var nchar : uint16
      read(&nchar)
      const.utf8.length = nchar
      const.utf8.bytes = [&uint8](C.malloc(nchar))
      for c = 0, nchar do
        read(&const.utf8.bytes[c])
      end

    -- MethodHandle
    elseif tag == 15 then
      read(&const.handle)

    -- MethodType
    elseif tag == 16 then
      read(&const.type)

    -- InvokeDynamic
    elseif tag == 18 then
      read(&const.invoke_dynamic)

    -- Unknown
    else
      util.fatal("unknown tag: %d", tag) --TODO return error

    end
  end

  --XXX free utf8 bytes and the constants table

end

decode()
