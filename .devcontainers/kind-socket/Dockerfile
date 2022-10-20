# Build base image with project dependencies
FROM fedora:36 AS base
RUN dnf install -y 'dnf-command(config-manager)' && \
        dnf install -y golang make jq git moby-engine && \
        go install sigs.k8s.io/kind@v0.16.0 && \
        install /root/go/bin/kind /usr/local/bin/kind

# Download project dependencies
FROM base AS deps
WORKDIR /deps
COPY Makefile Makefile
COPY make make
RUN make kubectl && make operator-sdk

# Build final image
FROM base AS final
COPY --from=deps /deps/bin/* /usr/local/bin/

## Setup local user
ARG UID
ARG GID
ARG USER
ARG DOCKER_GID
RUN groupadd -g ${GID} -o ${USER} && \
        useradd -m -u ${UID} -g ${GID} ${USER} && \
        groupmod -g ${DOCKER_GID} docker && \
        usermod -aG docker ${USER}
USER $USER

## Startup
COPY .devcontainers/kind/start-kind.sh /startup/
COPY .devcontainers/kind/kind-config.yaml /startup/
COPY .devcontainers/kind/docker-daemon.json /startup/
CMD cd /startup && /startup/start-kind.sh && sleep infinity
