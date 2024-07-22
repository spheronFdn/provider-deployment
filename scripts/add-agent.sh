#!/bin/bash

# This setup guide includes some contributions from Andrew.
# We thank the author for the efforts and dedication to creating this setup script.

#Control plane
SPHERON_NODE1_IP=134.195.196.81

# Node definitions
declare -A nodes

nodes=(
    ["spheron-node2"]="134.195.196.213"
)



# Password
password="spheron"

# Your public key file
public_key_file="$HOME/.ssh/id_rsa.pub"
public_key=$(cat "$public_key_file")

# SSH Options
ssh_options="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# Copy SSH keys and display hostname
for hostname in "${!nodes[@]}"; do
  ip=${nodes[$hostname]}
  echo "Processing $hostname ($ip)..."

  # Check if the key already exists
  exists=$(sshpass -p "$password" ssh $ssh_options "spheron@$ip" "grep -F '$public_key' ~/.ssh/authorized_keys" 2>/dev/null)

  # If the key does not exist, copy it
  if [ -z "$exists" ]; then
    echo "Adding new key to $hostname ($ip)..."
    sshpass -p "$password" ssh-copy-id $ssh_options "spheron@$ip" 2>/dev/null
  else
    echo "Key already exists on $hostname ($ip). Skipping..."
  fi

  function join_agent(){
    k3sup join --user spheron --ip $ip --server-ip $SPHERON_NODE1_IP --server-user spheron
  }
  join_agent

done