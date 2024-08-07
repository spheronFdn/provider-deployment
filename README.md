# Setup Provider
## Setup a new provider
### Get instance up and running
#### Init
- Get a bare metal server with any configuration
- Setup proper ssh with the server

#### Run Ansible to set things up 
- Edit the servers ip in inventory.ini file 
- Edit the hostname as per the preference for ex: provider.spheron.com
- Run Ansible playbook  
    ```
    ansible-playbook -i inventory.ini playbook.yml
    ```
This ansible scripts will create a user named with spheron, will fetch some of the scripts and setup them up for execution on the startup 


#### Install the stuff for the fisrt node
- Ssh into the server after the restart
- Now we will get prompts and we have to follow them.
- Say yes for the cluster first node
- Now keep following the prompt it will ask for domain, then ip consifuration (choose static ip), and finally it will update and install some scripts and restart again, this setup will install k3s, create spheron wallet if existing wallet not seleted (this might nor work) and some other things

- First time the provider pod will crash because we have not registered the provider to the chain to do that, ssh into the master node and run spheorn add provider command

    ```
    spheron provider add --from ~/.spheron/wallet.json --key-secret testPassword --region us-east --payment-token "USDTT" --domain provider.devnetasphn.com --attributes "region=us-east" 
    ```
- Now restart the provider pod it should be working
- Check status using
    ```
        curl --insecure https://provider.devnetasphn.com:8443/status
    ```    


#### If you are adding node to the cluster
- At the first prompt it say no to the first node
- Prompt will ask for the master node ip and some other details follow it.
- After this is will execute some scripts and restart the server
- Now ssh into to the master node and perform following actions
    ```
    sudo su spheron
    cd ~/
    ## download the add agent script url might change
    wget -q https://raw.githubusercontent.com/spheronFdn/provider-deployment/devnet/scripts/add-agent.sh
    
    ## edit the master ip and the client node ip in the script and run it
    chmod +x add-agent.sh
    ./add-agent.sh
    ## this will add the new node into the cluster.

    ```

- To check nodes is added successfully
    ```
    kubectl get nodes
    ```     

*Note*  : Make sure you copy the /home/spheron/.spheron/wallet.json from master node to the client node

This is requried for now becuase the the provider pod can get schdeuled to any node and it will fail if this thing is not done

## Enable GPU capabilities

*Note*: The scritps are not automated fully for GPU setup you we might have to do some manual things

- When we start setting up the provider or adding node, it will ask this server has gpu do you want to setup up say yes

- It will simply install some Nvidia drivers and other things and server will restart

- Now ssh into the server, we have to install and check some dependencies 
- Install or update driver 
    ```
    sudu apt update
    sudp apt install ubuntu-drivers-common
    sudo ubuntu-drivers autoinstall

    ```
- Now run this command
Expected/Example Output: 
    ``` 
    root@node1:~# ubuntu-drivers devices

    == /sys/devices/pci0000:00/0000:00:1e.0 ==
    modalias : pci:v000010DEd00001EB8sv000010DEsd000012A2bc03sc02i00
    vendor   : NVIDIA Corporation
    model    : TU104GL [Tesla T4]
    driver   : nvidia-driver-450-server - distro non-free
    driver   : nvidia-driver-418-server - distro non-free
    driver   : nvidia-driver-470-server - distro non-free
    driver   : nvidia-driver-515 - distro non-free
    driver   : nvidia-driver-510 - distro non-free
    driver   : nvidia-driver-525-server - distro non-free
    driver   : nvidia-driver-525 - distro non-free recommended
    driver   : nvidia-driver-515-server - distro non-free
    driver   : nvidia-driver-470 - distro non-free
    driver   : xserver-xorg-video-nouveau - distro free builtin
    ```

- Check for GPU model 
    ```
    nvidia-smi --query-gpu=gpu_name --format=csv,noheader

    Output:
    Tesla P4
    ```

- Setup labels for the node
    ```
    gpu_info="$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader)"

    echo "$gpu_info" | awk '{print tolower($2)}
    ```

*Note*: if the server have multiple gpu we have to add labels manually 

Labels looks like this 
    ```
    spheron.network/capabilities.gpu.vendor.nvidia.model.p4=1
    spheron.network/capabilities.gpu.vendor.nvidia.model.p4.interface.pcie=1
    spheron.network/capabilities.gpu.vendor.nvidia.model.p4.ram.8Gi=1
    ```

- Command to add labels

```
kubectl label node spheron-node2 spheron.network/capabilities.gpu.vendor.nvidia.model.p4=1
kubectl label node spheron-node2 spheron.network/capabilities.gpu.vendor.nvidia.model.p4.interface.PCIe=1
kubectl label node spheron-node2 spheron.network/capabilities.gpu.vendor.nvidia.model.p4.ram.8Gi=1

```

- Now on the master node and all other node to enable gpu container we have to create some config files 

```
## continerd k8 config
sudo cat <<EOF > /etc/rancher/k3/config.yaml
containerd_additional_runtimes:
  - name: nvidia
    type: "io.containerd.runc.v2"
    engine: ""
    root: ""
    options:
      BinaryName: '/usr/bin/nvidia-container-runtime'
EOF


```

- Now setup nvidia plugins
    ```
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

    # Install NVIDIA Device Plugin
    helm upgrade -i nvdp nvdp/nvidia-device-plugin \
        --namespace nvidia-device-plugin \
        --create-namespace \
        --set runtimeClassName="nvidia"
    ```

- Setup Basic enviroment
```
 kubectl create ns spheron-services
    kubectl label ns spheron-services spheron.network/name=spheron-services spheron.network=true
    kubectl create ns lease
    kubectl label ns lease spheron.network=true
    kubectl apply -f https://raw.githubusercontent.com/spheron-network/provider/main/pkg/apis/spheron.network/crd.yaml
```

- Install the ingress charts
```
    cat > ingress-nginx-custom.yaml << EOF
controller:
  service:
    type: ClusterIP
  ingressClassResource:
    name: "spheron-ingress-class"
  kind: DaemonSet
  hostPort:
    enabled: true
  admissionWebhooks:
    port: 7443
  config:
    allow-snippet-annotations: false
    compute-full-forwarded-for: true
    proxy-buffer-size: "16k"
  metrics:
    enabled: true
  extraArgs:
    enable-ssl-passthrough: true
tcp:
  "1317": "spheron-services/spheron-node-1:1317"
  "8443": "spheron-services/spheron-provider:8443"
  "9090":  "spheron-services/spheron-node-1:9090"
  "26656": "spheron-services/spheron-node-1:26656"
  "26657": "spheron-services/spheron-node-1:26657"
EOF
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
      --namespace ingress-nginx --create-namespace \
      -f ingress-nginx-custom.yaml

kubectl label ns ingress-nginx app.kubernetes.io/name=ingress-nginx app.kubernetes.io/instance=ingress-nginx
kubectl label ingressclass spheron-ingress-class spheron.network=true
``` 

- Install the provider and operators
```

git clone  https://github.com/spheronFdn/provider-helm-charts.git
cd provider-helm-charts/charts
git checkout devnet-spheron

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia

helm upgrade --install spheron-provider ./spheron-provider -n spheron-services \
        --set from=$ACCOUNT_ADDRESS \
        --set keysecret=$KEY_SECRET \
        --set domain=$DOMAIN \
        --set bidpricestrategy=randomRange \
        --set ipoperator=false \
        --set node=$NODE \
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

    helm upgrade --install spheron-hostname-operator ./spheron-hostname-operator -n spheron-services

    helm upgrade --install inventory-operator ./spheron-inventory-operator -n spheron-services


```
*Note*: Make sure to create provider with the gpu capabalities

```
spheron provider add --from ~/.spheron/wallet.json --key-secret testPassword --region us-east --payment-token "USDTT" --domain provider.devnetasphn.com --attributes "region=us-east,capabilities/gpu/vendor/nvidia/model/p4=true,capabilities/gpu/vendor/nvidia/model/p4/ram/8Gi=true" 
```


### Some Commands
- To Test Gpu deployment 
```
./spheron deployment create ../../_run/kube/deployment_gpu_big.yaml --from /Users/chetan/.spheron/wallet.json --key-secret testPassword

```

- Close Deployment
```
 ./spheron deployment close --dseq 469 --from /Users/chetan/.spheron/wallet.json --key-secret testPassword   
```

### Acknowledgement

This project incorporates code from [AkashOS](https://github.com/cryptoandcoffee/akashos), created by [Andrew Mello](https://github.com/88plug), which is licensed under the GNU General Public License v3.0 (GPLv3). The full text of the GPL3 license can be found in the LICENSE file in this repository. We thank the author for the efforts and dedication to creating this setup script.
