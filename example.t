local J = require "terra-java"
local C = terralib.includec("stdio.h")

local lang = J.package("java.lang")
local Math = lang.Math

terra pi()
  J.embedded()
  return Math.static():toRadians(180)
end

print(pi())


local util = J.package("java.util")

terra minute()
  J.embedded()
  var now = J.new(util.Date)
  return now:getMinutes()
end

print(minute())


local Object = J.class("example.Foo")
local Foo = J.class("example.Foo")

J.implement(Foo, lang.Object, {

  [[
    static {
      System.loadLibrary("example");
    }

    public static void main(String[] args) {
       Foo foo = new Foo();
       System.out.println(foo.square(Integer.parseInt(args[1])));
       System.out.println(foo.square(Integer.parseInt(args[2])));
    }
  ]],

  square = terra(self : Foo, x : J.int)
    return x * x
  end,

  stored = J.int,

  addStored = terra(self : &Foo, x : J.int)
    return self:stored() + x
  end

})
