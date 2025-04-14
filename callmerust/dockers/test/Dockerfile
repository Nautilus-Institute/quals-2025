FROM callmerust-challenge

USER root

RUN apt-get update && \
    apt-get install -y socat

#RUN echo 'flag{test-flag-please-ignore}' > /flag
RUN bash -c 'echo "flag{test-flag-please-ignore}" > /home/privuser/flag && chown  privuser:privuser /home/privuser/flag && chmod 400 /home/privuser/flag'

USER user

# Set the working directory for the challenge
WORKDIR /opt

CMD socat tcp4-listen:5555,reuseaddr,fork exec:/opt/run_challenge.sh
