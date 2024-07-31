## Install provider to existing kubernertes setup

- Hostname needs to change, please edit the HOSTNAME is the next step.
- KEY_SECRET is the secret for creating wallet so change it accordingly
- The `only-provier.sh` makes following changes:
  - Create spheron user
  - Create hostname
  - Install kubectl and helm
  - Install sphnctl
  - Download bid-script
  - Create spheron wallet using key-secret

```sh
git clone https://github.com/spheronFdn/provider-deployment.git
cd provider-deployment/scripts
```

```sh
export HOSTNAME=provider.testnetbsphn.xyz
export KEY_SECRET=testPassword
chmod +x only-provider.sh
./only-provider.sh # you need to run this with root previledge access.
```

## Change your user to spheron user

```sh
sudo su spheron
```

## Provider Config

[Refer to the step mentioned in the doc](https://docs.spheron.network/providers/setup-provider#create-provider-configuration)

## Register Provider

Registering provider will be done on spheron user since that where we created the wallet and have the wallet private key.

[Refer to the step mentioned in the doc](https://docs.spheron.network/providers/setup-provider#registering-a-provider) to register you provider to Spheron network onchain.

## Provider Attributes

[Refer to the step mentioned in the doc](https://docs.spheron.network/providers/setup-provider#set-provider-attributes) to set the CPU and GPU resources for spheron rewards.

## Move kube config to spheron user

Now you need to come back to your user which have the kube access.

```sh
sudo su
```

Setup kubeconfig for spheron user.

```sh
sudo mkdir -p /home/spheron/.kube
sudo cp /root/.kube/config /home/spheron/.kube/kubeconfig
sudo chown -R spheron:spheron /home/spheron/.kube
export KUBECONFIG=/home/spheron/.kube/kubeconfig
```

## Setup Enviroment

[Refer to the step mentioned in the doc](https://docs.spheron.network/providers/setup-provider#setup-environment)

## Ingress Setup

Note: If you are running k3s please disable traefik and servicelb

[Refer to the step mentioned in the doc](https://docs.spheron.network/providers/setup-provider#set-provider-attributes)

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

```sh
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

```sh
kubectl apply -f gpu-test-pod.yaml
echo "Waiting 60 seconds for the test pod to start..."
sleep 60
kubectl get pods -A -o wide
kubectl logs nbody-gpu-benchmark
kubectl delete pod nbody-gpu-benchmark
```

## Install provider using helm charts

We will be using provider helm chart for installation.

```sh
export HOSTNAME=provider.testnetbsphn.xyz
export KEY_SECRET=testPassword
cd /home/spheron/provider-helm-charts/charts
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

```sh
helm upgrade --install spheron-hostname-operator ./spheron-hostname-operator -n spheron-services
helm upgrade --install inventory-operator ./spheron-inventory-operator -n spheron-services
```

## Verify GPU Labels

Let the installation settle and wait for few minutes
Verify labels on the nodes

```sh
kubectl get nodes
kubectl describe node [Node Name] | grep -A20 Labels
```

## Check status

Using following command check status of the provider

```sh
curl --insecure https://[hostname]:8443/status
```

You can also look up your provider on our [Provider Dashboard](https://provider.spheron.network) to check if your era uptime is up to the mark. Additionally, you can withdraw your earnings and view your provider's tier and the rewards you are accruing.

### Acknowledgement

This project incorporates code from [AkashOS](https://github.com/cryptoandcoffee/akashos), created by [Andrew Mello](https://github.com/88plug), which is licensed under the GNU General Public License v3.0 (GPLv3). The full text of the GPL3 license can be found in the LICENSE file in this repository. We thank the author for the efforts and dedication to creating this setup script.
