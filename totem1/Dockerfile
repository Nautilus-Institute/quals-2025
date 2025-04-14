FROM amd64/ubuntu:24.04

RUN apt-get update && apt-get install -y nasm binutils

WORKDIR /code

CMD ["bash", "-c", "echo \"a\" | /code/output/totem1x64_g"]