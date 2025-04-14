#!/bin/bash

ulimit -m 22400

timeout -k 10 --foreground -s SIGKILL 20s deno run --v8-flags=--trace-gc --allow-read index.js

echo "⏰ 🚫 BANK IS NOW CLOSED FOR THE DAY 🚫 ⏰"
