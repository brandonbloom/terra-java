# Terra-Java

Raw JNI too cumbersome? JNA not fast enough? C++ code generators make you sad?

Try Terra-Java!


## Abstract

Terra-Java leverages Terra's metaprogramming facilities to enable you to
define native JVM extensions with unprecedented ease.

JNI boilerplate is automatically generated during Terra compilation.

Just as Terra can generate native code without a runtime Lua dependency,
Terra-Java can generate JVM extensions without a Terra-Java dependency.


## Status

This project is a work-in-progress. Some things do not work as advertised yet.


## Quick Start

### Dependencies & Configuration

Install [Terra 2016-03-25][1] and the JDK, then set the following environment
variables:

- `INCLUDE_PATH`: Terra looks here for standard C headers.
- `JDK_HOME`: Terra-Java looks here for Java headers and libjvm.

To use Terra-Java from your own Terra project, add the directory containing
`terra-java.t` to one additional environment variable:

- `TERRA_PATH`: Terra's version of `LUA_PATH`.

### Build

Compile the Terra-Java support libraries and examples:

```bash
./build.sh
```

### Running Examples

Run Terra code that interops with the JVM:

```bash
terra ./terra-java/examples/interop.t
terra ./terra-java/examples/extension/native.t
```

Run JVM code that utilizes native extensions:

```bash
java \
  -Djava.class.path=./obj \
  -Djava.library.path=./obj \
  terrajava.examples.extension.Accumulator
```


## Usage

Check out [the examples](./terra-java/examples), then see
[the guide](./doc/guide.md) for many more details


[1]: https://github.com/zdevito/terra/releases/tag/release-2016-03-25
