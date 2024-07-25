#!/bin/sh
rm lmao.s && cat app.trash | zig run src/main.zig >> lmao.s && ./link.sh lmao.s && ./lmao