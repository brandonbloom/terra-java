**WORK IN PROGRESS**

This document is currently somewhat aspirational.


# JNI Environments and Terra-Java Objects

All JNI operations require an environment object. Terra-Java wrapper objects
contain both an environment pointer and a _this_ pointer.

TODO: Lots more to say about this.


## Thread-Safety

JNI Environment objects are _not thread safe_. Therefore, Terra-Java objects
are also not thread safe. Since Lua and the Terra compiler are single
threaded, the lack of thread safety is not an issue for the embedded JVM and
metaprogramming code.

However, native code that is potentially called from an external JVM, must be
aware of object-thread ownership. Eventually, there will be a recommended way
to pass objects between threads.


# Translating Java-isms

## Imports

The `J.package` function returns a table of implicitly-defined elements that
represent classes imported from the package of the given name.

```lua
local StringBuilder = J.package("java.lang").StringBuilder
```

## Constructors

New objects can be constructed with the `J.new(class, args...)` macro.

```lua
J.new(StringBuilder, 10000)
```

## Methods

As you'd expect, Java methods become Terra methods.

```lua
obj:method(args, go, here)
```

## Fields

Fields become overloaded accessors methods. No arguments returns the field
value; one argument sets the field value.

```lua
terra move(p : Point, dx : int, dy : int)
  p:x(p:x() + dx)
  p:y(p:y() + dy)
end
```

## Statics

Static members don't need a _this_ pointer, but still need a JNI environment.
You can create an object with a null _this_ pointer with the "static" macro.
Note that this macro uses the implicit environment supplied by `J.embedded()`.

```lua
terra pi()
  J.embedded()
  return Math.static():toRadians(180)
end
```

## Arrays

`J.Array(T)` is the generic array type constructor.

Arrays are constructed with `J.new` and accept a size parameter.
For example: `J.new(J.array(int), 10)` creates an array of ten ints.

All arrays have a `len()` method.

Object array elements have direct indexing methods:

- `arr:get(index)`
- `arr:set(index, value)`

Primitive array elements must be accessed via pinning:

```lua
var pinned = integers:pin()
defer pinned:release()
for i = 0, pinned.len do
  f(pinned.elements[i])
end
```


## Strings

TODO

# Native Extensiono

TODO
