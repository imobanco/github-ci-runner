

TODO: qual a fonte desse exemplo? Perdi e não encontrei novamente.

```bash
cd ~/kubernetes-examples/appvia \
&& kubectl apply \
    -f deployment.yaml \
    -f service.yaml \
    -f ingress.yaml
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
