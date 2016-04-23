#!/bin/bash

set -ex

rm -rf ./obj
mkdir ./obj
find ./terra-java -name '*.java' | xargs javac -d ./obj

terra ./terra-java/examples/extension/native.t
