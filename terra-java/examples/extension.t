local J = require "terra-java"
local C = terralib.includec("stdio.h")

--NOTE: Extensions are very much still a work in progress.

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
