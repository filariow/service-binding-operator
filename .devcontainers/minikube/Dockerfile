FROM docker:dind

RUN apk add go make jq git bash curl python3

WORKDIR /app
COPY make make
COPY Makefile .

RUN  make install-tools && install bin/* /usr/local/bin

ARG UID
ARG GID
ARG UNAME
RUN echo "${UNAME}:x:${UID}:${GID}::/home/${UNAME}:" >> /etc/passwd && \
        echo "${UNAME}:!:$(($(date +%s) / 60 / 60 / 24)):0:99999:7:::" >> /etc/shadow && \
        echo "${UNAME}:x:${UID}:" >> /etc/group && \
        addgroup docker && \
        adduser ${UNAME} docker && \
        adduser nobody docker && \
        mkdir "/home/${UNAME}" && \
        chown ${UNAME}:${UNAME} "/home/${UNAME}" && \
        touch /var/run/docker.sock && \
        chown ${UNAME}:docker /var/run/docker.sock

