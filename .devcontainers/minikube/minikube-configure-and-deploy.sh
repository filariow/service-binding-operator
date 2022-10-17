#!/usr/bin/env bash

# configure minikube
minikube addons enable olm

# configure shell
eval $(minikube docker-env)

# deploy sbo
make deploy OPERATOR_REPO_REF=$(minikube ip):5000/sbo
