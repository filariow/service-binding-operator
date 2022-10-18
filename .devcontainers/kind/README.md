# Demo

1. Load the environment with docker compose.
```bash
UID=$(id -u) GID=$(id -g) UNAME=$(id -u -n) docker compose up --build
```

1. Start kind and install OLM
```bash
docker exec kind-app-1 bash -c "cd /sbo/.devcontainers/kind && /sbo/.devcontainers/kind/start-kind.sh"
```

1. Configure the registry hostname in dind
```bash
docker exec kind-dind-1 sh -c 'docker exec kind-control-plane bash -c "echo $(getent hosts registry) >> /etc/hosts"'
```

1. Build and deploy the Service Binding Operator
```bash
docker exec kind-app-1 make deploy OPERATOR_REPO_REF=registry:5000/sbo
docker exec kind-app-1 make push-image-unauth OPERATOR_REPO_REF=registry:5000/sbo
```

1. Run acceptance tests
```bash
docker exec kind-app-1 make test-acceptance TEST_ACCEPTANCE_TAGS="@dev" TEST_ACCEPTANCE_START_SBO=remote TEST_ACCEPTANCE_CLI=kubectl
```

## Troubleshooting

If you notice problems with kind startup, a problem may be in host's inotify limits

```console
sudo sysctl fs.inotify.max_user_watches=655360
sudo sysctl fs.inotify.max_user_instances=1280
```
