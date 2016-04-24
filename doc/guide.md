**WORK IN PROGRESS**

A handful of things in this doc are aspirational, so don't be surprised if
something doesn't work exaclty as advertised. Feel free to file an issue!


# Background

Some familiarity with the [Java Native Interface Specification][1] will be
helpful for many tasks, but should not be required.

Experience with [Lua/Terra][2] and low-level programming is assumed.


# Embedding vs Extending

Terra-Java code executes in one of two contexts:

1. Embedded in a Lua/Terra interpreter.
2. As a native extension of the JVM.

When embedding in Lua, which includes during extension compilation, Terra-Java
runs a private JVM via the JNI Invocation API.

When extending the JVM, Terra-Java code is indistinguishable from traditional
JNI native extensions. There are no run-time dependencies.


# Requiring

All code snippets in this document assume Terra-Java is required as follows:

```lua
local J = require "terra-java"
```


# JNI Environments and Wrapper Objects

All JNI operations require an environment object. Terra-Java wrapper objects
contain references to both an environment and _this_. Methods on a wrapper
object will supply the environment automatically.

If a raw JNI object is required, an implicit conversation will extract the
_this_ reference.

For operations not associated with a particular object instance, an
environment is obtained implicitly from the lexical scope. The target
environment must be declared in the terra function.

For metaprogramming and scripting, declare the embedded JVM:

```lua
terra f()
  J.embedded()
  -- Use JVM here ...
end
```

For callbacks from the JVM, such as when implementing native extensions,
do SOMETHING YET TO BE DOCUMENTED. XXX


# Initialization

Traditional JNI requires many explicit reflective operations to load classes
and to resolve members. Terra-Java automatically identifies necessary calls
to functions such as `FindClass` and `GetMethodID`.

When using the embedded JVM, the generated initialization logic must be run
explicitly before execution of code that uses any newly encountered classes or
members. This is accomplished by the `J.load` Lua function:

```
terra f()
  -- Use new classes or members here...
end

J.load()

f()
```

Loading is incremental and idempotent.

For native extensions, `J.load` is unnecessary. A full implementation of
`JNI_OnLoad` will be provided automatically.


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
object of that type. Refs will be automatically stripped where a value
of the underlying type is expected.

Local references may be explicitly released in order to free their resources
early.

When interacting with the embedded JVM, the Lua process is effectively a giant
native callback. All local references acquired from the embedded JVM should be
explicitly released.


## Thread-Safety

JNI Environments are _not thread safe_. Therefore, wrapper objects are also
not thread safe. Since Lua and the Terra compiler are single threaded, the
lack of thread safety is not an issue for the embedded JVM.  For native
extensions, care must be exercised with wrapper object environments.

Using `J.acquire` to create a global reference will strip the environment
from a wrapper object. The global reference can then be used safely on
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

## Null

Object wrappers are not pointers and therefore cannot be `nil`. To check for
null object references, use the `J.null` predicate macro:

```lua
J.null(obj)
```

## Statics

Static members can be used like any other member on an object instance
wrapper. To access statics without an instance, create a wrapper with a
null reference using the `J.static` macro:

```lua
terra pi()
  J.embedded()
  return J.static(Math):toRadians(180)
end
```

Java also provides a synthetic static `.class` field, which returns the type's
`java.lang.Class` object. For this, Terra-Java provides the `J.class` macro:

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

## Exceptions

TODO


# Native Extensions

To create a JVM native extension, follow these steps:

1. Generate a JVM classfile; eg. compile some Java.
2. Reflect on that class via `J.package`.
3. Redefine some methods on the Terra structure.
4. Call `J.savelib` to produce a native library.

Each step is described in more detail in the sections below.

## Compiling Java with Native Declarations

In one or more `.java` files, declare some methods with the `native` keyword.
For example:

```java
class Foo {
  public native int someMethod(String str, int x);
  // ...
}
```

In some central class of the extension package, create a static initializer to
load the native library:

```java
class Bar {
  static {
    System.loadLibrary("myext")
  }
  // ...
}
```

Then compile the `.java` files in to `.class` files normally.

## Implementing Native Methods

Simply define methods on Terra-Java wrappers like any normal Terra struct.

```lua
local myext = J.package("myext")
local Foo = myext.Foo

terra Foo:someMethod(str : lang.String, x : J.int)
  -- ...
end
```

## Compiling A Native Extension Library

Use the `J.savelib` function.

```lua
J.savelib("./out", "myext", myext)
```

This will produce `./out/libmyext.jnilib`.


## Using The native Extension

Don't forget to set Java's `-librarypath` property to include the path of
your `.jnilib` file!


[1]: http://docs.oracle.com/javase/7/docs/technotes/guides/jni/spec/jniTOC.html
[2]: http://terralang.org/
