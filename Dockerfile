FROM golang:1.12.6

ENV CGO_ENABLED=0
ENV GO111MODULE=on

#---------------Install java------------------------
# Hack for debian-slim to make the jdk install work below.
RUN mkdir -p /usr/share/man/man1
# repo needed for jdk install below.
RUN echo 'deb http://deb.debian.org/debian stretch-backports main' > /etc/apt/sources.list.d/backports.list
# Update image & install application dependant packages.
# RUN apt-get update && apt-get install -y nano libxext6 libfreetype6-dev libjpeg62-turbo-dev libpng-dev libmcrypt-dev libxslt-dev libpcre3-dev libxrender1 libfontconfig uuid-dev ghostscript curl wget ca-certificates-java
RUN apt-get update && apt-get install -y default-jdk unzip apt-transport-https tar xz-utils

RUN curl -fsSL https://get.docker.com -o get-docker.sh
RUN sh get-docker.sh

ENV JFROG_CLI_HOME_DIR=/home/jenkins

# install jfrog go.

WORKDIR /go/bin
RUN curl -fL https://getcli.jfrog.io | sh
RUN chmod +x /go/bin/jfrog
RUN mkdir /.jfrog && chmod 777 /.jfrog

# RUN kubectl cluster-info
ADD https://storage.googleapis.com/kubernetes-release/release/v1.11.2/bin/linux/amd64/kubectl /go/bin/kubectl
USER root
RUN chmod +x /go/bin/kubectl

# install node
WORKDIR /usr/local/lib/nodejs
RUN curl -O https://nodejs.org/dist/v12.6.0/node-v12.6.0-linux-x64.tar.xz \
    && tar -xJvf node-v12.6.0-linux-x64.tar.xz -C /usr/local/lib/nodejs
    
ENV PATH=/usr/local/lib/nodejs/node-v12.6.0-linux-x64/bin:$PATH

WORKDIR /go/bin

RUN mkdir -p /home/jenkins && chmod 777 /home/jenkins

RUN mkdir -p /.cache && chmod 777 /.cache


