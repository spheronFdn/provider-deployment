#!/bin/bash
#To be run on a single k3s node - to get the base spheron provider software installed.
mkdir -p  /home/spheron/logs/installer
echo "Install logs are available in /home/spheron/logs/installer if anything breaks"

function user_input(){

while true; do
    clear
    read -p "Is this setup for the first node/machine in the cluster? (y/n, default: y): " choice

    case "$choice" in
        n|N ) 
            CLIENT_NODE_=true
            echo "Client node setup selected."
            sleep 2
            break
            ;;
        y|Y ) 
            CLIENT_NODE_=false
            echo "Initial setup for spheron-node1 selected."
            sleep 2
            break
            ;;
        * )
            echo "Invalid entry. Please enter 'y' for client node or 'n' for initial setup."
            sleep 2
            ;;
    esac
done

if [[ $CLIENT_NODE_ == true ]]; then
    while true; do
        clear
        read -p "Enter the hostname to use for this additional node (default: spheron-node2): " CLIENT_HOSTNAME_
        
        if [[ -z $CLIENT_HOSTNAME_ ]]; then
            CLIENT_HOSTNAME_="spheron-node2"
        fi
        
        read -p "Are you sure the hostname is correct? ($CLIENT_HOSTNAME_) (y/n): " choice
        
        case "$choice" in
            y|Y ) 
                break
                ;;
            n|N ) 
                echo "Please try again."
                sleep 2
                ;;
            * ) 
                echo "Invalid entry. Please enter 'y' for yes or 'n' for no."
                sleep 2
                ;;
        esac
    done
fi

if [[ $CLIENT_NODE_ == true ]]; then
    read -p "Do you want to attempt to automatically join the client node to the server node? (y/n): " choice
    if [[ "$choice" =~ ^[yY]$ ]]; then
        while true; do
            read -p "What is the IP address of spheron-node1? : " SPHERON_NODE_1_IP
            
            read -p "Are you sure the IP address of spheron-node1 is correct? (Current: $SPHERON_NODE_1_IP) (y/n): " confirm
            case "$confirm" in
                [yY] )
                    while true; do
                        read -p "Should this node be a control plane or an agent? (c/a): " node_type
                        case "$node_type" in
                            [cC] )
                                NODE_TYPE="control_plane"
                                break
                                ;;
                            [aA] )
                                NODE_TYPE="agent"
                                break
                                ;;
                            * )
                                echo "Invalid entry. Please enter 'c' for control plane or 'a' for agent."
                                sleep 2
                                ;;
                        esac
                    done
                    break
                    ;;
                [nN] )
                    echo "Please try again."
                    sleep 2
                    ;;
                * )
                    echo "Invalid entry. Please enter 'y' for yes or 'n' for no."
                    sleep 2
                    ;;
            esac
        done
    else
        echo "Continuing without automatically joining the client node to the server node."
    fi
fi

# if [[ $CLIENT_NODE_ == "false" ]]; then
#   # Check if the user has an Spheron wallet
#   while true; do
#     clear
#     read -p "Do you have an Spheron wallet with at least 50 SPH and the mnemonic phrase available? (y/n, default: n): " choice

#     case "$choice" in
#         y|Y ) 
#             NEW_WALLET_=false
#             break
#             ;;
#         n|N ) 
#             echo "New wallet required during setup."
#             NEW_WALLET_=true
#             sleep 2
#             break
#             ;;
#         * )
#             echo "Invalid entry. Please enter 'y' for yes or 'n' for no."
#             sleep 2
#             ;;
#     esac
#   done

#   # Import key if the user knows it
#   if [[ $NEW_WALLET_ == "false" ]]; then
#     while true; do
#       clear
#       read -p "Enter the mnemonic phrase to import your provider wallet (e.g., KING SKI GOAT...): " mnemonic_

#       read -p "Are you sure the wallet mnemonic is correct? ($mnemonic_) (y/n): " choice
        
#       case "$choice" in
#           y|Y ) 
#               break
#               ;;
#           n|N ) 
#               echo "Please try again."
#               sleep 2
#               ;;
#           * ) 
#               echo "Invalid entry. Please enter 'y' for yes or 'n' for no."
#               sleep 2
#               ;;
#       esac
#     done
#   fi

#   # End of client node check
# fi

# GPU Support
if lspci | grep -q NVIDIA; then
  while true; do
    clear
    read -p "NVIDIA GPU Detected: Would you like to enable it on this host? (y/n, default: y): " GPU_
    
    read -p "Are you sure you want to enable GPU support? ($GPU_) (y/n): " choice
    
    case "$choice" in
        y|Y ) 
            GPU_=true
            break
            ;;
        n|N ) 
            echo "Skipping GPU support."
            GPU_=false
            sleep 3
            break
            ;;
        * )
            echo "Invalid entry. Please enter 'y' for yes or 'n' for no."
            sleep 3
            ;;
    esac
  done
fi

if [[ $CLIENT_NODE_ == "false" ]]; then
  # Domain is required
  while true; do
    clear
    read -p "Enter the domain name to use for your provider (example.com): " DOMAIN_
    
    read -p "Are you sure the provider domain is correct? ($DOMAIN_) (y/n): " choice
    
    case "$choice" in
        y|Y ) 
            break
            ;;
        n|N ) 
            echo "Please try again."
            sleep 2
            ;;
        * )
            echo "Invalid entry. Please enter 'y' for yes or 'n' for no."
            sleep 2
            ;;
    esac
  done

  # End of client_node mode check
fi
}

echo "Just a few questions..."
# Never log
user_input 


clear
echo ""
echo "Sit back and relax - this could take a few minutes or up to an hour depending on your hardware, connection, and choices." 
echo ""

#Store securely for user
KEY_SECRET_=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-32};echo;)



function depends(){
export DEBIAN_FRONTEND=noninteractive
apt-get -o Acquire::ForceIPv4=true update
DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -yqq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

snap install kubectl --classic ; snap install helm --classic
#Disable sleep
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
#Disable IPv6
sed -i -e 's/GRUB_CMDLINE_LINUX_DEFAULT="maybe-ubiquity"/GRUB_CMDLINE_LINUX_DEFAULT="ipv6.disable=1 maybe-ubiquity"/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
#Fast reboots
sed -i -e 's/#DefaultTimeoutStopSec=90s/DefaultTimeoutStopSec=5s/' /etc/systemd/system.conf
systemctl daemon-reload
}
echo "☸️ Updating Ubuntu"
depends &>> /home/spheron/logs/installer/depends.log

function gpu(){
if lspci | grep -q NVIDIA; then
echo "Install NVIDIA"
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/libnvidia-container/gpgkey | apt-key add -
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | tee /etc/apt/sources.list.d/libnvidia-container.list
apt-get -o Acquire::ForceIPv4=true update
apt install ubuntu-drivers-common
apt-get install -y nvidia-cuda-toolkit nvidia-container-toolkit nvidia-container-runtime 

ubuntu-drivers autoinstall

mkdir -p /etc/rancher/k3/
cat > /etc/rancher/k3/config.yaml <<'EOF'
containerd_additional_runtimes:
  - name: nvidia
    type: "io.containerd.runc.v2"
    engine: ""
    root: ""
    options:
      BinaryName: '/usr/bin/nvidia-container-runtime'
EOF

fi
}

if [[ $GPU_ == "true" ]]; then
echo "☸️ Installing GPU : Patience is a virtue."
gpu &>> /home/spheron/logs/installer/gpu.log
else
echo "☸️ Skipping GPU"
fi

if [[ $CLIENT_NODE_ == "false" ]]; then

function k3sup_install(){
curl -LS https://get.k3sup.dev | sh
#OLD WAY
#LOCAL_IP=$(ip -4 addr show | grep enp* | grep -oP 'inet \K[\d.]+')
#New way compatible with VPS
LOCAL_IP=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1)
echo 'spheron ALL=(ALL) NOPASSWD:ALL' | tee -a /etc/sudoers
apt-get install -y sshpass
sudo -u spheron sshpass -p 'spheron' ssh-copy-id -i /home/spheron/.ssh/id_rsa.pub -o StrictHostKeyChecking=no spheron@$LOCAL_IP
sudo -u spheron sshpass -p 'spheron' ssh-copy-id -i /home/spheron/.ssh/id_rsa.pub -o StrictHostKeyChecking=no spheron@127.0.0.1
#sudo -u spheron k3sup install --cluster --user spheron --ip $LOCAL_IP --k3s-extra-args "--disable servicelb --disable traefik --disable metrics-server --disable-network-policy --flannel-backend=none"
sudo -u spheron k3sup install --cluster --user spheron --ip $LOCAL_IP --k3s-extra-args "--disable servicelb --disable traefik --disable metrics-server"
##Add additional server nodes with:
#k3sup join --server --server-ip 192.168.1.199 --server-user spheron --user spheron --ip 192.168.1.132 --k3s-extra-args "--disable servicelb --disable traefik --disable metrics-server --disable-network-policy --flannel-backend=none"

chmod 600 /etc/rancher/k3s/k3s.yaml
mkdir -p /home/spheron/.kube
# Not all apps use the new default of "config"
cp /etc/rancher/k3s/k3s.yaml /home/spheron/.kube/config
cp /etc/rancher/k3s/k3s.yaml /home/spheron/.kube/kubeconfig
chown spheron:spheron /etc/rancher/k3s/k3s.yaml
echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> /home/spheron/.bashrc
echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> /etc/profile
source /home/spheron/.bashrc
# Breaking if we do not wait!
echo "Waiting 15 seconds for k3s to settle..."
grep nvidia /var/lib/rancher/k3s/agent/etc/containerd/config.toml
sleep 15
} 
echo "☸️ Installing k3sup"
k3sup_install &>> /home/spheron/logs/installer/k3sup.log

chown -R spheron:spheron /home/spheron/.kube/

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

#Install Spheron and setup wallet
function install_spheron(){
wget  https://spheron-release.s3.amazonaws.com/bins/amd64/spheron
cp spheron /usr/local/bin/sphnctl
chmod +x /usr/local/bin/sphnctl
echo "Spheorn Version     : $(spheron version)"

echo "Downloading bid script"
wget -O /home/spheron/bidscript.sh https://spheron-release.s3.amazonaws.com/scripts/bidscript.sh

}
echo "🚀 Installing Spheron"
install_spheron &>> /home/spheron/logs/installer/spheron.log


function setup_wallet(){
# if [[ $NEW_WALLET_ == "true" ]]; then
KEY_SECRET=testPassword
mkdir -p /home/spheron/.spheron
sphnctl wallet create --name wallet --key-secret testPassword
cp /root/.spheron/wallet.json /home/spheron/.spheron/wallet.json
cp /root/.spheron/config.json /home/spheron/.spheron/config.json
chown -R spheron:spheron /home/spheron/.spheron
ACCOUNT_ADDRESS=/spheron-key/wallet.json
# fi
}

echo "💰 Creating wallet"
setup_wallet &>> /home/spheron/logs/installer/wallet.log
echo "🔑 Please save the memonic"
cat /home/spheron/logs/installer/wallet.log | grep mnemonic 

# if [[ $NEW_WALLET_ == "true" ]]; then
# MNEMONIC=$(awk '/forget your password./{getline; getline; print}' /home/akash/logs/installer/wallet.log)
# else
# MNEMONIC=$mnemonic_
# unset mnemonic_
# fi

# function check_wallet(){
# ACCOUNT_ADDRESS_=$(echo $KEY_SECRET_ | akash keys list | grep address | cut -d ':' -f2 | cut -c 2-)
# BALANCE=$(akash query bank balances --node https://akash-rpc.global.ssl.fastly.net:443 $ACCOUNT_ADDRESS_)
# MIN_BALANCE=50

# if (( $(echo "$BALANCE < 50" | bc -l) )); then
#   echo "Balance is less than 50 AKT - you should send more coin to continue."
#   echo "Found a balance of $BALANCE on the wallet $ACCOUNT_ADDRESS_"
# else
#   echo "Found a balance of $BALANCE on the wallet $ACCOUNT_ADDRESS_"
# fi
# sleep 5
# }
#check_wallet 

echo "DOMAIN=$DOMAIN_" > variables
echo "ACCOUNT_ADDRESS=$ACCOUNT_ADDRESS_" >> variables
echo "KEY_SECRET=$KEY_SECRET_" >> variables
# echo "CHAIN_ID=akashnet-2" >> variables
echo "HOST=sheron" >> variables
echo "REGION=$REGION_" >> variables
echo "CPU=$CPU_" >> variables
echo "UPLOAD=$UPLOAD_" >> variables
echo "DOWNLOAD=$DOWNLOAD_" >> variables
echo "KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> variables
echo "CPU_PRICE=" >> variables
echo "MEMORY_PRICE=" >> variables
echo "DISK_PRICE=" >> variables
# echo "MNEMONIC=\"$MNEMONIC\"" >> variables
# echo 'NODE="http://spheron-node-1:26657"' >> variables
 

function provider_install(){
echo "Installing Spheron provider and bid-engine"

if [[ $GPU_ == "true" ]]; then
echo "Found GPU, using testnet config!"
wget -q https://raw.githubusercontent.com/spheronFdn/provider-deployment/main/scripts/run-helm-k3s-gpu.sh
# wget -q https://raw.githubusercontent.com/cryptoandcoffee/akashos/main/bid-engine-script-gpu.sh
chmod +x run-helm-k3s-gpu.sh  
# chmod +x bid-engine-script-gpu.sh
mv run-helm-k3s-gpu.sh run-helm-k3s.sh
# mv bid-engine-script-gpu.sh bid-engine-script.sh
chown spheron:spheron *.sh
echo "Running Helm Provider install after first reboot to get nvidia-smi"
else
wget -q https://raw.githubusercontent.com/spheronFdn/provider-deployment/main/scripts/run-helm-k3s.sh
chmod +x run-helm-k3s.sh
chown spheron:spheron *.sh
sudo -u spheron ./run-helm-k3s.sh 
fi
}

# echo "🌐 Installing Spheron Provider and Node"
# provider_install &>> /home/spheron/logs/installer/provider.log
echo "❌ Automatic provider install is Disable"
echo "🌐 Follow the Doc for Spheron Provider Installation after Restart"

echo "🛡️ Creating firewall rules"
cat <<EOF > ./firewall-ports.txt
8443/tcp - for manifest uploads
80/tcp - for web app deployments
443/tcp - for web app deployments
30000-32767/tcp - for Kubernetes node port range for deployments
30000-32767/udp - for Kubernetes node port range for deployments
EOF

chown spheron:spheron *.sh
chown spheron:spheron *.txt
chown spheron:spheron variables


# End node client mode skip
fi

if [[ $CLIENT_NODE_ == true ]]; then
echo "CLIENT_NODE=true" >> variables
echo "CLIENT_HOSTNAME=$CLIENT_HOSTNAME_" >> variables
echo "SPHERON_NODE_1_IP=$SPHERON_NODE_1_IP_" >> variables
# Setup hostname for client node
hostnamectl set-hostname $CLIENT_HOSTNAME_
echo $CLIENT_HOSTNAME_ | tee /etc/hostname
sed -i "s/127.0.1.1 spheron-node1/127.0.1.1 $CLIENT_HOSTNAME_/g" /etc/hosts
else
echo "CLIENT_NODE=false" >> variables
echo "CLIENT_HOSTNAME=spheron-node1" >> variables
fi

echo "SETUP_COMPLETE=true" >> variables

echo "Setup Complete"
echo "Rebooting ..."
reboot now --force

#Add/scale the cluster with 'microk8s add-node' and use the token on additional nodes.
#Use 'microk8s enable dns:1.1.1.1' after you add more than 1 node.

#Todos:
# Add checkup after install/first start ( 
# Add watchdog to check for updates
# Rename "start-akash" for easy user access
# Convert to simple menu / GUI for easy of use
# Support additional methods, k3s/kubespray
