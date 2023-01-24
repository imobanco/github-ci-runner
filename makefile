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
	podman run -d --rm \
	 -e RUNNER_SCOPE="repo" \
	 -e SCOPE_TARGET="https://github.com/imobanco/github-ci-runner" \
	 -e ACCESS_TOKEN="${ACCESS_TOKEN}" \
	 ghcr.io/imobanco/github-ci-runner:latest

run.org:
	podman run -d --rm \
	 -e RUNNER_SCOPE="org" \
	 -e SCOPE_TARGET="imobanco" \
	 -e ACCESS_TOKEN="${ACCESS_TOKEN}" \
	 ghcr.io/imobanco/github-ci-runner:latest
