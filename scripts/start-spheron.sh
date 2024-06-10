#!/bin/bash

cd /home/spheron
if [ -f variables ]; then 
source /home/spheron/variables

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

function configure_gpu() {
  echo "Detected GPU but not set up. Starting configuration..."

  helm repo add nvidia https://helm.ngc.nvidia.com/nvidia \
   && helm repo update \
   && helm install --wait --generate-name --create-namespace --namespace nvidia-device-plugin nvidia/gpu-operator --set driver.enabled=false --set toolkit.enabled=false --set migManager.enabled=false

function working_old(){
  # Add Helm repositories
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

# create containerd config
cat > etc/rancher/k3/config.yaml <<'EOF'
containerd_additional_runtimes:
 - name: nvidia
   type: "io.containerd.runc.v2"
   engine: ""
   root: ""
   options:
     BinaryName: '/usr/bin/nvidia-container-runtime'
EOF

  kubectl apply -f /home/spheron/gpu-nvidia-runtime-class.yaml

  # Install NVIDIA Device Plugin
  helm upgrade -i nvdp nvdp/nvidia-device-plugin \
    --namespace nvidia-device-plugin \
    --create-namespace \
    --set runtimeClassName="nvidia"
}
  echo "Waiting 60 seconds for the GPU to settle..."
  sleep 60
  kubectl get pods -A -o wide
  
  #Required for GPUs on Testnet
  # kubectl label node akash-node1 akash.network/capabilities.gpu.vendor.nvidia.model.1080=true
  # kubectl label node akash-node1 akash.network/capabilities.gpu.vendor.nvidia.model.3080ti=true

  # Set GPU_ENABLED to true
  echo "GPU_ENABLED=true" >> variables
}

function create_test_pod() {
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

  k3s kubectl apply -f gpu-test-pod.yaml
  echo "Waiting 60 seconds for the test pod to start..."
  sleep 60
  k3s kubectl get pods -A -o wide
  k3s kubectl logs nbody-gpu-benchmark
  k3s kubectl delete pod nbody-gpu-benchmark
}

if lspci | grep -q NVIDIA && ! grep -q "GPU_ENABLED=true" variables && ! grep -q "CLIENT_NODE=true" variables; then  
  sudo -u spheron ./run-helm-k3s.sh
  configure_gpu
  create_test_pod
fi

fi
#End NVIDIA

cleanup_bootstrap() {
    if [ -f ./*bootstrap.sh ]; then
        echo "Found old installers - cleaning up"
        rm ./k3s-bootstrap.sh 2>/dev/null
    fi
}

run_bootstrap() {
    wget -q --no-cache "https://raw.githubusercontent.com/spheronFdn/provider-deployment/devnet/scripts/k3s-bootstrap.sh"
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
