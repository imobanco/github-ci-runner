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


Passo 0: Clonar o repositório:
```bash
nix flake clone 'git+ssh://git@github.com/imobanco/github-ci-runner.git' --dest github-ci-runner \
&& cd github-ci-runner 1>/dev/null 2>/dev/null \
&& git checkout feature/github-runner-as-systemd-service \
&& (direnv --version 1>/dev/null 2>/dev/null && direnv allow) \
|| nix develop --command $SHELL
```


Passo 1: Iniciar a VM:
```bash
rm -fv nixos.qcow2;  

nix run --impure --refresh --verbose .#vm
```


Passo 2: Em outro terminal, mas no mesmo diretório:
```bash
remote-viewer spice://localhost:3001
```


Passo 3: Injetando manualmente o PAT. No terminal da VM use 
"seta para cima" (para acessar o histórico):
```bash
run-github-runner && sudo systemctl restart github-runner-nixos.service
```


Passo 4: Verifique que o runner aparece no link:
https://github.com/imobanco/github-ci-runner/actions/runners?tab=self-hosted


Passo 5: No terminal do clone local (apenas para testes manuais) do repositório:
```bash
export GH_TOKEN=ghp_yyyyyyyyyyyyyyy
```


Passo 6: Iniando manualmente o workflow 
Note: o remoto tenta iniciar a execução com o código que está no REMOTO, ou seja,
modificações apenas locais não são executadas.
```bash
gh workflow run tests.yml --ref feature/github-runner-as-systemd-service
```
Refs.:
- https://docs.github.com/en/enterprise-server@3.11/actions/using-workflows/manually-running-a-workflow?tool=cli#running-a-workflow


Pelo navegador:
https://github.com/imobanco/github-ci-runner/actions

