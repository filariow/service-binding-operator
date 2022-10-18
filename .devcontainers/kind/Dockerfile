# Build base image with project dependencies
FROM fedora:36 AS base
RUN dnf install -y 'dnf-command(config-manager)' && \
        dnf install -y golang make jq helm kubernetes-client git && \
        dnf install -y moby-engine && \
        go install sigs.k8s.io/kind@v0.16.0 && \
        install /root/go/bin/kind /usr/local/bin/kind

COPY --from=quay.io/operator-framework/operator-sdk:latest /usr/local/bin/operator-sdk /usr/local/bin/operator-sdk

# Download project dependencies
FROM base AS deps
WORKDIR /deps
COPY Makefile Makefile
COPY make make
RUN make install-tools

# Build final image
FROM base AS final
COPY --from=deps /deps/bin/* /usr/local/bin/

## Setup local user
ARG UID
ARG GID
ARG UNAME
RUN groupadd -g ${GID} -o ${UNAME} && \
        useradd -m -u ${UID} -g ${GID} ${UNAME} && \
        usermod -aG docker ${UNAME}
USER $UNAME

CMD sleep infinity

