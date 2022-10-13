#!/bin/env sh

kind create cluster --config /sbo/.devcontainers/kind-config.yaml
docker exec kind-control-plane sh -c 'getent hosts registry >> /etc/hosts'
sed -i 's/0\.0\.0\.0/kubernetes/' ${HOME}/.kube/config
export KUBECONFIG=$HOME/.kube/config

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "registry:5000"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

operator-sdk olm install --timeout 10m

