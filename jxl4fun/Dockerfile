FROM ubuntu:24.04@sha256:72297848456d5d37d1262630108ab308d3e9ec7ed1c3286a32fe09856619a782 as base

RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    libjpeg-dev \
    libpng-dev \
    libtiff-dev \
    libwebp-dev \
    libgif-dev \
    libz-dev \
    libopenexr-dev \
    libbrotli-dev \
    libgcc-10-dev

from base as builder

RUN git clone https://github.com/libjxl/libjxl.git && cd libjxl && git checkout 9845054a9d104062bb8712f3a04996a415e63774

WORKDIR /libjxl

RUN /libjxl/deps.sh

RUN apt-get update && apt-get install pkg-config clang-18 clang++-18 -y

ADD change.patch .
RUN patch -p1 < change.patch

ENV CC=clang-18
ENV CXX=clang++-18


WORKDIR /libjxl/build

RUN cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DJPEGXL_ENABLE_DEVTOOLS=ON -DCMAKE_CXX_FLAGS="-DJXL_DEBUG_V_LEVEL=100" ..

RUN make -j$(nproc)

from base as runner

RUN apt-get update && apt-get install -y socat python3 gdb strace
RUN git clone https://github.com/pwndbg/pwndbg --depth=1 && cd pwndbg && ./setup.sh

WORKDIR /libjxl/lib

COPY --from=builder /libjxl/build/lib/libjxl_threads.so.0.12 /libjxl/lib/.
COPY --from=builder /libjxl/build/lib/libjxl.so.0.12 /libjxl/lib/.
COPY --from=builder /libjxl/build/lib/libjxl_cms.so.0.12 /libjxl/lib/.
COPY --from=builder /libjxl/build/third_party/brotli/libbrotlidec.so.1 /libjxl/lib/.
COPY --from=builder /libjxl/build/third_party/brotli/libbrotlienc.so.1 /libjxl/lib/.
COPY --from=builder /libjxl/build/third_party/brotli/libbrotlicommon.so.1 /libjxl/lib/.

COPY --from=builder /libjxl/build/compile_commands.json /libjxl/compile_commands.json

ENV LD_LIBRARY_PATH=/libjxl/lib:$LD_LIBRARY_PATH

WORKDIR /libjxl/bin

COPY --from=builder /libjxl/build/tools/djxl /libjxl/bin/djxl

COPY src/server.py /libjxl/bin/server.py

COPY src/run_challenge.sh /libjxl/bin/run_challenge.sh

RUN echo "flug{you-connected-to-the-wrong-endpoint-for-flag1-please-try-the-other-endpoint-thank-you:)}" > /flag_intro

CMD "/libjxl/bin/run_challenge.sh"
