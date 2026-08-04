# ==============================================================================
# SECTION 1: SYSTEM PROVIDERS INTEGRATION
# ==============================================================================
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    command     = "aws"
  }
}

provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
      command     = "aws"
    }
  }
}

# ==============================================================================
# SECTION 2: CORE NETWORKING TOPOLOGY DEFINITION (VPC)
# ==============================================================================
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.6.1"

  name = "devops-vpc"
  cidr = var.vpc_cidr

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# ==============================================================================
# SECTION 3: MANAGED EKS COMPUTE CLUSTER CONFIGURATION (v21+ SPECS)
# ==============================================================================
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.20.0"

  name               = var.cluster_name
  kubernetes_version = "1.30"

  endpoint_public_access  = true
  endpoint_private_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_cluster_creator_admin_permissions = true
  authentication_mode                      = "API_AND_CONFIG_MAP"

  eks_managed_node_groups = {
    workers = {
      instance_types = ["t3.medium"] # Optimized baseline capacity for e-commerce loads
      min_size       = 1
      max_size       = 3
      desired_size   = 2

      iam_role_additional_policies = {
        AmazonEFSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
      }
    }
  }

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# ==============================================================================
# SECTION 4: IAM ROLES FOR SERVICE ACCOUNTS (IRSA) & HELM INTEGRATION
# ==============================================================================

# --- AWS Load Balancer Controller IAM Role Automation ---
module "lb_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39.0"

  role_name                              = "eks-lb-controller-role"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

# --- AWS Load Balancer Controller Helm Installation ---
resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  values = [
    <<-EOT
    clusterName: ${module.eks.cluster_name}
    serviceAccount:
      create: true
      name: aws-load-balancer-controller
      annotations:
        # FIXED: Resolved invalid string token mapping to valid AWS IAM Service Account key
        ://amazonaws.com: ${module.lb_role.iam_role_arn}
    EOT
  ]
}

# ==============================================================================
# SECTION 5: E-COMMERCE CONTAINER REGISTRY STORAGE LAYERS (AMAZON ECR)
# ==============================================================================

# --- Frontend Registry ---
resource "aws_ecr_repository" "frontend_app" {
  name                 = "shopflow-frontend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true # Automatically tracks DevSecOps security vulnerability bugs
  }
}

# --- Backend Registry ---
resource "aws_ecr_repository" "backend_api" {
  name                 = "shopflow-backend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# ==============================================================================
# SECTION 6: SHARED PERSISTENT STORAGE LAYER (AMAZON EFS)
# ==============================================================================

resource "aws_efs_file_system" "eks_efs" {
  creation_token = "${var.cluster_name}-efs"
  encrypted      = true

  tags = {
    Name        = "EKS-Shared-Storage"
    Environment = "production"
  }
}

resource "aws_security_group" "efs_sg" {
  name        = "allow_nfs_from_eks"
  description = "Allow NFS traffic from EKS nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Allow port 2049 traffic exclusively from within our corporate VPC network"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_nfs_from_eks"
  }
}

resource "aws_efs_mount_target" "zone" {
  count           = length(module.vpc.private_subnets)
  file_system_id  = aws_efs_file_system.eks_efs.id
  subnet_id       = module.vpc.private_subnets[count.index]
  security_groups = [aws_security_group.efs_sg.id]
}

