# ==============================================================================
# KUBERNETES & MODULE NETWORKING OUTPUTS
# ==============================================================================
output "cluster_endpoint" {
  description = "The URL endpoint used by kubectl and CI/CD tools to communicate with the EKS Control Plane."
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "The verified corporate string identifier of the provisioned Elastic Kubernetes Service instance."
  value       = module.eks.cluster_name
}

output "vpc_id" {
  description = "The core AWS Virtual Private Cloud ID containing the underlying subnets and nodes."
  value       = module.vpc.vpc_id
}

# ==============================================================================
# NATIVE AWS ARTIFACT STORAGE & FILESYSTEM OUTPUTS
# ==============================================================================
output "ecr_frontend_repository_url" {
  description = "The specific AWS Elastic Container Registry URL target used for frontend web tier containers."
  # FIXED: Matched exact block name declared in main.tf Section 5
  value = aws_ecr_repository.frontend_app.repository_url
}

output "ecr_backend_repository_url" {
  description = "The specific AWS Elastic Container Registry URL target used for backend API microservices."
  # FIXED: Matched exact block name declared in main.tf Section 5
  value = aws_ecr_repository.backend_api.repository_url
}

output "efs_id" {
  description = "The target AWS Elastic File System ID allocated to mount persistent volumes inside Kubernetes."
  value       = aws_efs_file_system.eks_efs.id
}



