# ==============================================================================
# ENTERPRISE GLOBAL INFRASTRUCTURE VARIABLES (variables.tf)
# ==============================================================================
# PURPOSE: 
# 1. Centralizes configuration variables to eliminate environment hardcoding.
# 2. Enforces input validation rules to catch deployment typos before execution.
# ==============================================================================

variable "aws_region" {
  type        = string
  description = "The target AWS Region where all primary resources will be provisioned."
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "The aws_region variable must be a valid AWS region format (e.g., us-east-1, eu-west-1)."
  }
}

variable "cluster_name" {
  type        = string
  description = "The corporate naming convention identifier assigned to the target EKS Cluster."
  default     = "shopflow-k8s" # UPDATED: Matches the cluster name defined in your Jenkinsfile environment block

  validation {
    condition     = length(var.cluster_name) <= 100 && can(regex("^[a-zA-Z0-9-_]+$", var.cluster_name))
    error_message = "The cluster_name must be 100 characters or less and can only contain alphanumeric characters, dashes, and underscores."
  }
}

variable "vpc_cidr" {
  type        = string
  description = "The primary IPv4 Classless Inter-Domain Routing (CIDR) block allocated for the core VPC network layout."
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "The vpc_cidr variable must be a valid IPv4 CIDR address block (e.g., 10.0.0.0/16)."
  }
}

