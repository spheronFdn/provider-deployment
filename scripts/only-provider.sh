#!/bin/bash
echo "Creating spheron user"
sudo useradd -m -s /bin/bash spheron
sudo usermod -aG sudo spheron
echo 'spheron ALL=(ALL) NOPASSWD:ALL' | tee -a /etc/sudoers
# update hostname
echo "Changing host name to $HOSTNAME"
sudo hostnamectl set-hostname $HOSTNAME
echo "Installing kubectl and helm"
sudo snap install kubectl --classic ; snap install helm --classic

echo "Installing latest sphnctl"
wget -O install.sh https://sphnctl.sh
chmod +x install.sh
./install.sh
echo "Spheorn CLI Installed Version     : $(sphnctl version)"

echo "Downloading bidscript"
wget -O /home/spheron/bidscript.sh https://spheron-release.s3.amazonaws.com/scripts/bidscript.sh

echo "Creating Wallet"
mkdir -p /home/spheron/.spheron
sphnctl wallet create --name wallet --key-secret $KEY_SECRET
sudo cp /root/.spheron/wallet.json /home/spheron/.spheron/wallet.json
sudo cp /root/.spheron/config.json /home/spheron/.spheron/config.json
sudo chown -R spheron:spheron /home/spheron/.spheron





