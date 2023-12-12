#!/bin/bash

# Set variables
export APP_ID=424585
export INSTALLATION_ID=44308097
export PRIVATE_KEY_FILE_PATH=~/ARC-Install/ARCsecret.pem

# Update apt and apt-get
sudo apt update -y
sudo apt-get update -y

# Install Brew
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && (echo; echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"') >> /home/ubuntu/.profile && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Check if Helm is installed and install it if not
brew install kubectl helm

# Check if Docker is installed and install it if not
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Installing..."
    # Add Docker's official GPG key:
    sudo apt-get install ca-certificates curl gnupg -y
    sudo install -m 0755 -d /etc/apt/keyrings 
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # Add the repository to Apt sources:
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -y
    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
    # Test Docker installation
    sudo docker run hello-world
else
    echo "Docker is already installed."
fi

# Update kubeconfig
if [ ! -d "~/.kube" ]; then
    echo "Creating ~/.kube directory..."
    mkdir ~/.kube
else
    echo "~/.kube directory already exists."
fi

cp config ~/.kube/.
export KUBECONFIG=~/.kube/config

# Clone ARC values charts
#git clone https://github.com/Fuhsiion/ARC-Install.git && cd ARC-Install
#git clone https://github.com/stackhpc/ARC-Installer.git

# Create a new namespace
kubectl create namespace arc-runners

# Create a kubectl secret for the GitHub App
kubectl create secret generic arc-secret  --namespace=arc-runners  --from-literal=github_app_id=${APP_ID} --from-literal=github_app_installation_id=${INSTALLATION_ID} --from-file=github_app_private_key=${PRIVATE_KEY_FILE_PATH}

# Install ARC controller
helm upgrade --install arc --namespace arc-systems --create-namespace -f ARC-Install/arc-configuration/controller/values.yaml oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller

# Install ARC runners looping over directories whos name starts with runner-scale-set in ARC-Install/arc-configuration/ using the values.yaml found in the corresponding runner-scale-set directory
for d in ARC-Install/arc-configuration/runner-scale-set*; do
    helm upgrade --install arc-runner-${d##*/} --namespace arc-systems --create-namespace -f $d/values.yaml oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set
done

