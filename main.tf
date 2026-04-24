# Create the Network (VPC)
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name   = "devops-vpc"
  cidr   = var.vpc_cidr

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}

# Create the Kubernetes Cluster (EKS)
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = "1.30" # IMPORTANT: In v21, this remains 'cluster_version'

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    workers = {
      instance_types = ["t3.medium"]
      min_size       = 1
      max_size       = 3
      desired_size   = 2
    }
  }
}

# --- Amazon ECR Repository ---
# This creates a private repository for your Docker images
resource "aws_ecr_repository" "app_repo" {
  name                 = "enterprise-app-repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true # Automatically scans images for vulnerabilities
  }
}

# --- Amazon EFS File System ---
# Creates a shared filesystem that multiple Pods can read/write simultaneously
resource "aws_efs_file_system" "eks_efs" {
  creation_token = "eks-efs"
  encrypted      = true

  tags = {
    Name = "EKS-Shared-Storage"
  }
}

# EFS Mount Targets
# Connects the EFS to each private subnet where your EKS nodes live
resource "aws_efs_mount_target" "zone" {
  count           = length(module.vpc.private_subnets)
  file_system_id  = aws_efs_file_system.eks_efs.id
  subnet_id       = module.vpc.private_subnets[count.index]
  security_groups = [aws_security_group.efs_sg.id]
}

# Security Group for EFS
# Allows EKS nodes to talk to the EFS over port 2049 (NFS)
resource "aws_security_group" "efs_sg" {
  name        = "allow_nfs_from_eks"
  description = "Allow NFS traffic from EKS nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block] # Restricts access to your VPC only
  }
}
resource "aws_ecr_repository" "frontend" { name = "frontend-repo" }
resource "aws_ecr_repository" "backend" { name = "backend-repo" }
