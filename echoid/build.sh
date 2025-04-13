#!/bin/bash

# Install dependencies
shards install --production --without development test

# Build challenge
shards build echoid --release --no-debug
strip bin/echoid

# Create database
./create_db.sh

