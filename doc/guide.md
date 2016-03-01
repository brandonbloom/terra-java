**WORK IN PROGRESS**

This document is currently aspirational.

# Translating Java-isms

## Constructors

New objects can be constructed with the `J.new` macro.

## Methods

## Fields

Fields become overloaded accessors methods. No arguments returns the field
value; one argument sets the field value.

```lua
local Rectangle = J.package("java.awt").Rectangle
terra move(rect : Rectangle, x : int, y : int)
  rect:x(rect:x() + amount)
  rect:y(rect:y() + amount)
end
```

## Statics

Static members don't need a _this_ pointer, but still need a JNI environment.
You can create an object with a null _this_ pointer with the "static" method:

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

Arrays have the following methods defined on them:

- `arr:len()`
- `arr:get(index)`
- `arr:set(index, value)`


# JNI-isms

# Lua/Terra-isms

# Thread-Safety

Java-Terra objects contain a reference to the JNI Environment object, which is
_not thread safe_. Eventually, there will be a recommended way to pass objects
between threads.
