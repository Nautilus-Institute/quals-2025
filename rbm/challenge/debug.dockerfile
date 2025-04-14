FROM debian:bookworm

RUN apt-get update && apt-get install -y \
    build-essential clang gdb \
    ruby-base64 ruby-json
