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
        sudo apt-get upgrade -y
        sudo apt-get install -y git curl docker.io docker-compose-v2
        ;;
    amzn)
        echo "Detected Amazon Linux. Updating and installing dependencies..."
        # Check if dnf is available (AL2023) or yum (AL2)
        if command -v dnf >/dev/null 2>&1; then
            sudo dnf update -y
            sudo dnf install -y git curl docker docker-compose
        else
            sudo yum update -y
            sudo yum install -y git curl docker
            # For AL2, we might need to install docker-compose manually
            sudo systemctl start docker
            sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            sudo chmod +x /usr/local/bin/docker-compose
        fi
        ;;
    *)
        echo "Unsupported OS: $OS_ID"
        echo "This script supports Ubuntu, Debian, and Amazon Linux."
        exit 1
        ;;
esac

# Start and enable Docker
echo "Enabling and starting Docker service..."
sudo systemctl enable docker
sudo systemctl start docker

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
