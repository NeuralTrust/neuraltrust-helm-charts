# Helm Upgrade Command for Data Plane

## Prerequisites

### Step 1: Create Secrets (Required)

Before deploying, create all necessary Kubernetes secrets:

**Option A: Using the script (Recommended)**
```bash
cd helm
./create-data-plane-secrets.sh
```

The script will prompt for:
- Data Plane JWT Secret (required)
- OpenAI API Key (optional)
- Google API Key (optional)
- Resend API Key (optional)
- Hugging Face Token (optional)
- ClickHouse Password (required, will generate if not provided)

**Option B: Manual creation**
```bash
kubectl create secret generic data-plane-jwt-secret \
  --from-literal=DATA_PLANE_JWT_SECRET="your-jwt-secret" \
  -n neuraltrust

kubectl create secret generic openai-secrets \
  --from-literal=OPENAI_API_KEY="your-openai-key" \
  -n neuraltrust

# ... repeat for other secrets
```

### Step 2: Build Dependencies

```bash
helm dependency build ./neuraltrust/data-plane
```

## Complete Helm Upgrade Command

```bash
helm upgrade --install data-plane ./neuraltrust/data-plane \
  --namespace neuraltrust \
  --create-namespace \
  -f ./neuraltrust/values-neuraltrust.yaml \
  --set global.security.allowInsecureImages=true \
  --set global.openshift=false \
  --set dataPlane.preserveExistingSecrets=false \
  --set dataPlane.imagePullSecrets="gcr-secret" \
  --set dataPlane.secrets.dataPlaneJWTSecret="YOUR_JWT_SECRET" \
  --set dataPlane.secrets.huggingFaceToken="YOUR_HF_TOKEN" \
  --set dataPlane.secrets.openaiApiKey="YOUR_OPENAI_KEY" \
  --set dataPlane.secrets.googleApiKey="YOUR_GOOGLE_KEY" \
  --set dataPlane.secrets.resendApiKey="YOUR_RESEND_KEY" \
  --set dataPlane.components.api.ingress.enabled=true \
  --set clickhouse.auth.password="YOUR_CLICKHOUSE_PASSWORD" \
  --set clickhouse.auth.username="neuraltrust" \
  --set clickhouse.shards=1 \
  --set clickhouse.replicaCount=1 \
  --set clickhouse.zookeeper.enabled=false \
  --set clickhouse.persistence.size="100Gi" \
  --set clickhouse.resources.requests.memory="4Gi" \
  --set clickhouse.resources.requests.cpu="2" \
  --set clickhouse.resources.limits.memory="8Gi" \
  --set clickhouse.resources.limits.cpu="4" \
  --set clickhouse.logLevel="fatal" \
  --set clickhouse.securityContext.enabled=true \
  --set clickhouse.securityContext.runAsUser=1001 \
  --set clickhouse.securityContext.runAsGroup=1001 \
  --set clickhouse.securityContext.fsGroup=1001 \
  --set clickhouse.openshift.enabled=false \
  --set kafka.kraft.enabled=false \
  --set kafka.extraConfigYaml.default.replication.factor=1 \
  --set kafka.auth.interBrokerProtocol=PLAINTEXT \
  --set kafka.auth.clientProtocol=PLAINTEXT \
  --set kafka.broker.replicaCount=1 \
  --set kafka.broker.podAntiAffinityPreset=hard \
  --set kafka.broker.resources.requests.cpu=500m \
  --set kafka.broker.resources.requests.memory=1Gi \
  --set kafka.broker.resources.limits.cpu=1000m \
  --set kafka.broker.resources.limits.memory=2Gi \
  --set kafka.provisioning.enabled=true \
  --set kafka.provisioning.replicationFactor=1 \
  --set kafka.provisioning.waitForKafka=true \
  --set kafka.provisioning.useHelmHooks=true \
  --set kafka.provisioning.resourcesPreset=small \
  --set kafka.provisioning.resources.requests.cpu=500m \
  --set kafka.provisioning.resources.requests.memory=512Mi \
  --set kafka.provisioning.resources.limits.cpu=1000m \
  --set kafka.provisioning.resources.limits.memory=1Gi \
  --set kafka.controller.replicaCount=0 \
  --set kafka.zookeeper.enabled=true \
  --set kafka.zookeeper.replicaCount=1 \
  --set kafka.zookeeper.podAntiAffinityPreset=hard \
  --set kafka.zookeeper.auth.client.enabled=false \
  --set kafka.zookeeper.resources.requests.cpu=500m \
  --set kafka.zookeeper.resources.requests.memory=512Mi \
  --set kafka.zookeeper.resources.limits.cpu=1000m \
  --set kafka.zookeeper.resources.limits.memory=1Gi \
  --wait-for-jobs \
  --timeout 30m
```

## For OpenShift

If using OpenShift, change:
```bash
--set global.openshift=true \
--set clickhouse.openshift.enabled=true \
```

## Using Secret References Instead of Direct Values

You can also use secret references in your values file:
```yaml
dataPlane:
  secrets:
    openaiApiKey:
      secretName: "existing-secret"
      secretKey: "OPENAI_API_KEY"
```

## Recommended Command for ArgoCD (using pre-created secrets)

**After creating secrets (see Prerequisites above), use this command:**
```bash
helm upgrade --install data-plane ./neuraltrust/data-plane \
  --namespace neuraltrust \
  --create-namespace \
  -f ./neuraltrust/values-neuraltrust.yaml \
  -f ./neuraltrust/values-clickhouse-prefixed.yaml \
  -f ./neuraltrust/values-kafka-prefixed.yaml \
  -f ./neuraltrust/values-data-plane-secrets.yaml \
  --set global.security.allowInsecureImages=true \
  --set global.openshift=false \
  --set dataPlane.imagePullSecrets="gcr-secret" \
  --set clickhouse.auth.password="YOUR_CLICKHOUSE_PASSWORD" \
  --set dataPlane.components.api.ingress.enabled=true \
  --wait-for-jobs \
  --timeout 30m
```

**Important:** Make sure the `gcr-secret` exists in your namespace before deploying:
```bash
# Create GCR secret if it doesn't exist
kubectl create secret docker-registry gcr-secret \
  --docker-server=europe-west1-docker.pkg.dev \
  --docker-username=_json_key \
  --docker-password="$(cat path/to/gcr-keys.json)" \
  --docker-email=admin@neuraltrust.ai \
  -n neuraltrust \
  --dry-run=client -o yaml | kubectl apply -f -
```

**Key points:**
- The `values-data-plane-secrets.yaml` file contains references to pre-created Kubernetes secrets
- All API keys and tokens are read from secrets, not passed directly
- Only the ClickHouse password needs to be passed via `--set` (it's used by the ClickHouse sub-chart)
- The prefixed values files already include `global.security.allowInsecureImages=true`

## Alternative: Using Direct Values (Not Recommended for Production)

If you prefer to pass secrets directly (not recommended for production/ArgoCD):
```bash
helm upgrade --install data-plane ./neuraltrust/data-plane \
  --namespace neuraltrust \
  --create-namespace \
  -f ./neuraltrust/values-neuraltrust.yaml \
  -f ./neuraltrust/values-clickhouse-prefixed.yaml \
  -f ./neuraltrust/values-kafka-prefixed.yaml \
  --set global.security.allowInsecureImages=true \
  --set global.openshift=false \
  --set clickhouse.auth.password="YOUR_CLICKHOUSE_PASSWORD" \
  --set dataPlane.secrets.dataPlaneJWTSecret="YOUR_JWT_SECRET" \
  --set dataPlane.secrets.huggingFaceToken="YOUR_HF_TOKEN" \
  --set dataPlane.secrets.openaiApiKey="YOUR_OPENAI_KEY" \
  --set dataPlane.secrets.googleApiKey="YOUR_GOOGLE_KEY" \
  --set dataPlane.secrets.resendApiKey="YOUR_RESEND_KEY" \
  --set dataPlane.components.api.ingress.enabled=true \
  --wait-for-jobs \
  --timeout 30m
```

