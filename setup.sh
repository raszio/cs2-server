#!/bin/bash

# Exit on error
set -e

echo "Starting CS2 Server Setup..."

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
else
    echo "Could not detect OS."
    exit 1
fi

case "$OS_ID" in
    ubuntu|debian)
        echo "Detected $OS_ID. Updating and installing dependencies..."
        sudo apt-get update
        sudo apt-get install -y git curl docker.io
        # Try to install compose via package manager
        sudo apt-get install -y docker-compose-v2 || sudo apt-get install -y docker-compose || echo "Package manager compose install failed, will try manual."
        ;;
    amzn)
        echo "Detected Amazon Linux. Updating and installing dependencies..."
        if command -v dnf >/dev/null 2>&1; then
            sudo dnf update -y
            sudo dnf install -y git curl docker
            # Try both common names for compose on AL2023
            sudo dnf install -y docker-compose || sudo dnf install -y docker-compose-plugin || echo "DNF compose install failed."
        else
            sudo yum update -y
            sudo yum install -y git curl docker
        fi
        ;;
    *)
        echo "Unsupported OS: $OS_ID"
        exit 1
        ;;
esac

# Start and enable Docker early to ensure we can test for compose
echo "Enabling and starting Docker service..."
sudo systemctl enable docker
sudo systemctl start docker

# Check if docker compose (v2) or docker-compose (v1/v2) is available
if docker compose version >/dev/null 2>&1; then
    echo "Docker Compose (v2) is already installed."
elif docker-compose version >/dev/null 2>&1; then
    echo "Docker-compose is already installed."
else
    echo "Docker Compose not found. Installing manually from GitHub..."
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    # Create a symbolic link so 'docker compose' works if the binary is in /usr/local/bin/docker-compose
    sudo mkdir -p /usr/local/lib/docker/cli-plugins
    sudo ln -sf /usr/local/bin/docker-compose /usr/local/lib/docker/cli-plugins/docker-compose
fi

# Add user to docker group to run without sudo
echo "Adding user $USER to docker group..."
sudo usermod -aG docker "$USER"

# Clone the repository into the home folder
echo "Cloning the CS2 server repository to ~/cs2-server..."
if [ -d "$HOME/cs2-server" ]; then
    echo "Directory ~/cs2-server already exists. Skipping clone."
else
    git clone https://github.com/raszio/cs2-server.git "$HOME/cs2-server"
fi

# Copy .env.example to .env
if [ -f "$HOME/cs2-server/.env.example" ]; then
    echo "Copying .env.example to .env..."
    cp "$HOME/cs2-server/.env.example" "$HOME/cs2-server/.env"
else
    echo "Warning: .env.example not found in ~/cs2-server"
fi

echo "--------------------------------------------------------"
echo "Setup finished successfully!"
echo "IMPORTANT: You MUST log out and log back in for the 'docker' group changes to take effect."
echo "Alternatively, run: newgrp docker"
echo "--------------------------------------------------------"
echo "To start your server:"
echo "1. cd ~/cs2-server"
echo "2. Edit .env file if necessary"
echo "3. Run 'docker compose up -d' (or 'docker-compose up -d' on older systems)"
echo "--------------------------------------------------------"
