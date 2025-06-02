# NeuralTrust OpenShift Platform Helm Chart

This Helm chart deploys the NeuralTrust platform on OpenShift, consisting of control plane and data plane components.

## Architecture

The platform consists of:
- **Control Plane**: API, Web App, and Scheduler components
- **Data Plane**: API, Worker, and Kafka components  
- **Dependencies**: PostgreSQL, ClickHouse, and Kafka

## Prerequisites

- OpenShift 4.x
- Helm 3.8+
- Access to the NeuralTrust container registry

## Installation

### Quick Start

1. **Install Data Plane**:
```bash
ENVIRONMENT=dev ./install-openshift-data-plane.sh --namespace neuraltrust-dev
```

2. **Install Control Plane**:
```bash
ENVIRONMENT=dev ./install-openshift-control-plane.sh --namespace neuraltrust-dev
```

### Manual Installation

#### 1. Install Data Plane Components

```bash
# Install ClickHouse
helm upgrade --install clickhouse ./helm-charts/shared-charts/clickhouse \
  --namespace neuraltrust \
  -f helm-charts/openshift/values-clickhouse.yaml \
  --set auth.password="your-secure-password"

# Install Kafka  
helm upgrade --install kafka ./helm-charts/shared-charts/kafka \
  --namespace neuraltrust \
  -f helm-charts/openshift/values-kafka.yaml

# Install Data Plane
helm upgrade --install data-plane ./helm-charts/openshift/data-plane \
  --namespace neuraltrust \
  -f helm-charts/openshift/values.yaml \
  --set dataPlane.secrets.openaiApiKey="your-openai-key" \
  --set dataPlane.secrets.dataPlaneJWTSecret="your-jwt-secret"
```

#### 2. Install Control Plane Components

```bash
helm upgrade --install control-plane ./helm-charts/openshift/control-plane \
  --namespace neuraltrust \
  -f helm-charts/openshift/values.yaml \
  --set controlPlane.secrets.controlPlaneJWTSecret="your-jwt-secret" \
  --set openai.secrets.apiKey="your-openai-key"
```

## Configuration

### Values Files Structure

- **`values.yaml`**: Base configuration with secure defaults
- **`values-clickhouse.yaml`**: ClickHouse chart configuration
- **`values-kafka.yaml`**: Kafka chart configuration

### Environment-Specific Configuration

Configure environment-specific settings using `--set` flags:

#### Development Environment
```bash
helm install data-plane ./helm-charts/openshift/data-plane \
  -f values.yaml \
  --set controlPlane.components.api.replicaCount=1 \
  --set controlPlane.components.app.replicaCount=1 \
  --set controlPlane.components.app.config.nodeEnv=development \
  --set controlPlane.components.app.config.openaiModel="gpt-3.5-turbo" \
  --set dataPlane.components.api.replicaCount=1 \
  --set dataPlane.components.worker.replicaCount=1 \
  --set postgresql.persistence.size="5Gi" \
  --set clickhouse.backup.enabled=false
```

#### Production Environment
```bash
helm install data-plane ./helm-charts/openshift/data-plane \
  -f values.yaml \
  --set controlPlane.components.api.replicaCount=3 \
  --set controlPlane.components.app.replicaCount=3 \
  --set controlPlane.components.app.config.nodeEnv=production \
  --set controlPlane.components.app.config.openaiModel="gpt-4" \
  --set dataPlane.components.api.replicaCount=3 \
  --set dataPlane.components.worker.replicaCount=3 \
  --set postgresql.persistence.size="100Gi" \
  --set postgresql.persistence.storageClass="fast-ssd" \
  --set clickhouse.backup.enabled=true
```

### Required Secrets

Set these values via `--set` flags:

#### Data Plane
- `dataPlane.secrets.openaiApiKey`
- `dataPlane.secrets.googleApiKey` (optional)
- `dataPlane.secrets.resendApiKey`
- `dataPlane.secrets.dataPlaneJWTSecret`
- `dataPlane.components.api.huggingfaceToken`

#### Control Plane  
- `controlPlane.secrets.controlPlaneJWTSecret`
- `openai.secrets.apiKey`
- `resend.apiKey`
- `clerk.publishableKey`
- `clerk.secretKey`
- `postgresql.secrets.password`

### Image Configuration

Override image repositories and tags:

```bash
--set controlPlane.components.api.image.repository="your-registry/api" \
--set controlPlane.components.api.image.tag="v1.2.3"
```

### Common Configuration Overrides

#### Resource Scaling for Development
```bash
--set controlPlane.components.api.resources.requests.memory="256Mi" \
--set controlPlane.components.api.resources.requests.cpu="100m" \
--set controlPlane.components.api.resources.limits.memory="512Mi" \
--set controlPlane.components.api.resources.limits.cpu="200m"
```

#### Resource Scaling for Production
```bash
--set controlPlane.components.api.resources.requests.memory="1Gi" \
--set controlPlane.components.api.resources.requests.cpu="500m" \
--set controlPlane.components.api.resources.limits.memory="2Gi" \
--set controlPlane.components.api.resources.limits.cpu="1000m"
```

## Chart Structure

```
helm-charts/openshift/
├── Chart.yaml                 # Main chart metadata
├── values.yaml                # Base configuration with secure defaults
├── values-clickhouse.yaml     # ClickHouse configuration
├── values-kafka.yaml          # Kafka configuration
├── control-plane/             # Control plane subchart
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
└── data-plane/               # Data plane subchart
    ├── Chart.yaml
    ├── values.yaml
    └── templates/
```

## Networking

### Routes (OpenShift)

The chart creates OpenShift Routes for external access:

- **Control Plane API**: `controlPlane.components.api.host`
- **Web Application**: `controlPlane.components.app.host`
- **Data Plane API**: `dataPlane.components.api.host`
- **Scheduler**: `controlPlane.components.scheduler.host`

### Network Policies

Configure network policies via `global.network`:

```yaml
global:
  network:
    controlPlaneCidr: "10.0.0.0/16"
    dataPlanecidr: "10.1.0.0/16"
    clientDataPlaneCidr: "192.168.1.0/24"
```

Or via `--set`:
```bash
--set global.network.controlPlaneCidr="10.0.0.0/16" \
--set global.network.dataPlanecidr="10.1.0.0/16"
```

## Backup Configuration

### ClickHouse Backup

Configure via `--set` flags:

```bash
--set clickhouse.backup.enabled=true \
--set clickhouse.backup.type="s3" \
--set clickhouse.backup.s3.bucket="your-backup-bucket" \
--set clickhouse.backup.s3.region="us-west-2" \
--set clickhouse.backup.s3.accessKey="your-access-key" \
--set clickhouse.backup.s3.secretKey="your-secret-key"
```

## Monitoring and Health Checks

The chart includes:
- **Readiness Probes**: `/health` endpoints
- **Liveness Probes**: Component health monitoring
- **Resource Limits**: Configured per environment

## Security

### Image Pull Secrets

For private registries, configure via `--set`:

```bash
--set controlPlane.components.api.image.imagePullSecrets[0].name="gcr-secret"
```

### Security Contexts

OpenShift-compatible security contexts are configured by default.

## Troubleshooting

### Common Issues

1. **Image Pull Errors**: Ensure registry credentials are properly configured
2. **Route Not Accessible**: Check network policies and firewall rules
3. **Pod Startup Failures**: Review resource limits and node capacity
4. **Secret Missing**: Verify all required secrets are set

### Debugging Commands

```bash
# Check pod status
oc get pods -n neuraltrust

# View pod logs
oc logs -f deployment/control-plane-api -n neuraltrust

# Check routes
oc get routes -n neuraltrust

# Validate configuration
helm template ./helm-charts/openshift -f values.yaml --debug
```

## Upgrading

### Minor Updates
```bash
helm upgrade data-plane ./helm-charts/openshift/data-plane \
  --namespace neuraltrust \
  --reuse-values
```

### Major Updates
```bash
# Backup your configuration
helm get values data-plane -n neuraltrust > current-values.yaml

# Review changes and upgrade
helm upgrade data-plane ./helm-charts/openshift/data-plane \
  --namespace neuraltrust \
  -f current-values.yaml
```

## Contributing

When modifying the chart:

1. Test with different environment configurations using `--set` flags
2. Update this documentation
3. Validate with `helm lint`

## Support

For issues or questions:
- Check the troubleshooting section
- Review pod logs and events
- Contact NeuralTrust support with deployment details 