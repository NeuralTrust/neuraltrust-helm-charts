#/bin/bash

echo "Updating system..."
sudo apt update -y
echo "Upgrading system..."
sudo apt upgrade -y
echo "Installing git..."
sudo apt install git -y
echo "Instaling docker..."
sudo apt install docker.io -y
# echo "Generating ssh key..."
# ssh-keygen

echo "Installing java..."
sudo apt install default-jre

echo "Instaling docker-compose..."
COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

ls -l /dev/disk/by-id/google-*
sudo mkfs.ext4 -m 0 -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/sdb

 
echo "Make directory to mount the external disk..."
sudo mkdir -p /mnt/disks
sudo mkdir -p /mnt/disks/neuraltrust

sudo chmod a+w /mnt/disks/neuraltrust

sudo mount -o discard,defaults /dev/sdb /mnt/disks/neuraltrust

sudo mkdir /mnt/disks/neuraltrust/certbot
sudo mkdir /mnt/disks/neuraltrust/certbot/etc
sudo mkdir /mnt/disks/neuraltrust/certbot/var
sudo mkdir /mnt/disks/neuraltrust/web
sudo mkdir /mnt/disks/neuraltrust/elastic
sudo mkdir /mnt/disks/neuraltrust/kafka
sudo mkdir /mnt/disks/neuraltrust/kibana
sudo mkdir /mnt/disks/neuraltrust/zk-data
sudo mkdir /mnt/disks/neuraltrust/zk-txn-logs



gcloud container clusters create "cluster-prod" \
  --region "europe-west1" \
  --enable-dataplane-v2 \
  --enable-master-authorized-networks \
  --master-authorized-networks 10.132.0.0/20,79.153.69.1/32 \
  --enable-autoscaling \
  --min-nodes 2 \
  --max-nodes 2 \
  --machine-type "e2-standard-4" \
  --disk-type "pd-standard" \
  --disk-size "100" \
  --cluster-dns "clouddns" \
  --cluster-dns-scope "vpc" \
  --cluster-dns-domain "cluster.local" \
  --num-nodes "1" \
  --scopes=cloud-platform \
  --logging=SYSTEM,API_SERVER,WORKLOAD \
  --monitoring=SYSTEM,API_SERVER \
  --node-locations "europe-west1-c" \
  --tags "http-server,https-server,kafka-cluster" \
  --autoprovisioning-network-tags "http-server,https-server,kafka-cluster" \
  --project "neuraltrust-app-prod"

gcloud container clusters get-credentials cluster-prod --region europe-west1 --project neuraltrust-app-prod

# Add Confluent Helm repository
helm repo add confluentinc https://packages.confluent.io/helm
helm repo update

kubectl create namespace neuraltrust

# Install Confluent for Kubernetes operator and CRDs
echo "Installing Confluent for Kubernetes operator and CRDs..."
helm install confluent-operator confluentinc/confluent-for-kubernetes --namespace neuraltrust --set installCRDs=true

# Install Elastic Helm repository
helm repo add elastic https://helm.elastic.co
helm repo update

# Install Elastic Cloud Operator
helm install elastic-operator elastic/eck-operator -n neuraltrust --create-namespace
helm uninstall elastic-operator -n neuraltrust || true


echo "Setting up ingress-nginx..."
# Only cleanup resources in neuraltrust namespace
helm uninstall ingress-nginx -n neuraltrust || true

# Add the ingress-nginx repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install ingress-nginx in the neuraltrust namespace with a unique name
helm install ingress-nginx-neuraltrust ingress-nginx/ingress-nginx \
    --namespace neuraltrust \
    --set controller.service.type=LoadBalancer \
    --set controller.ingressClassResource.name=nginx-neuraltrust \
    --set controller.ingressClassResource.default=false \
    --set controller.metrics.enabled=true \
    --set controller.admissionWebhooks.enabled=true \
    --set controller.electionID=ingress-controller-leader-neuraltrust \
    --wait \
    --atomic

# Verify the installation
echo "Verifying ingress-nginx installation..."
kubectl get pods -n neuraltrust -l app.kubernetes.io/name=ingress-nginx
kubectl get svc -n neuraltrust -l app.kubernetes.io/name=ingress-nginx

# Install cert-manager
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
--namespace neuraltrust \
--version v1.12.0 \
--set installCRDs=true


 kubectl create -n neuraltrust secret docker-registry gcr-secret \
  --docker-server=europe-west1-docker.pkg.dev \
  --docker-username=_json_key \
  --docker-password="$(cat neuraltrust.json)" \
  --docker-email=victor.garcia@neuraltrust.ai

# Install the Helm chart with a valid release name
helm install neuraltrust-platform ./neuraltrust-infra \
  --namespace neuraltrust \
  --create-namespace


# After the existing Connect wait command, add these debugging steps
echo "Checking Connect pod status..."
kubectl get pods -n neuraltrust -l app=connect -o wide

echo "Checking Connect pod logs..."
kubectl logs -n neuraltrust -l app=connect --tail=100

echo "Checking Connect events..."
kubectl get events -n neuraltrust --field-selector involvedObject.kind=Connect


# If the pod is in a crash loop or failed state, describe it
echo "Describing Connect pod..."
kubectl describe pod -n neuraltrust -l app=connect
