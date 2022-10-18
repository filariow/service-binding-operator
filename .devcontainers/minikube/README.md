# Demo - minikube with DinD

1. Load the environment with docker compose

```console
UID=$(id -u) GID=$(id -g) UNAME=$(id -u -n) docker compose up -d --build
```

1. Start minikube
```console
docker exec --user $(id -u):docker minikube-app-1 /sbo/hack/start-minikube.sh
```

1. Enable OLM
```console
docker exec --user $(id -u):docker minikube-app-1 minikube addons enable olm
```

1. Deploy the Service Binding Operator
```console
docker exec --user $(id -u):docker minikube-app-1 bash -c 'eval $(minikube docker-env) && make deploy OPERATOR_REPO_REF=$(minikube ip):5000/sbo'
```

1. Run acceptance tests
```console
docker exec --user $(id -u):docker minikube-app-1 bash -c 'eval $(minikube docker-env) && make test-acceptance TEST_ACCEPTANCE_TAGS="@dev" TEST_ACCEPTANCE_START_SBO=remote TEST_ACCEPTANCE_CLI=kubectl'
```

