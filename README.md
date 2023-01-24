# github-ci-runner


https://github.com/actions/runner


https://github.com/myoung34/docker-github-actions-runner

https://dev.to/pwd9000/create-a-docker-based-self-hosted-github-runner-linux-container-48dh

https://testdriven.io/blog/github-actions-docker/

https://hub.docker.com/r/myoung34/github-runner



# Token PAT

https://github.com/myoung34/docker-github-actions-runner/wiki/Usage#token-scope

# Install action
```bash
./ops/bash/install_action.sh 2.301.2 x64
```

# Runner token
## Enterprise
```bash
source .env
RUNNER_SCOPE=ent
SCOPE_TARGET=imobanco
./ops/bash/runner_token.sh
```

## Organization
```bash
source .env
RUNNER_SCOPE=org
SCOPE_TARGET=imobanco
./ops/bash/runner_token.sh
```

## Repo
```bash
source .env
RUNNER_SCOPE=repo
SCOPE_TARGET=https://github.com/imobanco/github-ci-runner
./ops/bash/runner_token.sh
```