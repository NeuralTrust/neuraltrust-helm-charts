# NeuralTrust - Kubernetes/OpenShift

Complete Helm deployment of the NeuralTrust platform for Kubernetes or OpenShift cluster.

## Quick Start

For quick start, we have the [`install-data-plane.sh`](./install-data-plane.sh) script that will install the Data Plane components to your Kubernetes or OpenShift cluster. And the [`install-control-plane.sh`](./install-control-plane.sh) script that will install the Control Plane components to your Kubernetes or OpenShift cluster.

### Data Plane

First we need to install the Data Plane components to your Kubernetes or OpenShift cluster.

To do so we need to define our secrets in a `.env.data-plane.prod` or `.env.data-plane.dev` file.

```bash
cp .env.data-plane.prod.example .env.data-plane.prod
```

Set the defined secreets in yor `.env.data-plane.prod`.

Here you can see a *GCR_KEY_FILE*. This file is provided by NeuralTrust so you are able to pull the images from the NeuralTrust GCR repository.

To install the Data Plane components, run the following command:

```bash
# for Kubernetes
./install-data-plane.sh
# for OpenShift
./install-data-plane.sh --openshift
```

### Control Plane

When the Data Plane components are installed, we need to install the Control Plane components to your Kubernetes or OpenShift cluster.

To do so we need to define our secrets in a `.env.control-plane.prod` or `.env.control-plane.dev` file.

```bash
cp .env.control-plane.prod.example .env.control-plane.prod
```

Set the defined secreets in yor `.env.control-plane.prod`.

Here you can see the *CONTROL_PLANE_JWT_SECRET*. This is the secret key for the JWT token that is used to authenticate the Control Plane components. To gather this secret, you can use the following command:

```bash
kubectl get secret data-plane-jwt-secret -n neuraltrust -o jsonpath='{.data.DATA_PLANE_JWT_SECRET}' | base64 --decod
```

Then we need to define *DATA_PLANE_API_URL*. This is the URL of the Data Plane API service. To gather this URL, you can use the following command. If you are deploying the Control Plane in the same cluster as the Data Plane, you can use:

```toml
DATA_PLANE_API_URL="data-plane-api-service.neuraltrust.svc.cluster.local"
```

With this configuration defined, we can install the Control Plane components.

```bash
# for Kubernetes
./install-control-plane.sh
# for OpenShift
./install-control-plane.sh --openshift

# install postgres database in cluster
./install-control-plane.sh --install-postgresql
```

## Installation

For a manual installation without the quick start, you can follow the following steps:

### Data Plane

1. Define GCR secret in your cluster.

```bash
kubectl create -n "neuraltrust" secret docker-registry gcr-secret \
    --docker-server=europe-west1-docker.pkg.dev \
    --docker-username=_json_key \
    --docker-password="path to your GCR key file" \
    --docker-email=admin@neuraltrust.ai \
    --dry-run=client -o yaml | kubectl apply -f -
```

2. Install ClickHouse

```bash
helm upgrade --install clickhouse "./clickhouse" \
    --namespace "neuraltrust" \
    --version "8.0.10" \
    -f ./neuraltrust/values-clickhouse.yaml \
    --set auth.password="set a password for clickhouse" \
    --wait
```

3. Install Kafka

```bash
helm upgrade --install kafka "./kafka" \
    --version "31.0.0" \
    --namespace "neuraltrust" \
    -f ./neuraltrust/values-kafka.yaml \
    --wait
```

4. Install Data Plane

```bash
helm upgrade --install data-plane "./neuraltrust/data-plane" \
    --namespace "neuraltrust" \
    -f "./neuraltrust/values-neuraltrust.yaml" \
    --timeout 15m \
    --set dataPlane.imagePullSecrets="$PULL_SECRET" \
    --set dataPlane.secrets.huggingFaceToken="$HUGGINGFACE_TOKEN" \
    --set dataPlane.secrets.dataPlaneJWTSecret="$DATA_PLANE_JWT_SECRET" \
    --set dataPlane.secrets.openaiApiKey="${OPENAI_API_KEY:-}" \
    --set dataPlane.secrets.googleApiKey="${GOOGLE_API_KEY:-}" \
    --set dataPlane.secrets.resendApiKey="${RESEND_API_KEY:-}" \
    # if you want to use s3 for clickhouse backup
    --set dataPlane.components.clickhouse.backup.s3.accessKey="${S3_ACCESS_KEY:-}" \
    --set dataPlane.components.clickhouse.backup.s3.secretKey="${S3_SECRET_KEY:-}" \
    # if you want to use gcs for clickhouse backup
    --set dataPlane.components.clickhouse.backup.gcs.accessKey="${GCS_ACCESS_KEY:-}" \
    --set dataPlane.components.clickhouse.backup.gcs.secretKey="${GCS_SECRET_KEY:-}" \
    # if you want to use ingress
    --set dataPlane.components.api.ingress.enabled="define if you want to use ingress" \
    --wait
```


### Control Plane

For the Control Plane we just need to run:

```bash
helm upgrade --install control-plane "./neuraltrust/control-plane" \
    --namespace "neuraltrust" \
    -f "./neuraltrust/values-neuraltrust.yaml" \
    --timeout 15m \
    --set controlPlane.secrets.controlPlaneJWTSecret="$CONTROL_PLANE_JWT_SECRET" \
    --set controlPlane.secrets.openaiApiKey="$OPENAI_API_KEY" \
    --set controlPlane.components.postgresql.installInCluster="$INSTALL_POSTGRESQL" \
    --set controlPlane.components.postgresql.secrets.password="$POSTGRES_PASSWORD" \
    --set controlPlane.components.app.config.dataPlaneApiUrl="$DATA_PLANE_API_URL" \
    --set controlPlane.components.scheduler.config.dataPlaneApiUrl="$DATA_PLANE_API_URL" \
    --set controlPlane.components.api.config.dataPlaneApiUrl="$DATA_PLANE_API_URL" \
    --set controlPlane.secrets.resendApiKey="${RESEND_API_KEY:-}" \
    --set controlPlane.components.scheduler.ingress.enabled="$([ "$SKIP_INGRESS" = true ] && echo false || echo true)" \
    --set controlPlane.components.api.ingress.enabled="$([ "$SKIP_INGRESS" = true ] && echo false || echo true)" \
    --set controlPlane.components.app.ingress.enabled="$([ "$SKIP_INGRESS" = true ] && echo false || echo true)" \
    --wait
```


## Advance Configuration

### Control Plane PostgreSQL

If you want to install the PostgreSQL database in the cluster, you can use the following command:

```bash
./install-control-plane.sh --install-postgresql
```

Otherwise you can use an external PostgreSQL database. To do so, you need to define the postgres secrets in `values-neuraltrust.yaml` file.

```yaml
controlPlane:
  components:
    postgresql:
      installInCluster: true
      secrets:
        name: "postgresql-secrets"
        user: "set a user for the postgres database"
        password: "set a password for the postgres database"
        database: "set a database for the postgres database"
        host: "set the host of the postgres database"
        port: "5432"
```

### TrustTest configuration

For the TrustTest evaluation we support OpenAI and Google. To use them, you just need to define one of them in `.env.data-plane.prod` or `.env.data-plane.dev` file.

```bash
OPENAI_API_KEY="set your openai api key"
GOOGLE_API_KEY="set your google api key"
```

In the `values-neuraltrust.yaml` file you can define the model to use for the LLM evaluation.

```yaml
dataPlane:
  components:
    api:
      trustTestConfig: # here you can define the model to use for each use case
        evaluator:
          provider: "google"
          model: "gemini-2.0-flash"
          temperature: 0.2
        question_generator:
          provider: "google"
          model: "gemini-2.0-flash"
          temperature: 0.5
        embeddings:
          provider: "openai"
          model: "text-embedding-3-small"
        topic_summarizer:
          provider: "google"
          model: "gemini-2.0-flash"
          temperature: 0.2
```
