# NeuralTrust Infrastructure

This repository contains the infrastructure code for [NeuralTrust](https://neuraltrust.ai), a comprehensive platform for monitoring, securing, and analyzing AI.

## Deployment Targets

The NeuralTrust platform can be deployed to various environments:

- **Kubernetes/OpenShift**: Using the provided Helm charts located in the [`helm`](./helm) directory.
- **Docker Compose**: For local development and testing, using the configuration in the [`docker-compose`](./docker-compose) directory.
- **Terraform**: Scripts for provisioning cloud infrastructure are available in the [`terraform`](./terraform) directory.

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

This division between the Data Plane and Control Plane allows for flexible deployment models to suit different needs:

- **Hybrid Deployment**: The Data Plane is deployed in your infrastructure for complete data privacy and control, while the Control Plane is managed by NeuralTrust.
- **Full SaaS**: NeuralTrust manages the entire infrastructure, providing a fully managed, turnkey solution.
- **Self-Hosted**: The complete platform is deployed in your own infrastructure, offering maximum control and data residency.

## Getting Started

To get started, please go to your desired deployment target and follow the instructions in the respective directory.

- [helm](./helm/README.md) for Kubernetes/OpenShift
- [docker-compose](./docker-compose/README.md) for local development and testing
- [terraform](./terraform/README.md) for cloud infrastructure provisioning

## Contributing

We welcome contributions to the NeuralTrust platform. Please see the [CONTRIBUTING.md](./CONTRIBUTING.md) file for more information.

## License

The NeuralTrust platform is licensed under the [Apache License 2.0](./LICENSE).
