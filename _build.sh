#!/bin/bash
sudo apt-get install libicu-dev
rm -rf dist/
cd lapack-3.12.1
rm -rf build/
mkdir -p build && cd build
cmake -GNinja -DCMAKE_INSTALL_PREFIX=../../dist ..
cmake --build . --target install  && cd ../../
rm -rf build/
mkdir -p build && cd build
cmake -GNinja -DCMAKE_INSTALL_PREFIX=../dist ..
cmake --build . --target install && cd ../
mv ./dist/include/fst ./dist/include/kaldi/fst
