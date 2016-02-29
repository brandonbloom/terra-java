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


## Getting Started

Try the example below, then see the [guide][./guide.md].

### Example Extension

```terra
--TODO: Include some C code.
--TODO: Import some Java classes.
--TODO: Define a class with a native methods.
```

### Configuration

The following environment variables should be set:

`INCLUDE_PATH`: Used by Terra to find standard C headers.
`JDK_HOME`: Terra-Java uses this to find Java headers and libjvm.

### Running With Embedded JVM

```terra
--TODO: launch a JVM
```

```bash
#TODO: run above terra
```

### Building Native Libraries

```terra
--TODO: save an object file
```

```bash
#TODO: run above terra
```
