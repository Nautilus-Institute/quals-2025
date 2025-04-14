# =============== Building Challenge In Docker  =============== 
# If you want your challenge to rebuild every time you push to this repository,
# fill in the dependencies and commands in this top part of the Dockerfile
# If you want to do this, follow the steps below

# Choose your base distro to build the challenge on.
# Some examples: debian:bullseye, ubuntu:22.04, alpine:latest, fedora:latest
# Or any other base docker image
FROM ubuntu:22.04 AS builder

# Install any requirements needed to build, using the RUN command
# For example here are a few build tools and libraries
RUN apt-get update && \
    apt-get install -y build-essential

# This adds all files in the ./src directory. If you have files somewhere else, move them to ./src or add another COPY command below
COPY src /src

RUN mkdir /build

WORKDIR /src

RUN rm -f loader

# This will run the script ./src/build.sh 
# You can also change it to run any other command to perform the build
RUN if [ -f ./build.sh ]; then ./build.sh; fi


# =============== Production Challenge Environment  ===============
# This part of the docker file defines the runtime environment for your challenge
# Please follow the steps below:

# CHAL AUTHOR: Choose your base distro to run the challenge on.
# Some examples: debian:bullseye, ubuntu:22.04, alpine:latest, fedora:latest
# Or any other base docker image
FROM ubuntu:22.04

# CHAL AUTHOR: If you have any runtime dependencies, install them here
# example: installing curl from apt
RUN apt-get update && apt-get install -y curl

RUN apt-get install -y cargo

RUN apt-get install -y strace htop

# By default all the challenge files go into /opt/.

# Copy any files built using `./src/build.sh`
COPY --from=builder /build/loader /opt/



RUN adduser --disabled-password --gecos "" user
RUN adduser --disabled-password --gecos "" privuser

RUN mkdir -p /home/privuser && chown privuser:privuser /home/privuser && chmod go-rwx /home/privuser

#the flag will be places in /home/privuser/flag, owned by privuser:privuser, with permissions 400
#RUN bash -c 'echo "flag{test-flag-please-ignore}" > /home/privuser/flag && chown  privuser:privuser /home/privuser/flag && chmod 400 /home/privuser/flag' ###

COPY ./bin/run_challenge.sh /opt/
COPY ./bin/workdir /opt/workdir
RUN chown -R user:user /opt/workdir

RUN mkdir /opt/privuserdir
RUN touch /opt/privuserdir/f
RUN chown -R privuser:privuser /opt/privuserdir

RUN chown privuser:privuser /opt/loader
RUN chmod +s /opt/loader



USER user

WORKDIR /opt/workdir
RUN cargo build --release

WORKDIR /opt
CMD /opt/run_challenge.sh

#CMD /bin/bash
