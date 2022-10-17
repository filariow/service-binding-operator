# Demo - minikube with DinD

```console
UID=$(id -u) GID=$(id -g) UNAME=$(id -u -n) docker compose up -d --build
docker exec --user $(id -u):docker minikube-app-1 /sbo/hack/start-minikube.sh

# docker exec --user $(id -u):docker minikube-app-1 bash /sbo/.devcontainers/minikube/minikube-configure-and-deploy.sh
docker exec --user $(id -u):docker minikube-app-1 minikube addons enable olm
docker exec --user $(id -u):docker minikube-app-1 bash -c 'eval $(minikube docker-env) && make deploy OPERATOR_REPO_REF=$(minikube ip):5000/sbo'

docker exec --user $(id -u):docker minikube-app-1 bash -c 'eval $(minikube docker-env) && make test-acceptance TEST_ACCEPTANCE_TAGS="@dev" TEST_ACCEPTANCE_START_SBO=remote TEST_ACCEPTANCE_CLI=kubectl'
```

```console
#!/bin/env bash

# deploy in minikube script
minikube addons enable olm
eval $(minikube docker-env)
make deploy OPERATOR_REPO_REF=$(minikube ip):5000/sbo
```
