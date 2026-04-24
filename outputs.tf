output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app_repo.repository_url
}

output "efs_id" {
  value = aws_efs_file_system.eks_efs.id
}
