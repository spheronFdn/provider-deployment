#!/bin/bash

cd /home/spheron
if [ -f variables ]; then 
source /home/spheron/variables
fi

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Delete all the old files
cleanup_bootstrap() {
    if [ -f ./*bootstrap.sh ]; then
        echo "Found old installers - cleaning up"
        rm ./k3s-bootstrap.sh 2>/dev/null
    fi
}

# Fetch the new k3 bootstarp script and execute it
run_bootstrap() {
    wget -q --no-cache "https://raw.githubusercontent.com/spheronFdn/provider-deployment/main/scripts/k3s-bootstrap.sh"
    chmod +x "k3s-bootstrap.sh"
    echo "No setup detected! Enter the default password 'spheron' to start the spheron installer"
    sudo "./k3s-bootstrap.sh"
}

main() {
    cleanup_bootstrap
    if [ ! -f variables ]; then
        run_bootstrap
    else
        source variables
        if [[ $SETUP_COMPLETE == true ]]; then
            export KUBECONFIG=/home/spheron/.kube/kubeconfig
            echo "Variables file detected - Setup complete."
        fi
    fi
}

# Execute the main function
main
