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


# k8s in NixOS VM


Gerar token:
- onde gerar: https://github.com/settings/tokens
- com os seguintes checks: https://github.com/myoung34/docker-github-actions-runner/wiki/Usage#token-scope


```bash
rm -fv nixos.qcow2; nix run --impure --refresh --verbose .#vm
```


Copie e cole no terminal da VM e edite com seu PAT gerado no pasos anterior:
```bash
GITHUB_TOKEN=ghp_yyyyyyyyyyyyyyy
```



```bash
# Bem haky, só bypassei o problema que deixava como pending
kubectl label nodes nixos size=linux
kubectl get nodes nixos --show-labels

NAME_SPACE_RUNNER='actions-runner-system'
kubectl create ns "$NAME_SPACE_RUNNER"

mkdir -pv ~/k8s-bootstrap-runner \
&& ~/k8s-bootstrap-runner

cat > script.sh <<-'EOF'
rm -rf *.pem *.csr *.srl || true

# Step 1: CA
# ----------

# create CA, it is secret, keep it safe
openssl genrsa -out ca.private.pem 2048

# create public CA, give it to everyone so they can add it to trusted root
openssl req -x509 -new -key ca.private.pem -out ca.public.pem -days 10000 -subj "/C=UA/L=Kiev"

# Step 2: Certificate
# -------------------

# create certificate, it is secret, keep it safe
openssl genrsa -out cert.private.pem 2048

# create "certificate signing request" (csr)
openssl req -new -key cert.private.pem -out cert.csr -subj "/CN=actions-runner-controller-webhook.actions-runner-system.svc"

# config
cat <<EOT >> cert.conf
[SAN]
subjectAltName = @alt_names
[alt_names]
DNS.1 = actions-runner-controller-webhook.actions-runner-system.svc
DNS.2 = actions-runner-controller-webhook.actions-runner-system.svc.cluster.local
EOT

# sign it with our CA
openssl x509 -req -in cert.csr -CA ca.public.pem -CAkey ca.private.pem -CAcreateserial -out cert.public.pem -days 10000 -extensions SAN -extfile cert.conf

# clean
rm -rf *.csr *.srl cert.conf || true

# check
openssl x509 -in cert.public.pem -text -noout | grep DNS
EOF

chmod 0755 script.sh

./script.sh

# smoke tests, better than nothing?!
test -f cert.public.pem || exit 1
test -f cert.private.pem || exit 1
test -f ca.public.pem || exit 1


kubectl create secret tls actions-runner-controller-serving-cert \
--namespace="$NAME_SPACE_RUNNER" \
--cert=cert.public.pem \
--key=cert.private.pem


# 

cat > values.yml <<-'EOF'
authSecret:
  create: true
  github_token: ghp_xxxxxxxxxxxxxxx

# POI: disable cert manager
certManagerEnabled: false

admissionWebHooks:
  # POI: cat ca.public.pem | base64
  caBundle: xxxxxxxxxxxxxxxxxxxxxxxxxxxx=

nodeSelector:
size: linux

podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/path: /metrics
  prometheus.io/port: "8080"
EOF


sed -i 's/xxxxxxxxxxxxxxxxxxxxxxxxxxxx=/'"$(cat ca.public.pem | base64 -w 0)"'/g' values.yml
sed -i 's/ghp_xxxxxxxxxxxxxxx/'"$GITHUB_TOKEN"'/g' values.yml

helm upgrade actions-runner-controller actions-runner-controller \
--install \
--namespace "$NAME_SPACE_RUNNER" \
--repo https://actions-runner-controller.github.io/actions-runner-controller \
-f values.yml


cat > runner.yml <<-'EOF'
apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment
metadata:
  name: gha
  namespace: actions-runner-system
spec:
  replicas: 1
  template:
    spec:
      # https://github.com/actions-runner-controller/actions-runner-controller/blob/master/docs/detailed-docs.md#runner-with-dind
      dockerdWithinRunnerContainer: true
      organization: Imobanco
      labels:
        - 'gha'
        - 'gha-dev'
      nodeSelector:
        size: linux

      resources:
        limits:
          cpu: "6.0"
          memory: "5Gi"
        requests:
          cpu: "3.0"
          memory: "4Gi"
EOF

kubectl --namespace="$NAME_SPACE_RUNNER" apply -f runner.yml

export POD_NAME=$(kubectl get pods --namespace "$NAME_SPACE_RUNNER" -l "app.kubernetes.io/name=actions-runner-controller,app.kubernetes.io/instance=actions-runner-controller" -o jsonpath="{.items[0].metadata.name}")

export CONTAINER_PORT=$(kubectl get pod --namespace "$NAME_SPACE_RUNNER" $POD_NAME -o jsonpath="{.spec.containers[0].ports[0].containerPort}")


echo "$POD_NAME"
echo "$CONTAINER_PORT"

```
Refs.:
- https://mac-blog.org.ua/github-actions-kubernetes-runner-without-certmanager/
- https://serverfault.com/questions/1099167/node-pool-selection
- https://superuser.com/a/1225139


```bash
kubectl describe -n "$NAME_SPACE_RUNNER" pod "$POD_NAME"
```


```bash
kubectl describe pod "$POD_NAME" -n "$NAME_SPACE_RUNNER"
```


TODO: 
Pq esse comando não termina?
O que esse comando faz exatamente?
```bash
kubectl \
--namespace "$NAME_SPACE_RUNNER" \
port-forward $POD_NAME 8080:$CONTAINER_PORT
```




```bash
kubectl -n actions-runner-system get pods
kubectl -n actions-runner-system get runners
```
Refs.:
- https://mac-blog.org.ua/github-actions-kubernetes-runner-without-certmanager/


```bash
while ! false; do
  kubectl get pod --all-namespaces -o wide \
  && echo \
  && kubectl get services --all-namespaces -o wide \
  && echo \
  && kubectl get nodes --all-namespaces -o wide; 
  sleep 2;
  clear;
done
```

