

Originalmente encontrado aqui:
https://kubernetes.io/docs/tutorials/stateless-application/guestbook

Está quebrado! Pelo menos uma das imagens usadas não existem mais!
```bash
docker pull gcr.io/google_samples/gb-frontend:v5
```
Refs.:
- https://kubernetes.io/docs/tutorials/stateless-application/guestbook/#creating-the-guestbook-frontend-deployment

```bash
journalctl --unit docker
```


Encontrei o repo original, mas também não consegui fazer funcionar 100%.


https://cloud.google.com/kubernetes-engine/docs/tutorials/guestbook


```bash
git clone https://github.com/GoogleCloudPlatform/kubernetes-engine-samples \
&& cd kubernetes-engine-samples/quickstarts/guestbook \
&& BASE_URL='https://k8s.io/examples/application/guestbook'
kubectl apply \
-f redis-leader-deployment.yaml \
-f redis-leader-service.yaml \
-f redis-follower-deployment.yaml \
-f redis-follower-service.yaml \
-f frontend-service.yaml
```

```bash
kubectl get service frontend
```

```bash
wk8s
```




```bash
cat > static-docker-example.yml <<-'EOF'
---
apiVersion: v1
kind: Pod
metadata:
  name: static-docker-example
spec:
  volumes:
  - name: dockersocket
    emptyDir: {}

  containers:

    # This is going to be our docker service container.
    - name: docker-service
      image: docker:dind-rootless
      
      # IMPORTANT! This is security related.
      # Read up about running privileged containers
      securityContext:
        privileged: true

      volumeMounts:
      - name: dockersocket
        mountPath: /run/user/1000/

    # We will run commands in this one.
    - name: docker-commander
      image: docker:dind-rootless
      # Just keep the container running
      command: [ "/bin/sh", "-c", "sleep 86000s" ]
      volumeMounts:
      - name: dockersocket
        mountPath: /var/run
EOF


kubectl apply -f static-docker-example.yml

```
Refs.:
- https://discuss.kubernetes.io/t/can-k8s-or-k8s-api-build-image-with-dockerfile/16059/2

