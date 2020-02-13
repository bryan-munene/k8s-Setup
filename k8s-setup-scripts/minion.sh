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
    ###                 EXECUTED IN THE WORKER NODE                                 ###
    ###                                                                             ###
    ###################################################################################


function joinCluster {
    info "Adding the node to the cluster"
    # Run the join command generated from the `kubeadm init` command executed in the master pod.
    # sudo kubeadm token create --print-join-command -- incase you lost the join command

    # Run this command in the master node to confirm that the worker node has been added to the cluster successfully.
    kubectl get nodes -o wide
}

function run {
    joinCluster
}

run
