# Main Terraform Configuration for AWS EKS
# This file contains the main provider configuration

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Backend configuration: Local state storage
  # State files are stored locally in terraform.tfstate files
  # For team collaboration, consider using remote state (S3, etc.)
  # backend "local" {
  #   path = "terraform.tfstate"
  # }
  # Note: When no backend is specified, Terraform uses local state by default
}

# Configure the AWS Provider
provider "aws" {
  region = var.region

  default_tags {
    tags = merge(
      var.common_tags,
      {
        ManagedBy = "Terraform"
        Environment = var.environment
      }
    )
  }
}

