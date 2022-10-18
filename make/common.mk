SHELL = /usr/bin/env bash -o pipefail
SHELLFLAGS = -ec

OS = $(shell go env GOOS)
ARCH = $(shell go env GOARCH)

CGO_ENABLED ?= 0
GO111MODULE ?= on
GOCACHE ?= "$(PROJECT_DIR)/out/gocache"
GOFLAGS ?= -mod=vendor

ARTIFACT_DIR ?= $(PROJECT_DIR)/out
HACK_DIR ?= $(PROJECT_DIR)/hack
OUTPUT_DIR ?= $(PROJECT_DIR)/out
PYTHON_VENV_DIR = $(OUTPUT_DIR)/venv3

CONTAINER_RUNTIME ?= docker

QUAY_USERNAME ?= redhat-developer+travis
REGISTRY_USERNAME ?= $(QUAY_USERNAME)
REGISTRY_NAMESPACE ?= $(QUAY_USERNAME)
QUAY_TOKEN ?= ""
REGISTRY_PASSWORD ?= $(QUAY_TOKEN)

GO ?= CGO_ENABLED=$(CGO_ENABLED) GOCACHE=$(GOCACHE) GOFLAGS="$(GOFLAGS)" GO111MODULE=$(GO111MODULE) go

.DEFAULT_GOAL := help

## Print help message for all Makefile targets
## Run `make` or `make help` to see the help
.PHONY: help
help: ## Credit: https://gist.github.com/prwhite/8168133#gistcomment-2749866

	@printf "Usage:\n  make <target>\n\n";

	@awk '{ \
			if ($$0 ~ /^.PHONY: [a-zA-Z\-_0-9]+$$/) { \
				helpCommand = substr($$0, index($$0, ":") + 2); \
				if (helpMessage) { \
					printf "\033[36m%-20s\033[0m %s\n", \
						helpCommand, helpMessage; \
					helpMessage = ""; \
				} \
			} else if ($$0 ~ /^[a-zA-Z\-_0-9.]+:/) { \
				helpCommand = substr($$0, 0, index($$0, ":")); \
				if (helpMessage) { \
					printf "\033[36m%-20s\033[0m %s\n", \
						helpCommand, helpMessage; \
					helpMessage = ""; \
				} \
			} else if ($$0 ~ /^##/) { \
				if (helpMessage) { \
					helpMessage = helpMessage"\n                     "substr($$0, 3); \
				} else { \
					helpMessage = substr($$0, 3); \
				} \
			} else { \
				if (helpMessage) { \
					print "\n                     "helpMessage"\n" \
				} \
				helpMessage = ""; \
			} \
		}' \
		$(MAKEFILE_LIST)


# When you run make VERBOSE=1 (the default), executed commands will be printed
# before executed. If you run make VERBOSE=2 verbose flags are turned on and
# quiet flags are turned off for various commands. Use V_FLAG in places where
# you can toggle on/off verbosity using -v. Use Q_FLAG in places where you can
# toggle on/off quiet mode using -q. Use S_FLAG where you want to toggle on/off
# silence mode using -s...
VERBOSE ?= 1
Q = @
Q_FLAG = -q
QUIET_FLAG = --quiet
V_FLAG =
S_FLAG = -s
X_FLAG =
ZAP_ENCODER_FLAG = --zap-log-level=debug --zap-encoder=console
VERBOSE_FLAG =
ifeq ($(VERBOSE),1)
	Q =
endif
ifeq ($(VERBOSE),2)
	Q =
	Q_FLAG =
	QUIET_FLAG =
	S_FLAG =
	V_FLAG = -v
	VERBOSE_FLAG = --verbose
	X_FLAG = -x
endif
ifeq ($(VERBOSE),3)
	Q_FLAG =
	QUIET_FLAG =
	S_FLAG =
	V_FLAG = -v
	VERBOSE_FLAG = --verbose
	X_FLAG = -x
endif

.PHONY: setup-venv
# Setup virtual environment
setup-venv:
	$(Q)python3 -m venv $(PYTHON_VENV_DIR)
	$(Q)$(PYTHON_VENV_DIR)/bin/pip install --upgrade setuptools
	$(Q)$(PYTHON_VENV_DIR)/bin/pip install --upgrade pip

.PHONY: clean
## Removes temp directories
clean:
	$(Q)-rm -rf ${V_FLAG} $(OUTPUT_DIR)

# Generate code
generate: controller-gen
	$(CONTROLLER_GEN) object:headerFile="hack/boilerplate.go.txt" paths="./..."

gen-mocks: mockgen
	PATH=$(shell pwd)/bin:$(shell printenv PATH) $(GO) generate $(V_FLAG) ./...

# Download controller-gen locally if necessary
CONTROLLER_GEN = $(shell pwd)/bin/controller-gen
controller-gen:
	$(call go-install-tool,$(CONTROLLER_GEN),sigs.k8s.io/controller-tools/cmd/controller-gen@v0.7.0)

# Download kustomize locally if necessary
KUSTOMIZE = $(shell pwd)/bin/kustomize
kustomize:
	$(call go-install-tool,$(KUSTOMIZE),sigs.k8s.io/kustomize/kustomize/v4@v4.5.4)

# go-install-tool will 'go install' any package $2 and install it to $1.
define go-install-tool
@[ -f $(1) ] || { \
set -e ;\
TMP_DIR=$$(mktemp -d) ;\
cd $$TMP_DIR ;\
go mod init tmp ;\
echo "Downloading $(2)" ;\
GOBIN=$(PROJECT_DIR)/bin go install $(2) ;\
rm -rf $$TMP_DIR ;\
}
endef

YQ = $(shell pwd)/bin/yq
yq:
	$(call go-install-tool,$(YQ),github.com/mikefarah/yq/v4@v4.26.1)

KUBECTL_SLICE = $(shell pwd)/bin/kubectl-slice
kubectl-slice:
	$(call go-install-tool,$(KUBECTL_SLICE),github.com/patrickdappollonio/kubectl-slice@v1.1.0)

MOCKGEN = $(shell pwd)/bin/mockgen
mockgen:
	$(call go-install-tool,$(MOCKGEN),github.com/golang/mock/mockgen@v1.6.0)

.PHONY: opm
OPM ?=  $(shell pwd)/bin/opm
opm:
	@(($$(command -v opm >/dev/null) && \
		[[ $$(command -v opm) != "$(OPM)" ]] && \
		[[ $$(opm version | cut -d'"' -f 2) =~ 'v$(OPM_VERSION)' ]]) && \
		rm -f $(OPM) && ln -s $$(command -v opm) $(OPM) || true)
	@([ -f '$(OPM)' ] && \
		[[ $$($(OPM) version | cut -d'"' -f 2) =~ 'v$(OPM_VERSION)' ]] \
		&& echo "opm $(OPM_VERSION) found") || { \
			set -e ;\
			mkdir -p $(dir $(OPM)) ;\
			rm -f $(OPM) ; \
			curl -sSLo $(OPM) https://github.com/operator-framework/operator-registry/releases/download/v$(OPM_VERSION)/$(OS)-$(ARCH)-opm ;\
			chmod +x $(OPM) ;\
		}

.PHONY: minikube
MINIKUBE ?=  $(shell pwd)/bin/minikube
minikube:
	@(($$(command -v minikube >/dev/null) && \
		[[ $$(command -v minikube) != "$(MINIKUBE)" ]] && \
		[[ $$(minikube version --short) =~ 'v$(MINIKUBE_VERSION)' ]]) && \
		rm -f $(MINIKUBE) && ln -s $$(command -v minikube) $(MINIKUBE) || true)
	@([ -f '$(MINIKUBE)' ] && \
		[[ $$($(MINIKUBE) version --short) =~ 'v$(MINIKUBE_VERSION)' ]] \
		&& echo "minikube $(MINIKUBE_VERSION) found") || { \
			set -e ;\
			mkdir -p $(dir $(MINIKUBE)) ;\
			rm -f $(MINIKUBE) ; \
			curl -sSLo $(MINIKUBE)  https://storage.googleapis.com/minikube/releases/v$(MINIKUBE_VERSION)/minikube-$(OS)-$(ARCH) ;\
			chmod +x $(MINIKUBE) ;\
		}

.PHONY: operator-sdk
OPERATOR_SDK ?=  $(shell pwd)/bin/operator-sdk
operator-sdk:
	@(($$(command -v operator-sdk >/dev/null) && \
		[[ $$(command -v operator-sdk) != "$(OPERATOR_SDK)" ]] && \
		[[ $$(operator-sdk version | cut -d',' -f 1 | cut -d'"' -f 2) =~ 'v$(OPERATOR_SDK_VERSION)' ]]) && \
		rm -f $(OPERATOR_SDK) && ln -s $$(command -v operator-sdk) $(OPERATOR_SDK) || true)
	@([ -f '$(OPERATOR_SDK)' ] && \
		[[ $$($(OPERATOR_SDK) version | cut -d',' -f 1 | cut -d'"' -f 2) =~ 'v$(OPERATOR_SDK_VERSION)' ]] \
		&& echo "operator-sdk $(OPERATOR_SDK_VERSION) found") || { \
			set -e ;\
			mkdir -p $(dir $(OPERATOR_SDK)) ;\
			rm -f $(OPERATOR_SDK) ; \
			curl -sSLo $(OPERATOR_SDK) https://github.com/operator-framework/operator-sdk/releases/download/v$(OPERATOR_SDK_VERSION)/operator-sdk_$(OS)_$(ARCH) ;\
			chmod +x $(OPERATOR_SDK) ;\
		}

.PHONY: kubectl
KUBECTL ?=  $(shell pwd)/bin/kubectl
kubectl: yq
	@(($$(command -v kubectl >/dev/null) && \
		[[ $$(command -v kubectl) != "$(KUBECTL)" ]] && \
		[[ $$(kubectl version --client --output yaml | $(YQ) eval '.clientVersion.gitVersion' -) =~ 'v$(KUBECTL_VERSION)' ]]) && \
		rm -f $(KUBECTL) && ln -s $$(command -v kubectl) $(KUBECTL) || true)
	@([ -f '$(KUBECTL)' ] && \
		[[ $$($(KUBECTL) version --client --output yaml | $(YQ) eval '.clientVersion.gitVersion' -) =~ 'v$(KUBECTL_VERSION)' ]] \
		&& echo "kubectl $(KUBECTL_VERSION) found") || { \
			set -e ;\
			mkdir -p $(dir $(KUBECTL)) ;\
			rm -f $(KUBECTL) ; \
			curl -sSLo $(KUBECTL) https://dl.k8s.io/release/v$(KUBECTL_VERSION)/bin/$(OS)/$(ARCH)/kubectl ;\
			chmod +x $(KUBECTL) ;\
		}

.PHONY: helm
HELM ?=  $(shell pwd)/bin/helm
helm:
	@(($$(command -v helm >/dev/null) && \
		[[ $$(command -v helm) != "$(HELM)" ]] && \
		[[ $$(helm version --short) =~ 'v$(HELM_VERSION)' ]]) && \
		rm -f $(HELM) && ln -s $$(command -v helm) $(HELM) || true)
	@([ -f '$(HELM)' ] && [[ $$($(HELM) version --short) =~ 'v$(HELM_VERSION)' ]] && echo "helm $(HELM_VERSION) found") || { \
		set -e ;\
		mkdir -p $(dir $(HELM)) $(HELM)-install ;\
		curl -sSLo $(HELM)-install/helm.tar.gz https://get.helm.sh/helm-v$(HELM_VERSION)-$(OS)-$(ARCH).tar.gz ;\
		tar xvfz $(HELM)-install/helm.tar.gz -C $(HELM)-install >/dev/null ;\
		rm -f $(HELM) ; \
		cp $(HELM)-install/$(OS)-$(ARCH)/helm $(HELM) ;\
		rm -r $(HELM)-install ;\
		chmod +x $(HELM) ;\
	}

.PHONY: install-tools
install-tools: minikube opm mockgen kubectl-slice yq kustomize controller-gen gen-mocks operator-sdk kubectl helm
	@echo
	@echo run '`eval $$(make local-env)`' to configure your shell to use tools in the ./bin folder

.PHONY: local-env
local-env:
	@echo export PATH=$(shell pwd)/bin:$$PATH

all: build
