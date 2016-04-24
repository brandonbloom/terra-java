local util = require "terra-java/util"
local declare = require "terra-java/declare"


--XXX: use me by exporting JNI_OnLoad when compiling a jnilib
local function fullinit()
  return terra()
    var [ENV] = jvm.env
    [xs]
  end
end
