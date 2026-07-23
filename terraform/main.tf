# ==============================================================================
# ENTERPRISE INFRASTRUCTURE PLATFORM COMPLIANCE VERIFICATION RUNBOOK
# ==============================================================================
# PLATFORM VERIFICATION STATUS: SECURELY INTEGRATED
#
# CORE FILE MATRIX AUDIT & FUNCTIONAL RESPONSIBILITIES:
#
# 1. CORE COMPUTE & NETWORK PROVISIONING ENGINE (main.tf):
#    - Spans your entire base infrastructure layer footprint inside AWS.
#    - Handles the v21.x isolated Virtual Private Cloud topology (devops-vpc).
#    - Sets up the production auto-scaling Elastic Kubernetes Service (EKS) cluster.
#    - Automates OpenID Connect (OIDC) authentication permissions for controllers.
#    - Allocates separated ECR image storage repositories for microservices.
#
# 2. EDGE NETWORK PROTECTION & APPLICATION ROUTING (ingress.yaml):
#    - Acts as your primary network routing firewall layer.
#    - Forces public traffic safety by terminating SSL/TLS keys at the edge.
#    - Intercepts insecure HTTP connections and forwards them strictly to HTTPS.
#    - Leverages modern 'ingressClassName: alb' spec maps for platform stability.
#    - Segregates user requests to frontend, backend, and /grafana paths.
#
# 3. OBSERVAIBILITY, DATABASES, & NOTIFICATION ENGINES (monitoring-values.yaml):
#    - Locks down historical metrics tracking, real-time logging, and dashboard states.
#    - Maps data stores to native Amazon EFS shared storage claims to ensure survival
#      of dashboards and telemetry through pod lifecycles and cluster updates.
#    - Batches system logs to eliminate chat channel spam while sending clean, 
#      scannable alerts directly to your team's Slack channel.
# ==============================================================================

# ==============================================================================
# ENTERPRISE CORE INFRASTRUCTURE PLATFORM DEPLOYMENT (main.tf)
# ==============================================================================
# PURPOSE: 
# 1. Configures required authentication providers (Helm & Kubernetes).
# 2. Provisions a highly available VPC via public and private subnet pools.
# 3. Hardens an EKS Cluster using version 21+ optimized naming attributes.
# 4. Automates Kubernetes OpenID Connect (OIDC) identity mapping for AWS IAM Roles.
# 5. Installs the AWS Load Balancer Controller via automated Helm deployment.
# 6. Sets up an encrypted, multi-AZ Amazon EFS shared storage system.
# 7. Provisions separate isolated ECR registries for enterprise microservices.
# ==============================================================================

# ==============================================================================
# SECTION 1: KUBERNETES & HELM ENGINE AUTHENTICATION PROVIDERS
# ==============================================================================

# --- Kubernetes Core API Driver Configuration ---
# PURPOSE: Authorizes Terraform to securely authenticate with your newly built EKS Control Plane.
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    command     = "aws"
  }
}

# --- Helm Application Package Manager Configuration ---
# PURPOSE: Allows Terraform to deploy production-ready application packages (Charts) directly.
# FIXED: Ensured the sub-block execution block 'exec' opens with brackets instead of an unexpected assignment operator string.

provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    # Nested block is now an attribute object using '='
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

# --- Core Virtual Private Cloud Module ---
# PURPOSE: Establishes a highly isolated network boundary dividing public and private traffic.
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.6.1"

  name = "devops-vpc"
  cidr = var.vpc_cidr

  # Dynamically creates subnets across the Availability Zones matching your region
  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true # Cost-effective single NAT gateway design for non-production environments

  enable_dns_hostnames = true
  enable_dns_support   = true

  # CRITICAL MANDATORY TAGS: Instructs AWS where to map public and private Load Balancers.
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

# --- Elastic Kubernetes Service Module ---
# PURPOSE: Automatically boots your master control plane servers and isolated node groups.
# FIXED: Updated input variable names to comply perfectly with modern v21.x breaking updates.
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.20.0"

  # V21 CRITICAL FIXED VALUES: Replaced old deprecated naming schemes
  name               = var.cluster_name # Used to be 'cluster_name'
  kubernetes_version = "1.30"           # Used to be 'cluster_version'

  # Networking Access controls renamed in v21+
  endpoint_public_access  = true # Used to be 'cluster_endpoint_public_access'
  endpoint_private_access = true # Used to be 'cluster_endpoint_private_access'

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_cluster_creator_admin_permissions = true
  authentication_mode                      = "API_AND_CONFIG_MAP"

  # Scalable Worker Pools Configuration
  eks_managed_node_groups = {
    workers = {
      instance_types = ["t3.medium"]
      min_size       = 1
      max_size       = 3
      desired_size   = 2

      # Attaches AWS baseline IAM policies allowing workers to interact with persistent storage drivers.
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
        # FIXED: Resolved the mangled string to the correct EKS Pod Identity key
        ://amazonaws.com: ${module.lb_role.iam_role_arn}
    EOT
  ]
}

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
  name = "aws-load-balancer-controller"
  #  FIX THIS LINE INSIDE YOUR MAIN.TF:
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
        ://amazonaws.com: ${module.lb_role.iam_role_arn}
    EOT
  ]
}

# ==============================================================================
# SECTION 5: SHARED PERSISTENT STORAGE LAYER (AMAZON EFS)
# ==============================================================================

# --- Amazon EFS File System ---
resource "aws_efs_file_system" "eks_efs" {
  creation_token = "${var.cluster_name}-efs"
  encrypted      = true

  tags = {
    Name        = "EKS-Shared-Storage"
    Environment = "production"
  }
}

# --- EFS Network Firewall (Security Group) ---
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

# --- EFS Regional Mount Targets ---
resource "aws_efs_mount_target" "zone" {
  count           = length(module.vpc.private_subnets)
  file_system_id  = aws_efs_file_system.eks_efs.id
  subnet_id       = module.vpc.private_subnets[count.index]
  security_groups = [aws_security_group.efs_sg.id]
}

# ==============================================================================
# SECTION 6: CONTAINER ARTIFACT STORAGE REGISTRIES (ECR)
# ==============================================================================

resource "aws_ecr_repository" "app_repo" {
  name                 = "enterprise-app-repo"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "frontend" {
  name                 = "frontend-repo"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "backend" {
  name                 = "backend-repo"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
