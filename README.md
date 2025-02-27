# NeuralTrust Infrastructure

This directory contains the infrastructure code for [NeuralTrust](https://neuraltrust.ai), a comprehensive platform for monitoring, securing, and analyzing AI interactions.

## Architecture

NeuralTrust consists of two main components:

1. **Data Plane** - Handles data ingestion, processing, and storage
   - API service for receiving and processing traces
   - ClickHouse database for analytics storage
   - Kafka for message processing
   - Worker service for background processing

2. **Control Plane** - Provides the user interface and API for managing applications
   - Web application for user interaction
   - API service for business logic
   - PostgreSQL database for application data

> **Important**: The Control Plane is managed by [NeuralTrust](https://neuraltrust.ai) and does not require installation.

## Connectivity

### Network Requirements

The NeuralTrust architecture has specific connectivity requirements:

1. **Data Plane API** - This is the only component that requires public internet exposure for two reasons:
   - To receive telemetry data from client applications using the NeuralTrust SDK
   - To allow the Control Plane to connect and manage the Data Plane

2. **Internal Components** - The following components should only be accessible within the Kubernetes cluster:
   - Kafka
   - ClickHouse
   - Worker service
   - Schema Registry

### Network Diagram

```
Internet
   │
   ▼
┌─────────────────────────────────────────────┐
│                                             │
│  Kubernetes Cluster                         │
│                                             │
│  ┌─────────────┐        ┌───────────────┐   │
│  │             │        │               │   │
│  │ Ingress     │───────▶│ Data Plane    │   │
│  │ Controller  │        │ API           │   │
│  │             │        │               │   │
│  └─────────────┘        └───────┬───────┘   │
│                                 │           │
│                                 ▼           │
│  ┌─────────────┐        ┌───────────────┐   │
│  │             │        │               │   │
│  │ Worker      │◀───────│ Kafka         │   │
│  │ Service     │        │               │   │
│  │             │        └───────────────┘   │
│  └──────┬──────┘                            │
│         │                                   │
│         ▼                                   │
│  ┌─────────────┐                            │
│  │             │                            │
│  │ ClickHouse  │                            │
│  │ Database    │                            │
│  │             │                            │
│  └─────────────┘                            │
│                                             │
└─────────────────────────────────────────────┘
```

### Firewall Configuration

Ensure your network allows:

1. Inbound HTTPS traffic (port 443) to the Kubernetes ingress controller
2. Outbound HTTPS traffic (port 443) from the Data Plane API to the Control Plane
3. Outbound HTTPS traffic (port 443) from the Worker service to external AI services (OpenAI, HuggingFace)

> **Important**: NeuralTrust can provide a specific IP range for the Control Plane to help you implement more restrictive firewall rules. However, you must ensure that:
> 1. Your client LLM applications can always reach the Data Plane API to send telemetry data
> 2. The Control Plane can connect to your Data Plane API for management purposes

> **Note**: All other communication happens within the Kubernetes cluster and doesn't require external network access.

## Prerequisites

Before installing [NeuralTrust](https://neuraltrust.ai), ensure you have the following:

- Kubernetes cluster (v1.20+)
  - Minimum of 3 nodes
  - Each node: 4 vCPUs, 16 GB Memory
  - Total cluster resources: 12+ vCPUs, 48+ GB Memory
- Helm (v3.8+)
- kubectl configured to access your cluster
- OpenAI API key
- HuggingFace token (provided by NeuralTrust)
- Google Container Registry (GCR) service account key (provided by NeuralTrust)

### Required Tools

- `kubectl`: For interacting with the Kubernetes cluster
- `helm`: For deploying Kubernetes applications
- `yq`: For YAML processing
- `jq`: For JSON processing

## Installation

### Environment Setup

1. Clone this repository:
   ```bash
   git clone https://github.com/NeuralTrust/neuraltrust-helm-charts.git
   cd neuraltrust-helm-charts
   ```

2. Create environment files:
   - For development: `.env.dev`
   - For production: `.env.prod`

   You can use the provided `.env.example` file as a template:
   ```bash
   cp .env.example .env.dev
   # Edit the file with your values
   nano .env.dev
   ```

### Environment Variables

The following environment variables are required for installation:

#### Common Variables

| Variable | Description |
|----------|-------------|
| `ENVIRONMENT` | Environment (dev/prod) |
| `EMAIL` | Email for Let's Encrypt certificates |
| `OPENAI_API_KEY` | OpenAI API key |
| `HUGGINGFACE_TOKEN` | HuggingFace token (provided by NeuralTrust) |
| `GCR_KEY_FILE` | Path to GCR service account key file (provided by NeuralTrust) |

### Data Plane Variables

#### Data Plane API

| Variable | Description |
|----------|-------------|
| `DATA_PLANE_API_URL` | Full URL for the Data Plane API |
| `DATA_PLANE_API_IMAGE_REPOSITORY` | Docker image repository for the API |
| `DATA_PLANE_API_IMAGE_TAG` | Docker image tag for the API |
| `DATA_PLANE_API_IMAGE_PULL_POLICY` | Image pull policy (Always/IfNotPresent) |
| `DATA_PLANE_JWT_SECRET` | JWT secret for authentication with Control Plane (generated if not provided) |

#### Worker

| Variable | Description |
|----------|-------------|
| `WORKER_IMAGE_REPOSITORY` | Docker image repository for the worker |
| `WORKER_IMAGE_TAG` | Docker image tag for the worker |
| `WORKER_IMAGE_PULL_POLICY` | Image pull policy for worker |

### Installing the Data Plane

```bash
# For development environment
export ENVIRONMENT=dev
# For production environment
# export ENVIRONMENT=prod

# Run the installation script
./install-data-plane.sh
```

During installation, you will be prompted for:
- Namespace (default: neuraltrust)
- OpenAI API key (if not set in environment)
- HuggingFace token (provided by NeuralTrust, if not set in environment)
- GCR service account key (provided by NeuralTrust)

The script will:
1. Create the namespace if it doesn't exist
2. Install cert-manager for SSL certificates
3. Install NGINX Ingress Controller
4. Create required secrets
5. Install ClickHouse database (with 2 shards and 2 replicas)
6. Install Kafka for messaging
7. Deploy the Data Plane components

## Domain Configuration

### DNS Setup

To properly configure the Data Plane API endpoint, you'll need to set up DNS records:

1. **Create a subdomain** - Create a dedicated subdomain for your Data Plane API (e.g., `dataplane.yourdomain.com`)

2. **Configure CNAME record** - Set up a CNAME record pointing to your Kubernetes ingress controller's external IP or load balancer:
   ```
   dataplane.yourdomain.com.  IN  CNAME  <your-ingress-controller-address>
   ```
   
   To find your ingress controller address after installation:
   ```bash
   kubectl get svc -n {{ namespace }} ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
   ```

3. **Alternative A record** - If CNAME is not possible, you can use an A record pointing to the IP address of your ingress controller:
   ```
   dataplane.yourdomain.com.  IN  A  <your-ingress-controller-ip>
   ```

### TLS/SSL Certificates

The installation process automatically configures Let's Encrypt certificates for your domain. Ensure that:

1. The domain is publicly accessible
2. DNS propagation is complete before installation
3. The email address provided in the `EMAIL` environment variable is valid (for Let's Encrypt notifications)

> **Note**: If you need to use your own certificates instead of Let's Encrypt, please contact NeuralTrust support for guidance on configuring custom certificates.

### Connecting to the Control Plane

After the Data Plane installation is complete, you need to connect it to the NeuralTrust Control Plane:

1. Log in to the NeuralTrust portal using your credentials
2. Navigate to the "Data Plane" section
3. Add a new Data Plane connection
4. Enter your Data Plane API endpoint (the `DATA_PLANE_API_URL` value)
5. Enter the JWT secret that was generated during installation (the `DATA_PLANE_JWT_SECRET` value)
6. Save the connection

The NeuralTrust team will provide you with access to the Control Plane and guide you through this process if needed.

> **Important**: Make sure to save the JWT secret displayed during installation. You will need this value to connect your Data Plane to the Control Plane.

## Database Configuration

NeuralTrust uses ClickHouse for analytics data storage. The Data Plane installation configures a ClickHouse cluster with:

- 2 shards for horizontal scaling
- 2 replicas per shard for high availability
- 100Gi of persistent storage

The schema includes tables for:
- Raw traces data
- Processed analytics data
- Security metrics
- User engagement metrics
- Channel metrics

## Upgrading

To upgrade an existing Data Plane installation:

1. Update the environment variables as needed
2. Run the installation script again

The Helm charts will detect existing installations and perform an upgrade.


## Troubleshooting

### Common Issues

1. **Pod startup failures**: Check pod logs with `kubectl logs -n neuraltrust <pod-name>`
2. **Database connection issues**: Verify ClickHouse is running with `kubectl get pods -n neuraltrust | grep clickhouse`
3. **API key errors**: Ensure your OpenAI API key and HuggingFace token are correctly set
4. **Ingress issues**: Check ingress status with `kubectl get ingress -n neuraltrust`
5. **Certificate issues**: Verify certificates with `kubectl get certificates -n neuraltrust`
6. **Control Plane connection issues**: Ensure your Data Plane API endpoint is accessible from the internet and the JWT token is correct

### Getting Help

If you encounter issues not covered here, please contact NeuralTrust support at support@neuraltrust.ai.

## License

Copyright © 2023-2024 NeuralTrust. All rights reserved.