#!/bin/bash

docker build --network=host -t jxl4fun . -f Dockerfile

echo "Running server on 0.0.0.0:5555"

socat tcp4-listen:5555,reuseaddr,fork exec:./__run.sh