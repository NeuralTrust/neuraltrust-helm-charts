# NeuralTrust - Terraform

This directory contains Terraform configurations for deploying Kubernetes clusters across multiple cloud providers:

- Azure (AKS)
- AWS (EKS)
- GCP (GKE) Coming soon

## Directory Structure

```
terraform/
├── README.md
├── providers/
    ├── azure/
    ├── aws/
    └── gcp/
```

## Prerequisites

- Terraform v1.0.0 or later
- Cloud provider CLI tools (az, aws, gcloud)
- Appropriate cloud provider credentials
- kubectl

## Usage

1. Navigate to the desired cloud provider directory
2. Copy `terraform.tfvars.example` to `terraform.tfvars` and fill in your values
3. Initialize Terraform:
   ```bash
   terraform init
   ```
4. Plan the deployment:
   ```bash
   terraform plan
   ```
5. Apply the configuration:
   ```bash
   terraform apply
   ```

## Provider-specific Requirements

### Azure
- Azure CLI installed and configured
- Azure subscription ID
- Service Principal credentials

### AWS
- AWS CLI installed and configured
- AWS access key and secret key
- IAM permissions for EKS

### GCP
- Google Cloud SDK installed and configured
- GCP project ID
- Service account credentials

## Security Considerations

- Never commit `terraform.tfvars` files containing sensitive information
- Use appropriate IAM roles and permissions
- Enable encryption at rest and in transit
- Configure network security groups/firewalls
- Enable audit logging 