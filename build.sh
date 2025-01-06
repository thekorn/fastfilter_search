#!/bin/bash

## this is mainly done to copy the `search.wasm` into the `www/` directory
## if we manage to do this with zigs build system, we can remove this script

set -e

zig build
cp ./zig-out/bin/search.wasm ./www/search.wasm
