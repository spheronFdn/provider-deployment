#! /bin/bash

SPHERON_FROM=.spheron/wallet.json
SPHERON_HOME=.spheron
SPHERON_KEY_SECRET=testPassword
SPHERON_WS_PORT=8544
SPHERON_API_PORT=8543
SPHERON_BID_PRICE_STRATEGY=shellScript
SPHERON_BID_PRICE_SCRIPT_PATH=.spheron/bidscript.sh
SPHERON_DEPLOYMENT_RUNTIME_CLASS=none


clear
Get the operating system
OS=$(uname -s)

# Check if OS is Linux, exit if not
if [ "$OS" != "Linux" ]; then
    echo "This script only works on Linux systems"
    exit 1
fi

wget -O ~/.spheron/bidscript.sh https://spheron-release.s3.amazonaws.com/scripts/bidscript.sh


install_docker_and_compose() {
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        echo "Docker is not installed. Installing Docker..."
        
        case $OS in
            linux)
                if [ -f /etc/os-release ]; then
                    . /etc/os-release
                    case $ID in
                        ubuntu|debian)
                            sudo apt-get update
                            sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
                            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
                            sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
                            sudo apt-get update
                            sudo apt-get install -y docker-ce docker-ce-cli containerd.io
                            ;;
                        fedora)
                            sudo dnf -y install dnf-plugins-core
                            sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
                            sudo dnf install -y docker-ce docker-ce-cli containerd.io
                            ;;
                        centos|rhel)
                            sudo yum install -y yum-utils
                            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
                            sudo yum install -y docker-ce docker-ce-cli containerd.io
                            ;;
                        *)
                            echo "Unsupported Linux distribution for automatic Docker installation."
                            echo "Please install Docker manually for your distribution."
                            exit 1
                            ;;
                    esac
                    
                    # Start and enable Docker service
                    sudo systemctl start docker
                    sudo systemctl enable docker
                    
                    # Add current user to docker group
                    sudo usermod -aG docker $USER
                    echo "You may need to log out and back in for the group changes to take effect."
                else
                    echo "Unable to determine Linux distribution. Please install Docker manually."
                    exit 1
                fi
                ;;
            
            *)
                echo "Unsupported operating system for automatic Docker installation."
                exit 1
                ;;
        esac
    else
        echo "Docker is already installed."
    fi

    # Check if Docker Compose is installed
    if ! command -v docker-compose &> /dev/null; then
        echo "Docker Compose is not installed. Installing Docker Compose..."
        
        case $OS in
            macos)
                echo "Docker Compose is included with Docker for Mac. No additional installation needed."
                ;;
            
            linux)
                sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
                sudo chmod +x /usr/local/bin/docker-compose
                ;;
            
            *)
                echo "Unsupported operating system for automatic Docker Compose installation."
                exit 1
                ;;
        esac
    else
        echo "Docker Compose is already installed."
    fi

    # Verify installations
    docker --version
    docker-compose --version
}

create_docker_compose() {
    # Create docker-compose.yml
    cat > ~/.spheron/gateway/docker-compose.yml << EOL
services:
  spheron-gateway:
    image: spheronnetwork/gateway:latest-arm64
    container_name: spheron-gateway
    restart: always
    ports:
      - "8543:8543"
      - "8553:8553"
      - "8544:8544"
      - "20000-22000:20000-22000"
    environment:
      - SPHERON_FROM=$SPHERON_FROM
      - SPHERON_HOME=$SPHERON_HOME
      - SPHERON_KEY_SECRET=$SPHERON_KEY_SECRET
      - SPHERON_WS_PORT=$SPHERON_WS_PORT
      - SPHERON_API_PORT=$SPHERON_API_PORT
      - SPHERON_BID_PRICE_STRATEGY=$SPHERON_BID_PRICE_STRATEGY
      - SPHERON_BID_PRICE_SCRIPT_PATH=$SPHERON_BID_PRICE_SCRIPT_PATH
      - SPHERON_DEPLOYMENT_RUNTIME_CLASS=$SPHERON_DEPLOYMENT_RUNTIME_CLASS
      - PROXY_PORT=8553
      - PROXY_PORT_START=20000
      - PROXY_PORT_END=22000
    volumes:
      - ~/.spheron:/.spheron
    command: >
      provider-services run
      --from=$SPHERON_FROM
      --home=$SPHERON_HOME
      --key-secret=$SPHERON_KEY_SECRET
      --wsport=$SPHERON_WS_PORT
      --gateway-listen-address=0.0.0.0:$SPHERON_API_PORT
      --bid-price-strategy=$SPHERON_BID_PRICE_STRATEGY
      --bid-price-script-path=$SPHERON_BID_PRICE_SCRIPT_PATH
      --deployment-runtime-class=$SPHERON_DEPLOYMENT_RUNTIME_CLASS
EOL

    echo "Docker Compose file created at ~/.spheron/gateway/docker-compose.yml"
}

get_docker_compose_command() {
    if command -v docker-compose &>/dev/null; then
        echo "docker-compose"
    elif docker compose version &>/dev/null; then
        echo "docker compose"
    else
        echo ""
    fi
}

# Add this after install_docker_and_compose()
install_docker_and_compose


DOCKER_COMPOSE_CMD=$(get_docker_compose_command)
if [ -z "$DOCKER_COMPOSE_CMD" ]; then
    echo "Error: Neither 'docker-compose' nor 'docker compose' is available."
    exit 1
fi

# Check if the docker-compose.yml file exists
if [ -f ~/.spheron/gateway/docker-compose.yml ]; then
    echo "Stopping any existing Gateway containers..."
    $DOCKER_COMPOSE_CMD -f ~/.spheron/gateway/docker-compose.yml down
    $DOCKER_COMPOSE_CMD -f ~/.spheron/gateway/docker-compose.yml rm 
else
    echo "No existing Gateway configuration found. Skipping container cleanup."
fi

create_docker_compose



echo "Starting Gateway..."
$DOCKER_COMPOSE_CMD  -f ~/.spheron/gateway/docker-compose.yml up -d --force-recreate
echo ""
echo "============================================"
echo "Gateway Is Installed and Running successfully"
echo "============================================"
echo ""
echo "To fetch the logs, run:"
echo "$DOCKER_COMPOSE_CMD -f ~/.spheron/gateway/docker-compose.yml logs -f"
echo ""
echo "To stop the service, run:"
echo "$DOCKER_COMPOSE_CMD -f ~/.spheron/gateway/docker-compose.yml down"
echo "============================================"
echo "Thank you for installing Gateway! 🎉"
echo "============================================"
echo ""
echo "Gateway logs:"
$DOCKER_COMPOSE_CMD -f ~/.spheron/gateway/docker-compose.yml logs -f




