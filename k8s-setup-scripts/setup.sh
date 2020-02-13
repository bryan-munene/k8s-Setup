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

    ###############################################################################
    ###                                                                         ###
    ###            !!! TO BE EXECUTED AS SUPER USER !!!                         ###
    ###                                                                         ###
    ###############################################################################

# Become super user
sudo -i -p $PASSWORD

function basePackages {
    # Update all packages and Install the yum-config-manager

    info "Updating all packages and Installing the yum-config-manager"
    
    sudo yum update -y      
    sudo yum install -y yum-utils device-mapper-persistent-data lvm2
}

function docker {
    # Remove any installed docker version if any.
    
    require VERSION_STRING $VERSION_STRING

    info "Adding the docker repo and installing it"
    
    sudo yum remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine

    # Add the repo to install docker
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

    # List all available docker versions for installation
    # yum list docker-ce --showduplicates | sort -r

    # Install a specific version of docker since RHEL and CentOS 8 fails if no version is specified.
    sudo yum install docker-ce-$VERSION_STRING docker-ce-cli-$VERSION_STRING containerd.io

    # Disable firewalld so DNS resolution can work inside the container.
    sudo systemctl disable firewalld

    # Enable the docker service and start it.
    sudo systemctl enable --now docker && sudo systemctl start docker

    # Test the installation of docker
    sudo docker run hello-world

    # Add the user to the docker user group
    sudo usermod -aG docker $USER
}

function k8sIPtables {
    # Configure iptables for Kubernetes
    
    info "Configuring iptables for Kubernetes"

cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

    sysctl --system
}

function k8sRepo {
    # Add the kubernetes repo needed to find the kubelet, kubeadm and kubectl packages

    info "Adding the k8s repo"

cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
}

function disables {
    # Set SELinux in permissive mode (effectively disabling it)

    info "Disabling SELinux and swap"

    setenforce 0
    sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
    
    # Turn off the swap: Required for Kubernetes to work
    sudo swapoff -a
}

function k8sInstallation {
    info "Installing kubernetes (and packages) and enabling it"

    # Install Kubernetes
    sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
    
    # Start Kubernetes
    systemctl enable --now kubelet && sudo systemctl start kubelet
}

function run {
    basePackages
    docker
    k8sIPtables
    k8sRepo
    disables
    k8sInstallation
}

run
