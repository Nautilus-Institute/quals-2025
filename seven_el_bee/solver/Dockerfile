FROM debian:bookworm AS builder

RUN apt-get update && apt-get install -y \
    build-essential clang

COPY . /opt/solver
WORKDIR /opt/solver
RUN make

FROM debian:bookworm

COPY --from=builder /opt/solver/solver /opt/solver/bin/solver

RUN adduser --no-create-home --disabled-password --gecos "" user
USER user

WORKDIR /
CMD ["/opt/solver/bin/solver"]
