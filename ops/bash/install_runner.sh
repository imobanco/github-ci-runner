#!/usr/bin/env bash

# https://github.com/myoung34/docker-github-actions-runner/blob/master/install_actions.sh

GH_RUNNER_VERSION=$1
TARGET_PLATFORM=$2

export TARGET_ARCH="x64"

if [[ $TARGET_PLATFORM == "linux/arm64" ]]; then
  export TARGET_ARCH="arm64"
fi

pwd
ls -la
ls -la ./runner-cli

curl -L "https://github.com/actions/runner/releases/download/v${GH_RUNNER_VERSION}/actions-runner-linux-${TARGET_PLATFORM}-${GH_RUNNER_VERSION}.tar.gz" > /home/runner_user/runner-cli/actions.tar.gz

ls -la
ls -la ./runner-cli
tar -zxf /home/runner_user/runner-cli/actions.tar.gz -C /home/runner_user/runner-cli

ls -la
ls -la ./runner-cli
rm -f /home/runner_user/runner-cli/actions.tar.gz

ls -la
ls -la ./runner-cli

/home/runner_user/runner-cli/bin/installdependencies.sh
