#!/usr/bin/env bash

./scripts/build.sh

patchelf --set-rpath '$ORIGIN/' harchiver
cp harchiver release/
cp LICENSE release/
cp README.md release/
tar czvf harchiver.tar.gz release/

