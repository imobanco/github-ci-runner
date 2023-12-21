



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
while true; do
  kubectl get pod --all-namespaces -o wide \
  && echo \
  && kubectl get services --all-namespaces -o wide \
  && echo \
  && kubectl get deployments.apps --all-namespaces -o wide \
  && echo \
  && kubectl get nodes --all-namespaces -o wide; 
  sleep 2;
  clear;
done
```
