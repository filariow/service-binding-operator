SHELL = /usr/bin/env bash -o pipefail
SHELLFLAGS = -ec


# Source for generating docs (one of `local` and `github`)
SITE_SOURCE ?= local

.PHONY: site
## render site
site:
ifeq ($(SITE_SOURCE),local)
	SITE_URL=${PWD}/out/site envsubst < antora-playbook.local.yaml.tmpl > antora-playbook.local.yaml
endif
	$(CONTAINER_RUNTIME) run -u $(shell id -u) -e CI=true -e HOME=/antora -v ${PWD}:/antora:Z --rm -t antora/antora:3.0.1 antora-playbook.$(SITE_SOURCE).yaml
