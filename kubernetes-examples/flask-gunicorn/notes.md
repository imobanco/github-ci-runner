



Adaptado para usar `nodePort`: 
```bash
cat > flask-node-port.yml <<-'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: hello-service
  name: hello-service
spec:
  replicas: 3
  selector:
    matchLabels:
      app: hello-service
  template:
    metadata:
      labels:
        app: hello-service
    spec:
      containers:
      - name: hello-service
        image: quay.io/lordofthejars/hello-flask:1.0.0
        ports:
          - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: hello-service
  labels:
    app: hello-service
spec:
  # Expose the service on a static port on each node
  # so that we can access the service from outside the cluster 
  type: NodePort

  # When the node receives a request on the static port (30163)
  # "select pods with the label 'app' set to 'echo-hostname'"
  # and forward the request to one of them
  selector:
    app: hello-service

  ports:
    # Three types of ports for a service
    # nodePort - a static port assigned on each the node
    # port - port exposed internally in the cluster
    # targetPort - the container port to send requests to
    - nodePort: 30163
      port: 8080 
      targetPort: 8080
EOF

kubectl apply -f flask-node-port.yml
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


## Usando LoadBalancer e ip hardcoded

```bash
cat > flask-load-balancer.yml <<-'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: hello-service
  name: hello-service
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello-service
  template:
    metadata:
      labels:
        app: hello-service
    spec:
      containers:
      - name: hello-service
        image: quay.io/lordofthejars/hello-flask:1.0.0
        ports:
          - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: hello-service
  labels:
    app: hello-service
spec:
  ports:
  - name: http
    port: 8080
  selector:
    app: hello-service
  type: LoadBalancer
  externalIPs:
  - "34.74.203.201"
EOF


kubectl apply -f flask-load-balancer.yml

```
Refs.:
- https://paul-boone.medium.com/kubernetes-loadbalancer-ip-stuck-in-pending-6ddea72b8ff5


No terminal da VM NixOS:
```bash
curl 34.74.203.201:8080/
```

Pelo que entendi não funciona externamente.



