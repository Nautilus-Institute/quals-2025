FROM debian:bookworm AS builder

RUN apt-get update && apt-get install -y \
    build-essential clang

COPY . /opt/challenge
WORKDIR /opt/challenge
RUN make

FROM debian:bookworm

COPY --from=builder /opt/challenge/build/solver /opt/challenge/bin/solver

RUN adduser --no-create-home --disabled-password --gecos "" user
USER user

WORKDIR /
CMD ["/opt/challenge/bin/solver"]
