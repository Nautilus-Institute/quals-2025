FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y python3 python3-pip python3-dev git libssl-dev libffi-dev build-essential && \
    apt-get clean

RUN python3 -m pip install --upgrade pip && python3 -m pip install --upgrade pwntools

COPY ./solver/* /opt/

WORKDIR /opt

CMD python3 /opt/solver.py
