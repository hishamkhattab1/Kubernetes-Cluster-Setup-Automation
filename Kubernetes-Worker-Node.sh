#!/bin/bash

# THE REPO NEED TO BE UPDATED !!!!!!!!!!!!!!!!!

# STEP 1: Install Containerd
#--------------------------------
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf makecache -y
sudo dnf install -y containerd.io
sudo mv /etc/containerd/config.toml /etc/containerd/config.toml.bak

# Create the containerd configuration file
sudo containerd config default > config.toml

# Modify the SystemdCgroup field to true
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' config.toml

# Move the modified configuration file to the /etc/containerd directory
sudo mv config.toml /etc/containerd/config.toml

# Restart containerd to apply the changes
sudo systemctl enable --now containerd

# Add Container Runtime
sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter
sudo sysctl --system

# STEP 2: Modify SELinux and Firewall Settings and disable swap
#---------------------------------------------------------------------------
# Disable SELinux & Swap
sudo setenforce 0
sudo sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config
sudo sed -i '/swap/s/^/#/' /etc/fstab
sudo swapoff -a

# Firewall Configuration for Worker Node
sudo firewall-cmd --add-port={10250,30000-32767,5473,179}/tcp --permanent
sudo firewall-cmd --add-port={4789,8285,8472}/udp --permanent
sudo firewall-cmd --reload

# STEP 3: Configure Network
#----------------------------------
# CONFIGURE NETWORK
sudo tee /etc/sysctl.d/k8s.conf <<EOF
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

# STEP 4: Install Kubernetes Tools and Initiate the cluster
#-------------------------------------------------------------------

# Install Kubelet, Kubeadm & Kubectl
sudo tee /etc/yum.repos.d/kubernetes.repo <<EOF
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
EOF

dnf install -y {kubelet,kubeadm,kubectl} --disableexcludes=kubernetes

# Enable and Start Kubelet and Containerd
sudo systemctl enable kubelet && sudo systemctl start kubelet
sudo systemctl enable containerd && sudo systemctl start containerd

source ./kubernetes-worker-node-vars.sh

kubeadm join $MASTER_IP --token $TOKEN --discovery-token-ca-cert-hash $DISCOVERY_TOKEN_CA_CERT_HASHR
