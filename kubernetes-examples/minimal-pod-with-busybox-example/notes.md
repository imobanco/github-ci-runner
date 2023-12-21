

```bash
cd ~/kubernetes-examples/minimal-pod-with-busybox-example \
&& kubectl apply \
-f minimal-pod-with-busybox-example.yaml


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
