#!/bin/bash

# Bash scripts to install Docker-CE engine and Kubernetes engine
# to a CentOS box.

# Sets up a multi node kubernetes cluster
# with a master node and worker node(s)

# Exit upon encountering an error
set -euo pipefail

# Set the base route
ROOT_DIR=$(pwd)

# Run the script to set up the env variables and other custom functions
source $ROOT_DIR/utils.sh

    ###################################################################################
    ###                                                                             ###
    ###            !!! TO BE EXECUTED AS NORMAL USER !!!                            ###
    ###                EXECUTED IN THE LOCAL MACHINE                                ###
    ###                                                                             ###
    ###################################################################################


# This assumes you're on Ubuntu OS in your local machine/work station

function installKubectl {
    info "Adding the repo, gpg keys and installing kubectl"
    # Add the repo, gpg keys and install kubectl locally
    sudo apt-get update && sudo apt-get install -y apt-transport-https
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
    echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
    sudo apt-get update
    sudo apt-get install -y kubectl

    # Test the new kubectl. This should have an issue of refused connection
    kubectl version
}

function configureKubectl {
    require USER_NAME $USER_NAME
    require HOST_ADDRESS $HOST_ADDRESS

    info "Configuring Kubectl"
    # Create a kubectl config file locally
    mkdir -p ~/.kube/
    scp $USER_NAME@$HOST_ADDRESS:~/.kube/config ~/.kube/

    # Test the new kubectl. This should not have the issue of refused connection
    kubectl version
}

function UIDashboardDisplay {
    # Get the token needed to connect to the dashboard
    kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep k8s-admin | awk '{print $1}')

    # Start the proxy to be able to access the dashboard on the browser from loclhost
    kubectl proxy # http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy
}

function installStorageos {
    info "Installing and configuring helm"

    # Install Helm, which is a package manager of kubernetes.
    sudo snap install helm --classic

    info "Installing and configuring Storageos to manage storage on the cluster"
    # Use helm to install storageos, our storage management of choice.
    helm repo add storageos https://charts.storageos.com
    helm install storageos/storageos --name=storageos --namespace=storageos --set cluster.join="$WORKER_NODE1_HOSTNAME\,$WORKER_NODE2_HOSTNAME\,$WORKER_NODE3_HOSTNAME"
    ClusterIP=$(kubectl get svc/storageos --namespace storageos -o custom-columns=IP:spec.clusterIP --no-headers=true)
    ApiAddress=$(echo -n "tcp://$ClusterIP:5705" | base64)
    kubectl patch secret/storageos-api --namespace storageos --patch "{\"data\": {\"apiAddress\": \"$ApiAddress\"}}"

    # Create a kubernetes storage class from the .yaml script here and make it default
    kubectl apply -f $ROOT_DIR/storageClass.yaml
    kubectl patch storageclass fast -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

    # You can access the storageos dashboard by running this command. The credentials should be `storageos/storageos`
    kubectl --namespace storageos port-forward svc/storageos 5705 #  http://localhost:5705
}

function metrics {
    info "Setting up the metrics server"
    # Setup the metrics server to monitor resource utilization
    DOWNLOAD_URL=$(curl --silent "https://api.github.com/repos/kubernetes-sigs/metrics-server/releases/latest" | jq -r .tarball_url)
    DOWNLOAD_VERSION=$(grep -o '[^/v]*$' <<< $DOWNLOAD_URL)
    curl -Ls $DOWNLOAD_URL -o metrics-server-$DOWNLOAD_VERSION.tar.gz
    mkdir metrics-server-$DOWNLOAD_VERSION
    tar -xzf metrics-server-$DOWNLOAD_VERSION.tar.gz --directory metrics-server-$DOWNLOAD_VERSION --strip-components 1
    kubectl apply -f metrics-server-$DOWNLOAD_VERSION/deploy/1.8+/

    # Verify the deployment of the metrics server
    kubectl get deployment metrics-server -n kube-system
}

function prometheus {
    # Add monitoring of the cluster using prometheus
    info "deploying prometheus to the cluster"

}

function run {
    installKubectl
    configureKubectl
    installStorageos
    metrics
    prometheus
}

run
