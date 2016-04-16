**WORK IN PROGRESS**

This document is currently more of a goals / design-doc than usage reference.
That is, most of this stuff doesn't work, or doesn't work with this syntax.


# Background

Some familiarity with the [Java Native Interface Specification][1] will be
helpful for many tasks, but should not be required.

Experience with [Lua/Terra][2] and low-level programming is assumed.


# Configuration

The following environment variables should be set:

- `INCLUDE_PATH`: Used by Terra to find standard C headers.
- `TERRA_PATH`: Add to this the root directory of Terra-Java.
- `JDK_HOME`: Terra-Java uses this to find Java headers and libjvm.

Then load Terra-Java like this:

```lua
local J = require "terra-java"
```


# JNI Environments and Terra-Java Objects

All JNI operations require an environment object. Terra-Java wrapper objects
contain references to both an environment and _this_. Methods on a Terra-Java
object will supply the environment automatically.

If a raw JNI object is required, an implicit conversation will extract the
_this_ reference.

For operations not associated with a particular object instance, an
environment is obtained implicitly from the lexical scope. The target
environment must be declared in the terra function.

For metaprogramming and scripting, declare the embedded JVM:

```lua
J.embedded()
```

For callbacks from the JVM, such as when implementing native extensions,
do SOMETHING YET TO BE DOCUMENTED. XXX


## Object Lifetime

Java objects may be stored anywhere (stack or heap) during the duration
of a Java-to-native callback. These "local references" will be automatically
freed when control returns from the native callback.

However, if a Java object lives longer than a native callback activation, it
is called a "global reference". Global references must be explicitly retained
and released:

```lua
someGlobal = J.retain(obj)
-- later...
J.release(someGlobal)
```

Global references have type `Ref(T)` and act as method proxies to underlying
object of that type. Refs will automatically stripped where a value
of the underlying type is expected.

Local references may be explicitly released in order to free their resources
early.

When interacting with the embedded JVM, the Lua process is effectively a giant
native callback. All local references acquired from the embedded JVM should be
explicitly released.


## Thread-Safety

JNI Environments are _not thread safe_. Therefore, Terra-Java objects
are also not thread safe. Since Lua and the Terra compiler are single
threaded, the lack of thread safety is not an issue for the embedded JVM.

Using `J.acquire` to create a global reference will strip the environment
from a Terra-Java object. The global reference can then be used safely on
any thread in code where a substitute JNI environment is available.


# Translating Java-isms

## Imports

The `J.package(name)` function returns a table of implicitly-defined elements
that represent classes imported from the package of the given name.

```lua
local lang = J.package("java.lang")
local StringBuilder = lang.StringBuilder
```

## Constructors

New objects can be constructed with the `J.new(class, args...)` macro:

```lua
var sb = J.new(StringBuilder, 10000)
```

## Methods

Java methods become Terra methods:

```lua
sb:setLength(50)
```

## Fields

Fields become overloaded accessors methods. Call them without arguments to
return the field's value, or with one argument to set the field's value:

```lua
terra move(p : Point, dx : int, dy : int)
  p:x(p:x() + dx)
  p:y(p:y() + dy)
end
```

## Statics

Static members don't need a _this_ reference, but still need a JNI environment.
To create an object with an environment and a null _this_ reference, use the
`J.static` macro:

```lua
terra pi()
  J.embedded()
  return J.static(Math):toRadians(180)
end
```

Java also provides a synthetic static `.class` field, which returns the type's
`java.lang.Type` object. For this, Terra-Java provides the `J.class` macro:

```lua
J.class(Math):getName() -- returns "java.util.Math"
```

## Arrays

`J.Array(T)` is the generic array type constructor.

Arrays are constructed with `J.new` and accept a size parameter. For example,
this creates an array of ten integers:

```lua
J.new(J.array(int), 10)
```

All arrays have a `len()` method.

Object array elements have direct indexing methods:

- `arr:get(index)`
- `arr:set(index, value)`

Primitive array elements must be accessed via pinning:

```lua
var pinned = arr:retain()
defer pinned:release()
for i = 0, pinned.len do
  f(pinned.elements[i])
end
```

## Strings

TODO


# Native Extensions

TODO



[1]: http://docs.oracle.com/javase/7/docs/technotes/guides/jni/spec/jniTOC.html
[2]: http://terralang.org/
