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

# go-install-tool will 'go install' any package $2 and install it to $1.
define go-install-tool
[ -f $(1) ] || { \
set -e ;\
TMP_DIR=$$(mktemp -d) ;\
cd $$TMP_DIR ;\
go mod init tmp 2>/dev/null ;\
GOBIN=$(PROJECT_DIR)/bin go install $(2) ;\
rm -rf $$TMP_DIR ;\
}
endef

define output-install
echo "$(1)@$(2) installed"
endef

# Download controller-gen locally if necessary
CONTROLLER_GEN = $(shell pwd)/bin/controller-gen
controller-gen:
	@(($$(command -v controller-gen >/dev/null) && \
		[[ $$(command -v controller-gen) != "$(CONTROLLER_GEN)" ]] && \
		[[ $$(controller-gen --version | cut -d' ' -f 2) =~ 'v$(CONTROLLER_GEN_VERSION)' ]]) && \
		rm -f $(CONTROLLER_GEN) && ln -s $$(command -v controller-gen) $(CONTROLLER_GEN) || true)
	@([ -f '$(CONTROLLER_GEN)' ] && \
		[[ $$($(CONTROLLER_GEN) --version | cut -d' ' -f 2) =~ 'v$(CONTROLLER_GEN_VERSION)' ]] \
		&& echo "controller-gen $(CONTROLLER_GEN_VERSION) found") || { \
			rm -f $(CONTROLLER_GEN) ;\
			$(call go-install-tool,$(CONTROLLER_GEN),sigs.k8s.io/controller-tools/cmd/controller-gen@v$(CONTROLLER_GEN_VERSION)) ;\
			$(call output-install,controller-gen,$(CONTROLLER_GEN_VERSION)) ;\
		}


YQ = $(shell pwd)/bin/yq
yq:
	@(($$(command -v yq >/dev/null) && \
		[[ $$(command -v yq) != "$(YQ)" ]] && \
		[[ $$(yq --version | cut -d' ' -f 3) =~ '$(YQ_VERSION)' ]]) && \
		rm -f $(YQ) && ln -s $$(command -v yq) $(YQ) || true)
	@([ -f '$(YQ)' ] && \
		[[ $$($(YQ) --version | cut -d' ' -f 3) =~ '$(YQ_VERSION)' ]] \
		&& echo "yq $(YQ_VERSION) found") || { \
			rm -f $(YQ) ;\
			$(call go-install-tool,$(YQ),github.com/mikefarah/yq/v4@v$(YQ_VERSION)) ;\
			$(call output-install,yq,$(YQ_VERSION)) ;\
		}

KUBECTL_SLICE = $(shell pwd)/bin/kubectl-slice
kubectl-slice:
	@(($$(command -v kubectl-slice >/dev/null) && \
	[[ $$(command -v kubectl-slice) != "$(KUBECTL_SLICE)" ]] && \
		[[ $$(kubectl-slice --version | cut -d' ' -f 3) =~ '$(KUBECTL_SLICE_VERSION)' ]]) && \
		rm -f $(KUBECTL_SLICE) && ln -s $$(command -v kubectl-slice) $(KUBECTL_SLICE) || true)
	@([ -f '$(KUBECTL_SLICE)' ] && \
		[[ $$($(KUBECTL_SLICE) --version | cut -d' ' -f 3) =~ '$(KUBECTL_SLICE_VERSION)' ]] \
		&& echo "kubectl-slice $(KUBECTL_SLICE_VERSION) found") || { \
			rm -f $(KUBECTL_SLICE) ;\
			arch=$$(case "$(ARCH)" in "amd64") echo "x86_64" ;; *) echo "$(ARCH)" ;; esac) ;\
			mkdir -p $(KUBECTL_SLICE)-install ;\
			curl -sSLo $(KUBECTL_SLICE)-install/kubectl-slice.tar.gz https://github.com/patrickdappollonio/kubectl-slice/releases/download/v$(KUBECTL_SLICE_VERSION)/kubectl-slice_$(KUBECTL_SLICE_VERSION)_$(OS)_$${arch}.tar.gz ;\
			tar xvfz $(KUBECTL_SLICE)-install/kubectl-slice.tar.gz -C $(KUBECTL_SLICE)-install/ > /dev/null ;\
			mv $(KUBECTL_SLICE)-install/kubectl-slice $(KUBECTL_SLICE) ;\
			rm -rf $(KUBECTL_SLICE)-install ;\
			$(call output-install,kubectl-slice,$(KUBECTL_SLICE_VERSION)) ;\
		}


MOCKGEN = $(shell pwd)/bin/mockgen
mockgen:
	@(($$(command -v mockgen >/dev/null) && \
		[[ $$(command -v mockgen) != "$(MOCKGEN)" ]] && \
		[[ $$(mockgen --version | cut -d' ' -f 3) =~ 'v$(MOCKGEN_VERSION)' ]]) && \
		rm -f $(MOCKGEN) && ln -s $$(command -v mockgen) $(MOCKGEN) || true)
	@([ -f '$(MOCKGEN)' ] && \
		[[ $$($(MOCKGEN) --version | cut -d' ' -f 3) =~ 'v$(MOCKGEN_VERSION)' ]] \
		&& echo "mockgen $(MOCKGEN_VERSION) found") || { \
			rm -f $(MOCKGEN) ;\
			$(call go-install-tool,$(MOCKGEN),github.com/golang/mock/mockgen@v$(MOCKGEN_VERSION)) ;\
			$(call output-install,mockgen,$(MOCKGEN_VERSION)) ;\
		}
	

KUSTOMIZE = $(shell pwd)/bin/kustomize
kustomize:
	@(($$(command -v kustomize >/dev/null) && \
		[[ $$(command -v kustomize) != "$(KUSTOMIZE)" ]] && \
		[[ $$(kustomize version | cut -d' ' -f 1 | cut -d'/' -f 2) =~ 'v$(KUSTOMIZE_VERSION)' ]]) && \
		rm -f $(KUSTOMIZE) && ln -s $$(command -v kustomize) $(KUSTOMIZE) || true)
	@([ -f '$(KUSTOMIZE)' ] && \
		[[ $$($(KUSTOMIZE) version | cut -d' ' -f 1 | cut -d'/' -f 2) =~ 'v$(KUSTOMIZE_VERSION)' ]] \
		&& echo "kustomize $(KUSTOMIZE_VERSION) found") || { \
			set -e ;\
			mkdir -p $(dir $(KUSTOMIZE)) ;\
			rm -f $(KUSTOMIZE) ; \
			mkdir -p $(KUSTOMIZE)-install ;\
			curl -sSLo $(KUSTOMIZE)-install/kustomize.tar.gz https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv$(KUSTOMIZE_VERSION)/kustomize_v$(KUSTOMIZE_VERSION)_$(OS)_$(ARCH).tar.gz ;\
			tar xzvf $(KUSTOMIZE)-install/kustomize.tar.gz -C $(KUSTOMIZE)-install/ >/dev/null ;\
			mv $(KUSTOMIZE)-install/kustomize $(KUSTOMIZE) ;\
			rm -rf $(KUSTOMIZE)-install ;\
			chmod +x $(KUSTOMIZE) ;\
			$(call output-install,kustomize,$(KUSTOMIZE_VERSION)) ;\
		}

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
			$(call output-install,opm,$(OPM_VERSION)) ;\
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
			$(call output-install,minikube,$(MINIKUBE_VERSION)) ;\
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
			$(call output-install,operator-sdk,$(OPERATOR_SDK_VERSION)) ;\
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
			$(call output-install,kubectl,$(KUBECTL_VERSION)) ;\
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
		$(call output-install,helm,$(HELM_VERSION)) ;\
	}

.PHONY: install-tools
install-tools: controller-gen helm kubectl kubectl-slice kustomize minikube mockgen operator-sdk opm yq
	@echo
	@echo run '`eval $$(make local-env)`' to configure your shell to use tools in the ./bin folder

.PHONY: local-env
local-env:
	@echo export PATH=$(shell pwd)/bin:$$PATH

all: build
