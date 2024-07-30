## Install provider to existing kubernertes setup


- Hostname needs to chnage, please edit the HOSTNAME is the next step.
- KEY_SECRET is the secret for creating wallet so change it accordingly
- The `only-provier.sh` makes following changes:
    - Create spheron user
    - Create hostname
    - Install kubectl and helm
    - Install sphnctl
    - Download bid-script
    - Create spheron wallet using key-secret


```shell
export HOSTNAME=provider.spheron.com
export KEY_SECRET=walletKeySecret
chmod +x only-provider.sh
sudo ./only-provider.sh
```

## Provider Config

[Link](https://docs.spheron.network/providers/setup-provider#create-provider-configuration)

## Register Provider

[Link](https://docs.spheron.network/providers/setup-provider#registering-a-provider)

## Provider Attributes

 [Link](https://docs.spheron.network/providers/setup-provider#set-provider-attributes)

## Move kube config to spheron user

Setup kubeconfig for spheron user

```
sudo mkdir -p /home/spheron/.kube 
sudo cp /root/.kube/config /home/spheron/.kube/kubeconfig
sudo chown -R spheron:spheron /home/spheron/.kube
export KUBECONFIG=/home/spheron/.kube/kubeconfig 
``` 

## Setup Enviroment

[Link](https://docs.spheron.network/providers/setup-provider#set-provider-attributes)

## Ingress

[text](https://docs.spheron.network/providers/setup-provider#set-provider-attributes)

## Install nvidia-device-plugin 

This step assumes you already have GPU setup(nvidia-smi, nvidia-drivers, cudaruntime..)

Note: Install only if it is not installed

```shell
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm repo add nvdp https://nvidia.github.io/k8s-device-plugin

helm repo update


# Create NVIDIA RuntimeClass
cat > /home/spheron/gpu-nvidia-runtime-class.yaml <<EOF
kind: RuntimeClass
apiVersion: node.k8s.io/v1
metadata:
  name: nvidia
handler: nvidia
EOF

kubectl apply -f /home/spheron/gpu-nvidia-runtime-class.yaml

helm upgrade -i nvdp nvdp/nvidia-device-plugin \
  --namespace nvidia-device-plugin \
  --create-namespace \
  --version 0.14.5 \
  --set runtimeClassName="nvidia"
```

### Create a GPU test pod 

We will create a test pod to check if nvidia-runtime configured correctly

```shell
cat > gpu-test-pod.yaml << EOF
apiVersion: v1
kind: Pod
metadata:
  name: nbody-gpu-benchmark
  namespace: default
spec:
  restartPolicy: OnFailure
  runtimeClassName: nvidia
  containers:
  - name: cuda-container
    image: nvcr.io/nvidia/k8s/cuda-sample:nbody
    args: ["nbody", "-gpu", "-benchmark"]
    resources:
      limits:
        nvidia.com/gpu: 1
    env:
    - name: NVIDIA_VISIBLE_DEVICES
      value: all
    - name: NVIDIA_DRIVER_CAPABILITIES
      value: all
EOF
```

```shell
kubectl apply -f gpu-test-pod.yaml
echo "Waiting 60 seconds for the test pod to start..."
sleep 60
kubectl get pods -A -o wide
kubectl logs nbody-gpu-benchmark
kubectl delete pod nbody-gpu-benchmark
```

## Install provider using helm charts

We will be using provider helm chart for installation.

```shell
export KEY_SECRET=walletKeySecret
git clone https://github.com/spheronFdn/provider-helm-charts
cd provider-helm-charts/charts
REGION=$(jq -r '.region' /home/spheron/.spheron/provider-config.json)
DOMAIN=$(jq -r '.hostname' /home/spheron/.spheron/provider-config.json)
helm upgrade --install spheron-provider ./spheron-provider -n spheron-services \
        --set from=/spheron-key/wallet.json \
        --set keysecret=$KEY_SECRET \
        --set domain=$DOMAIN \
        --set bidpricestrategy=shellScript \
        --set bidpricescript="$(cat /home/spheron/bidscript.sh | openssl base64 -A)" \
        --set ipoperator=false \
        --set node=spheron \
        --set log_restart_patterns="rpc node is not catching up|bid failed" \
        --set resources.limits.cpu="2" \
        --set resources.limits.memory="2Gi" \
        --set resources.requests.cpu="1" \
        --set resources.requests.memory="1Gi"
        
kubectl patch configmap spheron-provider-scripts \
      --namespace spheron-services \
      --type json \
      --patch='[{"op": "add", "path": "/data/liveness_checks.sh", "value":"#!/bin/bash\necho \"Liveness check bypassed\""}]'

kubectl rollout restart statefulset/spheron-provider -n spheron-services        
```

## Install Operators

Install inventory and hostname operator

```shell
helm upgrade --install spheron-hostname-operator ./spheron-hostname-operator -n spheron-services
helm upgrade --install inventory-operator ./spheron-inventory-operator -n spheron-services
```

## Verify GPU Labels

Let the installation settle and wait for few minutes
Verify labels on the nodes

```shell
kubectl get nodes
kubectl describe node [Node Name] | grep -A20 Labels
```


## Check status

Using following command check status of the provider

```shell
curl --insecure https://[hostname]:8443/status
```


