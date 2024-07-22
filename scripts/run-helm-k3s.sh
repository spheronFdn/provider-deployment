#!/bin/bash

# This setup guide includes some contributions from Andrew.
# We thank the author for the efforts and dedication to creating this setup script.


cd /home/spheron

export KUBECONFIG=/home/spheron/.kube/kubeconfig
. /home/spheron/variables

git clone  https://github.com/spheronFdn/provider-helm-charts.git
cd provider-helm-charts/charts
git checkout devnet-spheron

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add rook-release https://charts.rook.io/release
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia

helm repo update



setup_environment() {
    # Kubernetes config
    kubectl create ns spheron-services
    kubectl label ns spheron-services akash.network/name=spheron-services akash.network=true
    kubectl create ns lease
    kubectl label ns lease akash.network=true
    kubectl apply -f https://raw.githubusercontent.com/akash-network/provider/main/pkg/apis/akash.network/crd.yaml
}

ip_leases(){
#IP leases
kubectl create ns metallb-system
helm repo add metallb https://metallb.github.io/metallb
helm upgrade --install metallb metallb/metallb -n metallb-system --wait
kubectl -n metallb-system expose deployment metallb-controller --name=controller --overrides='{"spec":{"ports":[{"protocol":"TCP","name":"monitoring","port":7472}]}}'
helm upgrade --install spheron-ip-operator spheron-ip-operator -n spheron-services --set provider_address=$ACCOUNT_ADDRESS --wait
kubectl apply -f metal-lb.yml
}


ingress_charts() {
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
  "8443": "spheron-services/spheron-provider:8443"
  "8444": "spheron-services/spheron-provider:8444"
  "1317": "spheron-services/spheron-node-1:1317"
  "9090":  "spheron-services/spheron-node-1:9090"
  "26656": "spheron-services/spheron-node-1:26656"
  "26657": "spheron-services/spheron-node-1:26657"
EOF
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
      --namespace ingress-nginx --create-namespace \
      -f ingress-nginx-custom.yaml

kubectl label ns ingress-nginx app.kubernetes.io/name=ingress-nginx app.kubernetes.io/instance=ingress-nginx
kubectl label ingressclass spheron-ingress-class akash.network=true

}

provider_setup() {
    helm upgrade --install spheron-provider ./spheron-provider -n spheron-services \
        --set from=$ACCOUNT_ADDRESS \
        --set keysecret=$KEY_SECRET \
        --set domain=$DOMAIN \
        --set bidpricestrategy=shellScript \
        --set bidpricescript="$(cat /home/spheron/bidscript.sh | openssl base64 -A)" \
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
}


hostname_operator() {
    helm upgrade --install spheron-hostname-operator ./spheron-hostname-operator -n spheron-services
}

inventory_operator() {
    helm upgrade --install inventory-operator ./spheron-inventory-operator -n spheron-services
}

persistent_storage() {
echo "Persistent storage - MUST INSTALL apt-get install -y lvm2 on EACH NODDE BEFORE RUNNING"
    cat > rook.yml << EOF
operatorNamespace: rook-ceph

configOverride: |
  [global]
  osd_pool_default_pg_autoscale_mode = on
  osd_pool_default_size = 1
  osd_pool_default_min_size = 1

cephClusterSpec:
  resources:

  mon:
    count: 1
  mgr:
    count: 1

  storage:
    useAllNodes: true
    useAllDevices: true
    config:
      osdsPerDevice: "1"

cephBlockPools:
  - name: spheron-deployments
    spec:
      failureDomain: host
      replicated:
        size: 1
      parameters:
        min_size: "1"
        deviceFilter: "^vd[a-z]$"
    storageClass:
      enabled: true
      name: beta1
      isDefault: false
      reclaimPolicy: Delete
      allowVolumeExpansion: true
      parameters:
        imageFormat: "2"
        imageFeatures: layering
        csi.storage.k8s.io/provisioner-secret-name: rook-csi-rbd-provisioner
        csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph
        csi.storage.k8s.io/controller-expand-secret-name: rook-csi-rbd-provisioner
        csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph
        csi.storage.k8s.io/node-stage-secret-name: rook-csi-rbd-node
        csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph
        csi.storage.k8s.io/fstype: ext4

  - name: spheron-deployments
    spec:
      failureDomain: host
      replicated:
        size: 1
      parameters:
        min_size: "1"
        deviceFilter: "^sd[a-z]$"
    storageClass:
      enabled: true
      name: beta2
      isDefault: false
      reclaimPolicy: Delete
      allowVolumeExpansion: true
      parameters:
        imageFormat: "2"
        imageFeatures: layering
        csi.storage.k8s.io/provisioner-secret-name: rook-csi-rbd-provisioner
        csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph
        csi.storage.k8s.io/controller-expand-secret-name: rook-csi-rbd-provisioner
        csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph
        csi.storage.k8s.io/node-stage-secret-name: rook-csi-rbd-node
        csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph
        csi.storage.k8s.io/fstype: ext4

  - name: spheron-deployments
    spec:
      failureDomain: host
      replicated:
        size: 1
      parameters:
        min_size: "1"
        deviceFilter: "^nvme[0-9]$"
    storageClass:
      enabled: true
      name: beta3
      isDefault: false
      reclaimPolicy: Delete
      allowVolumeExpansion: true
      parameters:
        imageFormat: "2"
        imageFeatures: layering
        csi.storage.k8s.io/provisioner-secret-name: rook-csi-rbd-provisioner
        csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph
        csi.storage.k8s.io/controller-expand-secret-name: rook-csi-rbd-provisioner
        csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph
        csi.storage.k8s.io/node-stage-secret-name: rook-csi-rbd-node
        csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph
        csi.storage.k8s.io/fstype: ext4

  - name: spheron-nodes
    spec:
      failureDomain: host
      replicated:
        size: 1
      parameters:
        min_size: "1"
    storageClass:
      enabled: true
      name: akash-nodes
      isDefault: false
      reclaimPolicy: Delete
      allowVolumeExpansion: true
      parameters:
        # RBD image format. Defaults to "2".
        imageFormat: "2"
        # RBD image features. Available for imageFormat: "2". CSI RBD currently supports only `layering` feature.
        imageFeatures: layering
        # The secrets contain Ceph admin credentials.
        csi.storage.k8s.io/provisioner-secret-name: rook-csi-rbd-provisioner
        csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph
        csi.storage.k8s.io/controller-expand-secret-name: rook-csi-rbd-provisioner
        csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph
        csi.storage.k8s.io/node-stage-secret-name: rook-csi-rbd-node
        csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph
        # Specify the filesystem type of the volume. If not specified, csi-provisioner
        # will set default as `ext4`. Note that `xfs` is not recommended due to potential deadlock
        # in hyperconverged settings where the volume is mounted on the same node as the osds.
        csi.storage.k8s.io/fstype: ext4

# Do not create default Ceph file systems, object stores
cephFileSystems:
cephObjectStores:

# Spawn rook-ceph-tools, useful for troubleshooting
toolbox:
  enabled: true
  resources:
EOF

helm search repo rook-release --version v1.12.4
helm upgrade --install --wait --create-namespace -n rook-ceph rook-ceph rook-release/rook-ceph --version 1.12.4
echo "Did you update nodes in rook-ceph-cluster.values1.yml?"
#SHOWS DUPLICATE ISSUE - WORKS WHEN RUN TWICE
helm upgrade --install --create-namespace -n rook-ceph rook-ceph-cluster --set operatorNamespace=rook-ceph rook-release/rook-ceph-cluster --version 1.12.4 -f rook.yml --force

sleep 30

kubectl label sc spheron-nodes akash.network=true
kubectl label sc beta3 akash.network=true
kubectl label sc beta2 akash.network=true
kubectl label sc beta1 akash.network=true

echo "Did you update this label to the same node in rook-ceph-cluster.values1.yml?"
kubectl label node $PERSISTENT_STORAGE_NODE1 akash.network/storageclasses=${PERSISTENT_STORAGE_NODE1_CLASS} --overwrite
kubectl label node $PERSISTENT_STORAGE_NODE2 akash.network/storageclasses=${PERSISTENT_STORAGE_NODE3_CLASS} --overwrite
kubectl label node $PERSISTENT_STORAGE_NODE3 akash.network/storageclasses=${PERSISTENT_STORAGE_NODE3_CLASS} --overwrite

echo "If health not OK, do this"
kubectl -n rook-ceph exec -it $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- bash -c "ceph health mute POOL_NO_REDUNDANCY"
}

setup_environment 
ingress_charts 
provider_setup 
hostname_operator 
inventory_operator


# run_functions() {
#     for func in "$@"; do
#         if declare -f "$func" > /dev/null; then
#             echo "Running $func"
#             "$func"
#         else
#             echo "Error: $func is not a known function"
#             exit 1
#         fi
#     done
# }

# if [ "$#" -eq 0 ]; then
#     run_functions setup_environment ingress_charts provider_setup hostname_operator inventory_operator
# else
#     run_functions "$@"
# fi
