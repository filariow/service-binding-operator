FROM fedora:36

CMD [ "sleep", "infinity" ]

RUN dnf install -y 'dnf-command(config-manager)' && \
        dnf install -y golang make jq helm kubernetes-client git

RUN dnf install -y moby-engine
COPY --from=quay.io/operator-framework/operator-sdk:latest /usr/local/bin/operator-sdk /usr/local/bin/operator-sdk

ARG UID
ARG GID
ARG UNAME
RUN groupadd -g ${GID} -o ${UNAME} && \
		useradd -m -u ${UID} -g ${GID} ${UNAME} && \
		usermod -aG docker ${UNAME}
RUN go install sigs.k8s.io/kind@v0.16.0 && install /root/go/bin/kind /usr/local/bin/kind

USER $UNAME

