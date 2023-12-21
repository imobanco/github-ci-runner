

```bash
cd ~/kubernetes-examples/appvia \
&& kubectl apply \
-f deployment.yaml \
-f service.yaml \
-f ingress.yaml


while true; do
  kubectl get pod --all-namespaces -o wide \
  && echo \
  && kubectl get services --all-namespaces -o wide \
  && echo \
  && kubectl get nodes --all-namespaces -o wide; 
  sleep 1;
  clear;
done
```

