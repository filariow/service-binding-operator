#!/bin/env sh

unset KUBECONFIG
kind create cluster --config ./kind-config.yaml
docker exec kind-control-plane sh -c "echo $(getent hosts registry) >> /etc/hosts"
sed -i 's/0\.0\.0\.0/kubernetes/' ${HOME}/.kube/config
export KUBECONFIG=${HOME}/.kube/config

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

cat << EOF

Setup is complete.

Try install and test the service-binding-operator from the container $HOSTNAME

    docker exec $HOSTNAME make deploy OPERATOR_REPO_REF=registry:5000/sbo
    docker exec $HOSTNAME make push-image -o registry-login OPERATOR_REPO_REF=registry:5000/sbo
    docker exec $HOSTNAME make test-acceptance TEST_ACCEPTANCE_TAGS="@dev" TEST_ACCEPTANCE_START_SBO=remote TEST_ACCEPTANCE_CLI=kubectl
EOF
