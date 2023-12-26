

Atualmente quebrado!

https://kubernetes.io/docs/tutorials/stateless-application/expose-external-ip-address/#creating-a-service-for-an-application-running-in-five-pods

Adaptado para usar `nodePort`: 
```bash
cat > nodejs-node-port.yml <<-'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/name: load-balancer-example
  name: hello-world
spec:
  replicas: 5
  selector:
    matchLabels:
      app.kubernetes.io/name: load-balancer-example
  template:
    metadata:
      labels:
        app.kubernetes.io/name: load-balancer-example
    spec:
      containers:
      - image: gcr.io/google-samples/node-hello:1.0
        name: hello-world
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: hello-world
  labels:
    app: hello-world
spec:
  # Expose the service on a static port on each node
  # so that we can access the service from outside the cluster 
  type: NodePort

  # When the node receives a request on the static port (30163)
  # "select pods with the label 'app' set to 'echo-hostname'"
  # and forward the request to one of them
  selector:
    app: hello-world

  ports:
    # Three types of ports for a service
    # nodePort - a static port assigned on each the node
    # port - port exposed internally in the cluster
    # targetPort - the container port to send requests to
    - nodePort: 30163
      port: 8080 
      targetPort: 8080
EOF

kubectl apply -f nodejs-node-port.yml
```
Refs.:
- [How to deploy a Flask application in Python with Gunicorn](https://developers.redhat.com/articles/2023/08/17/how-deploy-flask-application-python-gunicorn#)
- https://matthewpalmer.net/kubernetes-app-developer/articles/service-kubernetes-example-tutorial.html
- https://medium.com/google-cloud/kubernetes-nodeport-vs-loadbalancer-vs-ingress-when-should-i-use-what-922f010849e0



```bash
wk8s
```

Em um terminal na VM NixOS:
```bash
curl localhost:30163/
```


Em um terminal no host:
```bash
curl localhost:8090/
```

