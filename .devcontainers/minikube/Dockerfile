FROM docker:dind

RUN apk add go make jq git bash curl python3

WORKDIR /app
COPY make make
COPY Makefile .

RUN  make install-tools && install bin/* /usr/local/bin

