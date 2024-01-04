# github-ci-runner

https://github.com/actions/runner

## Refs
- https://github.com/myoung34/docker-github-actions-runner
- https://dev.to/pwd9000/create-a-docker-based-self-hosted-github-runner-linux-container-48dh
- https://testdriven.io/blog/github-actions-docker/
- https://hub.docker.com/r/myoung34/github-runner



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
./ops/bash/runner_token.sh ent imobanco
```

## Organization
```bash
source .env
./ops/bash/runner_token.sh org imobanco
```

## Repo
```bash
source .env
./ops/bash/runner_token.sh repo https://github.com/imobanco/github-ci-runner
```

# Entrypoint
```bash
source .env
RUNNER_SCOPE="org" SCOPE_TARGET="imobanco" bash ./ops/bash/entrypoint.sh
```


# github self-hosted runner em uma máquina virtual NixOS usando systemd


Gerar token:
- onde gerar: https://github.com/settings/tokens
- com os seguintes checks: https://github.com/myoung34/docker-github-actions-runner/wiki/Usage#token-scope


Como o copy/paste está quebrado nesse momento, é necessário
clonar o repositório.
```bash
nix flake clone 'git+ssh://git@github.com/imobanco/github-ci-runner.git' --dest github-ci-runner \
&& cd github-ci-runner 1>/dev/null 2>/dev/null \
&& git checkout feature/github-runner-as-systemd-service \
&& (direnv --version 1>/dev/null 2>/dev/null && direnv allow) \
|| nix develop --command $SHELL
```


Por hora está sendo feito um hardcode do PAT. 
Cole o valor do seu PAT no script `run-github-runner`.


Após adicionar o PAT:
```bash
rm -fv nixos.qcow2;  
env NIXPKGS_ALLOW_UNFREE=1 \
NIXPKGS_ALLOW_INSECURE=1 \
nix run --impure --refresh --verbose .#vm
```

O histórico é populado com comandos úteis.
Usar seta para cima e enter.

