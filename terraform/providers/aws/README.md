# AWS EKS Cluster Terraform Configuration

This Terraform configuration creates and manages Amazon Elastic Kubernetes Service (EKS) clusters with comprehensive features for both **development** and **production** environments.

## Features

- **Multi-Environment Support**: Separate configurations for dev and prod
- **VPC Networking**: Custom VPC with public and private subnets
- **NAT Gateway**: Outbound internet access for private subnets
- **EKS Cluster**: Managed Kubernetes cluster with encryption
- **Node Groups**: Configurable managed node groups with autoscaling
- **GPU Support**: Optional GPU node group for ML workloads
- **Security**: IAM roles, encryption, private endpoints
- **Logging**: CloudWatch Logs integration
- **IRSA**: IAM Roles for Service Accounts support
- **Add-ons**: VPC CNI, CoreDNS, kube-proxy, EBS CSI driver

## File Structure

```
aws/
├── main.tf                  # Main provider configuration
├── vpc.tf                   # VPC, subnets, NAT gateway configuration
├── iam.tf                   # IAM roles and policies
├── eks.tf                   # EKS cluster and addons configuration
├── node_groups.tf           # Node group configurations
├── variables.tf             # All variable definitions
├── outputs.tf               # Output values
├── terraform.tfvars.example # Example variable values
└── README.md               # This file
```

## Prerequisites

1. **AWS CLI**: Install and configure the AWS CLI
   ```bash
   # Install AWS CLI
   # See: https://aws.amazon.com/cli/
   
   # Configure credentials
   aws configure
   ```

2. **Terraform**: Install Terraform >= 1.0
   ```bash
   # Install Terraform
   # See: https://www.terraform.io/downloads
   ```

3. **kubectl**: Install kubectl for cluster management
   ```bash
   # Install kubectl
   # See: https://kubernetes.io/docs/tasks/tools/
   ```

4. **AWS Account**: Create AWS accounts for dev and prod

5. **Enable Required Services**:
   - EKS
   - VPC
   - IAM
   - CloudWatch Logs

## Quick Start

### 1. Initialize Terraform

```bash
cd aws
terraform init
```

### 2. Review Configuration

```bash
# Review dev environment plan
terraform plan -var-file=terraform.tfvars.example
```

### 3. Deploy

```bash
# Deploy development environment
terraform apply -var-file=terraform.tfvars.example
```

## Configuration Variables

### Required Variables

- `region` - AWS region (e.g., `us-east-1`)
- `cluster_name` - Name of the EKS cluster

### Key Variables

- `kubernetes_version` - Kubernetes version (e.g., `1.28`)
- `vpc_cidr` - CIDR block for VPC
- `node_count` - Desired number of nodes
- `instance_type` - EC2 instance type for nodes
- `enable_gpu_node_pool` - Enable GPU node pool (optional)

See `variables.tf` for a complete list of all available variables.

## Network Configuration

The configuration creates:
- **VPC**: Custom VPC with DNS support
- **Public Subnets**: For load balancers and NAT gateways
- **Private Subnets**: For EKS nodes
- **Internet Gateway**: For public subnet internet access
- **NAT Gateways**: For private subnet outbound access

## Node Groups

### Primary Node Group
- Main workload pool
- Configurable autoscaling
- Supports Spot instances

### GPU Node Group (Optional)
- GPU-accelerated workloads
- Instance types: g4dn.xlarge, etc.
- Taints: `nvidia.com/gpu=present:NoSchedule`

## Security

1. **Encryption**: EKS cluster encryption at rest using KMS
2. **Private Endpoints**: Optional private API server endpoint
3. **IAM Roles**: Separate roles for cluster and nodes
4. **IRSA**: IAM Roles for Service Accounts for pod-level permissions
5. **Network Isolation**: Private subnets for nodes

## Connecting to the Cluster

### Configure kubectl

```bash
# Get the command from Terraform output
terraform output kubectl_command

# Or use AWS CLI directly
aws eks update-kubeconfig --name CLUSTER_NAME --region REGION
```

### Verify Connection

```bash
kubectl cluster-info
kubectl get nodes
```

## Outputs

After deployment, Terraform outputs useful information:

```bash
# View all outputs
terraform output

# View specific output
terraform output cluster_endpoint
terraform output oidc_provider_arn
```

### Key Outputs

- `cluster_name` - Cluster name
- `cluster_endpoint` - API endpoint
- `oidc_provider_arn` - OIDC provider ARN for IRSA
- `kubectl_command` - Command to configure kubectl
- `node_iam_role_arn` - Node IAM role ARN

## Using IRSA (IAM Roles for Service Accounts)

1. **Create a Kubernetes Service Account**:
   ```yaml
   apiVersion: v1
   kind: ServiceAccount
   metadata:
     name: my-sa
     namespace: my-namespace
     annotations:
       eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/MY_ROLE
   ```

2. **Use in Pods**:
   ```yaml
   apiVersion: v1
   kind: Pod
   spec:
     serviceAccountName: my-sa
     containers:
     - name: my-app
       image: my-image
   ```

## Common Tasks

### Updating Node Group

1. Modify `terraform.tfvars`
2. Plan changes:
   ```bash
   terraform plan
   ```
3. Apply:
   ```bash
   terraform apply
   ```

### Scaling Nodes

For autoscaling enabled node groups, adjust `min_node_count` and `max_node_count` in your `.tfvars` file.

### Adding GPU Node Pool

1. Set `enable_gpu_node_pool = true` in your `.tfvars` file
2. Configure GPU node pool variables
3. Apply changes
4. **Apply taints after nodes are created** (AWS EKS managed node groups don't support taints at creation):
   ```bash
   # Option 1: Use the helper script
   ./apply-taints.sh
   
   # Option 2: Manual command
   kubectl taint nodes -l pool=gpu nvidia.com/gpu=present:NoSchedule --overwrite
   ```

### Applying Node Taints

**Important**: AWS EKS managed node groups don't support setting taints directly in Terraform. You need to apply taints after the nodes are created:

```bash
# For GPU nodes
kubectl taint nodes -l pool=gpu nvidia.com/gpu=present:NoSchedule --overwrite

# For other node pools (if needed)
kubectl taint nodes -l pool=primary key=value:effect --overwrite
```

A helper script `apply-taints.sh` is provided to automate this process.

## State Management

State is stored **locally** in `terraform.tfstate` files in the working directory.

### Local State Storage

- **State File**: `terraform.tfstate` (created automatically)
- **Backup File**: `terraform.tfstate.backup` (created during operations)
- **Location**: Same directory as your Terraform configuration files

### Using Local State

```bash
# Initialize Terraform (no backend config needed)
terraform init

# Apply configuration
terraform apply -var-file=dev.tfvars

# Verify state
terraform show
```

### Recommended: Add to .gitignore

Create or update `.gitignore` in the terraform directory:

```
# Local state files
terraform.tfstate
terraform.tfstate.backup
*.tfstate
*.tfstate.*

# Crash log files
crash.log
crash.*.log

# Exclude all .tfvars files which might contain sensitive data
*.tfvars
*.tfvars.json

# Ignore override files
override.tf
override.tf.json
*_override.tf
*_override.tf.json
```

## Troubleshooting

### Cluster Not Accessible

```bash
# Check cluster status
aws eks describe-cluster --name CLUSTER_NAME --region REGION

# Verify kubectl context
kubectl config current-context
```

### Node Group Issues

```bash
# Check node group status
aws eks describe-nodegroup --cluster-name CLUSTER_NAME --nodegroup-name NODE_GROUP_NAME --region REGION

# View node events
kubectl get events --all-namespaces
```

## Additional Resources

- [EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [IRSA Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)

---

**Note**: Always review and test changes in development before applying to production.

