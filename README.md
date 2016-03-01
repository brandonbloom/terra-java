# Terra-Java

Raw JNI too cumbersome? JNA not fast enough? C++ code generators make you sad?

Try Terra-Java!


## Abstract

Terra-Java leverages Terra's metaprogramming facilities to enable you to
define native-code JVM extensions with a familiar and convenient
object-oriented interface to JNI.

JNI wrappers are dynamically generated with the help of an embedded JVM and
java.lang.reflect during Terra compilation. Just as Terra can generate native
code without a runtime Lua dependency, Terra-Java can generate vanilla
object files ready for loading in to your own JVM process.


## Status

This project is a work-in-progress. Nothing really works as advertised yet.


## Getting Started

Try the examples below, then see [the guide](./doc/guide.md).

### Configuration

The following environment variables should be set:

- `INCLUDE_PATH`: Used by Terra to find standard C headers.
- `JDK_HOME`: Terra-Java uses this to find Java headers and libjvm.

### Using the Embedded JVM

```lua
local J = require "terra-java"

local Math = J.package("java.lang").Math

terra pi()
  J.embedded()
  return Math.static():toRadians(180)
end

print(pi())

--TODO: Show more interesting examples.
```

### Building Native Extensions

```lua
local J = require "terra-java"
local C = terralib.includec("stdio.h")

C.printf("hello\n") --TODO: put this in an extension class

--TODO: save an object file
```

```bash
#TODO: run above terra
```
