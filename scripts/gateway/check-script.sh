#!/bin/bash

# Curl the status endpoint and store the response
response=$(curl --silent --insecure https://localhost:8443/status)

# Use jq to check if inventory.available.nodes array is empty
# Returns true if empty, false if has elements
is_empty=$(echo "$response" | jq -r '.cluster.inventory.available.nodes | length == 0')

if [ "$is_empty" = "true" ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    kubectl rollout restart statefulset/spheron-provider -n spheron-services        
    kubectl rollout restart deployment operator-inventory -n spheron-services
else
    echo "Inventory nodes array has $(echo "$response" | jq '.cluster.inventory.available.nodes | length') node(s)"
    exit 0
fi

    