SHELL := /bin/bash

CURRENT_DIR=$(shell basename $(CURRENT_PWD))
CURRENT_PWD=$(shell pwd)
DATE:=$(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
GIT_REVISION:=$(shell git rev-parse --short HEAD)

IMAGE_REGISTRY=ghcr.io
PROJECT_NAME=github-ci-runner
IMAGE_NAME=imobanco/$(PROJECT_NAME)
IMAGE_TAG=latest
IMAGE=$(IMAGE_REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)
CONTAINERFILE=./ops/container/Containerfile
KUBE_YML=./ops/kubernets/runner.yml
ENV_FILE_NAME=.env

print-%  : ; @echo $($*)


################################################################################
# Dev container commands
################################################################################
build:
	podman build --file $(CONTAINERFILE) --tag $(IMAGE) --label org.opencontainers.image.created=$(DATE) --label org.opencontainers.image.revision=$(GIT_REVISION) $(args) .

run.repo:
	podman run -d --privileged --replace --rm --name repo_runner \
	 -e RUNNER_SCOPE="repo" \
	 -e SCOPE_TARGET="https://github.com/imobanco/github-ci-runner" \
	 -e ACCESS_TOKEN="${ACCESS_TOKEN}" \
	 ghcr.io/imobanco/github-ci-runner:latest
	 podman logs -f repo_runner

run.repo.bash:
	podman run --privileged --replace --rm -it --name repo_runner \
	 -e RUNNER_SCOPE="repo" \
	 -e SCOPE_TARGET="https://github.com/imobanco/github-ci-runner" \
	 -e ACCESS_TOKEN="${ACCESS_TOKEN}" \
	 ghcr.io/imobanco/github-ci-runner:latest bash

run.org:
	podman run -d --privileged --replace --rm --name org_runner \
	 -e RUNNER_SCOPE="org" \
	 -e SCOPE_TARGET="imobanco" \
	 -e ACCESS_TOKEN="${ACCESS_TOKEN}" \
	 ghcr.io/imobanco/github-ci-runner:latest
	 podman logs -f org_runner

login.registry:
	podman login $(IMAGE_REGISTRY)

login.registry.stdin:
	@echo $(PASSWORD)  | podman login --username $(USERNAME) --password-stdin $(IMAGE_REGISTRY)

logout.registry:
	podman logout $(IMAGE_REGISTRY)

pull: login.registry
	podman pull $(IMAGE)

push.to.registry:
	podman push $(IMAGE)

build.and.push:
	make build
	make login.registry.stdin
	make push.to.registry
