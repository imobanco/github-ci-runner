#!/usr/bin/env bash


docker run -d --restart always --name github-runner \
  -e REPO_URL="https://github.com/imobanco/github-ci-runner" \
  -e ACCESS_TOKEN="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" \
  -e RUNNER_NAME="teste-runner" \
  -e RUNNER_WORKDIR="/tmp/github-runner-your-repo" \
  -e RUNNER_GROUP="my-group" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /tmp/github-runner-your-repo:/tmp/github-runner-your-repo \
  ghcr.io/myoung34/docker-github-actions-runner:latest
