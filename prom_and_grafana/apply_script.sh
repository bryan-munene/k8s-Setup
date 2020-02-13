#bin/bash

# Perform cluster role binding

# create the monitoring namespace
kubectl create namespace monitoring

# Create the role
kubectl create -f working/role2.yml

# Create the config map
kubectl create -f working/config-map.yml -n monitoring

# Deploy the mandatory file
# kubectl apply -f working/man.yml -n monitoring

# Deploy prometheus
kubectl apply -f working/prometheus-deployment.yml -n monitoring

# Crete a service to expose prometheus
kubectl apply -f working/prometheus-service.yml --namespace=monitoring

# Echo check on pods
echo "Running pods......"
kubectl get pods --namespace=monitoring
