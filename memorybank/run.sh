#!/bin/bash

docker build -t deno-banking-system .
docker run --rm -i deno-banking-system