#!/usr/bin/env bash

# https://github.com/myoung34/docker-github-actions-runner/blob/master/install_actions.sh

GH_RUNNER_VERSION=$1
TARGET_PLATFORM=$2

export TARGET_ARCH="x64"

if [[ $TARGET_PLATFORM == "linux/arm64" ]]; then
  export TARGET_ARCH="arm64"
fi

curl -L "https://github.com/actions/runner/releases/download/v${GH_RUNNER_VERSION}/actions-runner-linux-${TARGET_PLATFORM}-${GH_RUNNER_VERSION}.tar.gz" > ./runner-cli/actions.tar.gz
tar -zxf ./runner-cli/actions.tar.gz -C ./runner-cli
rm -f ./runner-cli/actions.tar.gz

./runner-cli/bin/installdependencies.sh
