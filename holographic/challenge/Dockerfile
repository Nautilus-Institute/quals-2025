FROM debian:bookworm AS builder

RUN apt-get update && apt-get install -y \
    build-essential clang

COPY . /opt/challenge
WORKDIR /opt/challenge
RUN make

FROM debian:bookworm

COPY --from=builder /opt/challenge/build/holographic /opt/challenge/bin/holographic

RUN adduser --no-create-home --disabled-password --gecos "" user
USER user

WORKDIR /
CMD ["/opt/challenge/bin/holographic"]
