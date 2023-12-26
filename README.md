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


# github self-hosted runner em k8s em uma VM NixOS

Gerar token:
- onde gerar: https://github.com/settings/tokens
- com os seguintes checks: https://github.com/myoung34/docker-github-actions-runner/wiki/Usage#token-scope


```bash
rm -fv nixos.qcow2; nix run --impure --refresh --verbose .#vm
```


Copie e cole no terminal da VM e EDITE com seu PAT gerado no passo anterior:
```bash
GITHUB_PAT=ghp_yyyyyyyyyyyyyyy
```


```bash
NAMESPACE="arc-systems"

helm install arc \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller \
    --set image.tag="0.8.1" \
    --version "0.8.1"

INSTALLATION_NAME="arc-runner-set"
NAMESPACE="arc-runners"
GITHUB_CONFIG_URL="https://github.com/Imobanco/github-ci-runner"

helm install "${INSTALLATION_NAME}" \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    --set githubConfigUrl="${GITHUB_CONFIG_URL}" \
    --set githubConfigSecret.github_token="${GITHUB_PAT}" \
    oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
    --set image.tag="0.8.1" \
    --version "0.8.1"
wk8s
```




Verifique que o runner aparece no link:
https://github.com/imobanco/github-ci-runner/actions/runners?tab=self-hosted

No terminal do clone local (apenas para testes manuais) do repositório:
```bash
export GH_TOKEN=ghp_yyyyyyyyyyyyyyy
```


```bash
gh workflow run tests.yml --ref feature/k8s
```
Refs.:
- https://docs.github.com/en/enterprise-server@3.11/actions/using-workflows/manually-running-a-workflow?tool=cli#running-a-workflow

Pelo navegador:
https://github.com/imobanco/github-ci-runner/actions


Links:
- https://docs.github.com/en/enterprise-server@3.11/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller/quickstart-for-actions-runner-controller
- 



## DinD


Copie e cole no terminal da VM e EDITE com seu PAT gerado no passo anterior:
```bash
GITHUB_PAT=ghp_yyyyyyyyyyyyyyy
```


```bash
cd "$HOME" \
&& git clone https://github.com/actions/actions-runner-controller.git \
&& cd actions-runner-controller \
&& git checkout 1f9b7541e6545a9d5ffa052481a84aad7ba4aa4d


cat << 'EOF' > enables-dind.patch
diff --git a/charts/gha-runner-scale-set/values.yaml b/charts/gha-runner-scale-set/values.yaml
index 021fecb..4395555 100644
--- a/charts/gha-runner-scale-set/values.yaml
+++ b/charts/gha-runner-scale-set/values.yaml
@@ -37,11 +37,11 @@ githubConfigSecret:
 #     - example.org
 
 ## maxRunners is the max number of runners the autoscaling runner set will scale up to.
-# maxRunners: 5
+maxRunners: 3
 
 ## minRunners is the min number of idle runners. The target number of runners created will be
 ## calculated as a sum of minRunners and the number of jobs assigned to the scale set.
-# minRunners: 0
+minRunners: 1
 
 # runnerGroup: "default"
 
@@ -75,8 +75,8 @@ githubConfigSecret:
 ##
 ## If any customization is required for dind or kubernetes mode, containerMode should remain
 ## empty, and configuration should be applied to the template.
-# containerMode:
-#   type: "dind"  ## type can be set to dind or kubernetes
+containerMode:
+  type: "dind"  ## type can be set to dind or kubernetes
 #   ## the following is required when containerMode.type=kubernetes
 #   kubernetesModeWorkVolumeClaim:
 #     accessModes: ["ReadWriteOnce"]
@@ -199,6 +199,6 @@ template:
 ## In case the helm chart can't find the right service account, you can explicitly pass in the following value
 ## to help it finish RoleBinding with the right service account.
 ## Note: if your controller is installed to only watch a single namespace, you have to pass these values explicitly.
-# controllerServiceAccount:
-#   namespace: arc-system
-#   name: test-arc-gha-runner-scale-set-controller
+controllerServiceAccount:
+  namespace: arc-system
+  name: test-arc-gha-runner-scale-set-controller
EOF

git apply enables-dind.patch
rm -v enables-dind.patch


NAMESPACE="arc-systems"
helm install arc --wait \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller

#INSTALLATION_NAME="arc-runner-set1"
#NAMESPACE="arc-runners"
#GITHUB_CONFIG_URL="https://github.com/Imobanco/github-ci-runner"
#
#helm install "${INSTALLATION_NAME}" --wait \
#    --namespace "${NAMESPACE}" \
#    --create-namespace \
#    --set githubConfigUrl="${GITHUB_CONFIG_URL}" \
#    --set githubConfigSecret.github_token="${GITHUB_PAT}" \
#    oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set


INSTALLATION_NAME="arc-runner-set-dind"
NAMESPACE="arc-runners"
GITHUB_CONFIG_URL="https://github.com/Imobanco/github-ci-runner"

helm install "${INSTALLATION_NAME}" \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    --set githubConfigUrl="${GITHUB_CONFIG_URL}" \
    --set githubConfigSecret.github_token="${GITHUB_PAT}" \
    --values ~/actions-runner-controller/charts/gha-runner-scale-set/values.yaml \
    oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
    --set image.tag="0.4.0" \
    --version "0.4.0" 
wk8s
```


```bash
kubectl get pods -n arc-systems
kubectl get pods -n arc-runners
```


### Tentativa


```bash
#cd "$HOME" \
#&& git clone https://github.com/actions/actions-runner-controller.git \
#&& cd actions-runner-controller \
#&& git checkout 1f9b7541e6545a9d5ffa052481a84aad7ba4aa4d
#
#cat << 'EOF' > pin-tags-and-dind.patch
#diff --git a/charts/gha-runner-scale-set/values.yaml b/charts/gha-runner-scale-set/values.yaml
#index 021fecb..6bc29fe 100644
#--- a/charts/gha-runner-scale-set/values.yaml
#+++ b/charts/gha-runner-scale-set/values.yaml
#@@ -75,8 +75,8 @@ githubConfigSecret:
# ##
# ## If any customization is required for dind or kubernetes mode, containerMode should remain
# ## empty, and configuration should be applied to the template.
#-# containerMode:
#-#   type: "dind"  ## type can be set to dind or kubernetes
#+containerMode:
#+  type: "dind"  ## type can be set to dind or kubernetes
# #   ## the following is required when containerMode.type=kubernetes
# #   kubernetesModeWorkVolumeClaim:
# #     accessModes: ["ReadWriteOnce"]
#@@ -133,7 +133,7 @@ template:
#   ##           mountPath: /run/docker
#   ##           readOnly: true
#   ##     - name: dind
#-  ##       image: docker:dind
#+  ##       image: docker:24.0.7-dind-alpine3.18
#   ##       args:
#   ##         - dockerd
#   ##         - --host=unix:///run/docker/docker.sock
#@@ -190,7 +190,7 @@ template:
#   spec:
#     containers:
#       - name: runner
#-        image: ghcr.io/actions/actions-runner:latest
#+        image: ghcr.io/actions/actions-runner:2.306.0
#         command: ["/home/runner/run.sh"]
# 
# ## Optional controller service account that needs to have required Role and RoleBinding
#EOF
#
#git apply pin-tags-and-dind.patch
#rm -v pin-tags-and-dind.patch


cd "$HOME" \
&& git clone https://github.com/actions/actions-runner-controller.git \
&& cd actions-runner-controller \
&& git checkout e0a7e142e0fcd446c58e7875d4d44a7eea6e72f2

cat << 'EOF' > pin-tags-and-dind.patch
diff --git a/charts/gha-runner-scale-set/values.yaml b/charts/gha-runner-scale-set/values.yaml
index bbd58ac..8c2db90 100644
--- a/charts/gha-runner-scale-set/values.yaml
+++ b/charts/gha-runner-scale-set/values.yaml
@@ -68,8 +68,8 @@ githubConfigSecret:
 #       key: ca.crt
 #   runnerMountPath: /usr/local/share/ca-certificates/
 
-# containerMode:
-#   type: "dind"  ## type can be set to dind or kubernetes
+containerMode:
+  type: "dind"  ## type can be set to dind or kubernetes
 #   ## the following is required when containerMode.type=kubernetes
 #   kubernetesModeWorkVolumeClaim:
 #     accessModes: ["ReadWriteOnce"]
@@ -158,7 +158,7 @@ template:
   spec:
     containers:
     - name: runner
-      image: ghcr.io/actions/actions-runner:latest
+      image: ghcr.io/actions/actions-runner:2.306.0
       command: ["/home/runner/run.sh"]
 
 ## Optional controller service account that needs to have required Role and RoleBinding
EOF

git pin-tags-and-dind.patch
rm -v pin-tags-and-dind.patch


NAMESPACE="arc-systems"

helm install arc \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller \
    --set image.tag="0.4.0" \
    --version "0.4.0" 

INSTALLATION_NAME="arc-runner-set"
NAMESPACE="arc-runners"
GITHUB_CONFIG_URL="https://github.com/Imobanco/github-ci-runner"

helm install "${INSTALLATION_NAME}" \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    --set githubConfigUrl="${GITHUB_CONFIG_URL}" \
    --set githubConfigSecret.github_token="${GITHUB_PAT}" \
    oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
    --set image.tag="0.4.0" \
    --version "0.4.0" 
    
INSTALLATION_NAME="arc-runner-set-dind"
NAMESPACE="arc-runners"
GITHUB_CONFIG_URL="https://github.com/Imobanco/github-ci-runner"

helm install "${INSTALLATION_NAME}" \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    --set githubConfigUrl="${GITHUB_CONFIG_URL}" \
    --set githubConfigSecret.github_token="${GITHUB_PAT}" \
    --values ~/actions-runner-controller/charts/gha-runner-scale-set/values.yaml \
    oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
    --set image.tag="0.4.0" \
    --version "0.4.0" 
    
wk8s
```


```bash
INSTALLATION_NAME="arc-runner-set"
NAMESPACE="arc-runners"

helm uninstall "${INSTALLATION_NAME}" \
    --namespace "${NAMESPACE}" 
```

#### Kaniko


https://some-natalie.dev/blog/kaniko-in-arc/
https://snyk.io/blog/building-docker-images-kubernetes/


```bash

NAMESPACE="arc-systems"

helm install arc \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller


INSTALLATION_NAME="arc-runner-set"
NAMESPACE="arc-runners"
GITHUB_CONFIG_URL="https://github.com/Imobanco/github-ci-runner"

helm install "${INSTALLATION_NAME}" \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    --set githubConfigUrl="${GITHUB_CONFIG_URL}" \
    --set githubConfigSecret.github_token="${GITHUB_PAT}" \
    oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set


cat > k8s-storage.yml << 'EOF'
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: k8s-mode
  namespace: test-runners # just showing the test namespace
provisioner: file.csi.azure.com # change this to your provisioner
allowVolumeExpansion: true # probably not strictly necessary
reclaimPolicy: Delete
mountOptions:
 - dir_mode=0777 # this mounts at a directory needing this
 - file_mode=0777
 - uid=1000 # match your pod's user id, this is for actions/actions-runner
 - gid=1000
 - mfsymlinks
 - cache=strict
 - actimeo=30
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-k8s-cache-pvc
  namespace: test-runners
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: k8s-mode # we'll need this in the runner Helm chart
EOF


kubectl create namespace test-runners
kubectl apply -f k8s-storage.yml
```


```bash
cat > helm-kaniko.yml << 'EOF'
template:
  spec:
    initContainers: # needed to set permissions to use the PVC
    - name: kube-init
      image: ghcr.io/actions/actions-runner:latest
      command: ["sudo", "chown", "-R", "runner:runner", "/home/runner/_work"]
      volumeMounts:
      - name: work
        mountPath: /home/runner/_work
    containers:
      - name: runner
        image: ghcr.io/actions/actions-runner:latest
        command: ["/home/runner/run.sh"]
        env:
          - name: ACTIONS_RUNNER_CONTAINER_HOOKS
            value: /home/runner/k8s/index.js
          - name: ACTIONS_RUNNER_POD_NAME
            valueFrom:
              fieldRef:
                fieldPath: metadata.name
          - name: ACTIONS_RUNNER_REQUIRE_JOB_CONTAINER
            value: "false"  # allow non-container steps, makes life easier
        volumeMounts:
          - name: work
            mountPath: /home/runner/_work

containerMode:
  type: "kubernetes" 
  kubernetesModeWorkVolumeClaim:
    accessModes: ["ReadWriteOnce"]
    storageClassName: "k8s-mode"
    resources:
      requests:
        storage: 1Gi
EOF

helm install kaniko-worker \
    --namespace "test-runners" \
    --set githubConfigUrl="${GITHUB_CONFIG_URL}" \
    --set githubConfigSecret.github_token="${GITHUB_PAT}" \
    -f helm-kaniko.yml \
    oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
    --version 0.8.1

kubectl get pods -n "test-runners"
```

###




```bash
NAMESPACE="arc-systems"

helm \
install \
--dry-run \
arc \
--namespace "${NAMESPACE}" \
--create-namespace \
oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller \
-o yaml > gha-runner-scale-set-controller.yml


INSTALLATION_NAME="arc-runner-set"
NAMESPACE="arc-runners"
GITHUB_CONFIG_URL="https://github.com/Imobanco/github-ci-runner"


helm \
install \
--dry-run \
"${INSTALLATION_NAME}" \
--namespace "${NAMESPACE}" \
--create-namespace \
--set githubConfigUrl="${GITHUB_CONFIG_URL}" \
--set githubConfigSecret.github_token="${GITHUB_PAT}" \
oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
-o yaml > gha-runner-scale-set.yml

wk8s
```



```bash
helm install --dry-run --debug

#kubectl create namespace arc-runners
#kubectl create secret generic pre-defined-secret \
#--namespace=arc-runners \
#--from-literal=github_token="${GITHUB_PAT}"


    --set image.tag="0.4.0" \
    --version "0.4.0" \
```


```bash
cd "$HOME" \
&& git clone https://github.com/actions/actions-runner-controller.git \
&& cd actions-runner-controller \
&& git checkout 1f9b7541e6545a9d5ffa052481a84aad7ba4aa4d


mkdir -pv ~/arc-configuration/{controller,runner-scale-set-1,runner-scale-set-2} \
&& cd ~/arc-configuration


cd ~/actions-runner-controller/charts \
&& cp -v actions-runner-controller/values.yaml ~/arc-configuration/controller \
&& cp -v gha-runner-scale-set/values.yaml ~/arc-configuration/runner-scale-set-1 \
&& cp -v gha-runner-scale-set/values.yaml  ~/arc-configuration/runner-scale-set-2

```
