# VPC and Networking Configuration for EKS
# This file contains VPC, subnets, internet gateway, and NAT gateway resources

# Get availability zones in the region
data "aws_availability_zones" "available" {
  state = "available"
}

# Create VPC
resource "aws_vpc" "main" {
  count                = var.existing_vpc_id == null ? 1 : 0
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.cluster_name}-vpc"
  }
}

# Use existing VPC if provided
locals {
  vpc_id = var.existing_vpc_id != null ? var.existing_vpc_id : aws_vpc.main[0].id
}

# Get VPC data for existing VPC
data "aws_vpc" "selected" {
  id = local.vpc_id
}

# Create Internet Gateway
resource "aws_internet_gateway" "main" {
  count  = var.existing_vpc_id == null ? 1 : 0
  vpc_id = local.vpc_id

  tags = {
    Name = "${var.cluster_name}-igw"
  }
}

# Create public subnets for load balancers and NAT gateways
resource "aws_subnet" "public" {
  count             = var.existing_vpc_id == null ? length(var.public_subnet_cidrs) : 0
  vpc_id            = local.vpc_id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name                                            = "${var.cluster_name}-public-${count.index + 1}"
    "kubernetes.io/role/elb"                        = "1"
    "kubernetes.io/cluster/${var.cluster_name}"     = "shared"
  }
}

# Create private subnets for EKS nodes
resource "aws_subnet" "private" {
  count             = var.existing_vpc_id == null ? length(var.private_subnet_cidrs) : 0
  vpc_id            = local.vpc_id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name                                            = "${var.cluster_name}-private-${count.index + 1}"
    "kubernetes.io/role/internal-elb"               = "1"
    "kubernetes.io/cluster/${var.cluster_name}"     = "owned"
  }
}

# Create Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count  = var.existing_vpc_id == null && var.enable_nat_gateway ? length(aws_subnet.public) : 0
  domain = "vpc"

  tags = {
    Name = "${var.cluster_name}-nat-eip-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}

# Create NAT Gateways
resource "aws_nat_gateway" "main" {
  count         = var.existing_vpc_id == null && var.enable_nat_gateway ? length(aws_subnet.public) : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.cluster_name}-nat-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}

# Create route table for public subnets
resource "aws_route_table" "public" {
  count  = var.existing_vpc_id == null ? 1 : 0
  vpc_id = local.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }

  tags = {
    Name = "${var.cluster_name}-public-rt"
  }
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count          = var.existing_vpc_id == null ? length(aws_subnet.public) : 0
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# Create route tables for private subnets
resource "aws_route_table" "private" {
  count  = var.existing_vpc_id == null && var.enable_nat_gateway ? length(aws_subnet.private) : 0
  vpc_id = local.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name = "${var.cluster_name}-private-rt-${count.index + 1}"
  }
}

# Associate private subnets with private route tables
resource "aws_route_table_association" "private" {
  count          = var.existing_vpc_id == null && var.enable_nat_gateway ? length(aws_subnet.private) : 0
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Get existing subnets if VPC is provided
data "aws_subnets" "private" {
  count = var.existing_vpc_id != null ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
  filter {
    name   = "tag:kubernetes.io/role/internal-elb"
    values = ["1"]
  }
}

data "aws_subnets" "public" {
  count = var.existing_vpc_id != null ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
  filter {
    name   = "tag:kubernetes.io/role/elb"
    values = ["1"]
  }
}

# Local values for subnet IDs
locals {
  private_subnet_ids = var.existing_vpc_id != null ? data.aws_subnets.private[0].ids : aws_subnet.private[*].id
  public_subnet_ids  = var.existing_vpc_id != null ? data.aws_subnets.public[0].ids : aws_subnet.public[*].id
}

