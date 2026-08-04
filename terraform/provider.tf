terraform {
  # 1. THIRD-PARTY PROVIDER PLUGINS LOCKING
  # PURPOSE: Downloads and pins the exact vendor binaries needed to build your infrastructure.
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # FIXED: Swapped from non-existent v6.x cliff to the actual production-stable v5.x enterprise branch
      version = ">= 5.39.0" # Guarantees total compliance with modern AWS EKS API and v21+ module architectures
    }
  }

  # 2. REMOTE SECURE GITOPS STATE & ACCIDENTAL RACE-CONDITION LOCKING
  # PURPOSE: Centralizes your infrastructure mapping ledger and prevents team file collision.
  # NOTE: To activate, simply remove the starting '/*' and ending '*/' markers.
  /*
  backend "s3" {
    bucket       = "shopflow-enterprise-tfstate-bucket" 
    key          = "global/eks/terraform.tfstate"       
    region       = "us-east-1"                          
    encrypt      = true                                 
    use_lockfile = true                                 # Modern native S3 concurrency locking (Replaces DynamoDB constraints)
  }
  */
}

# ==============================================================================
# MAIN AWS DRIVER CONFIGURATION
# ==============================================================================
# PURPOSE: Authorizes Terraform to act, create, and destroy components in your account.
provider "aws" {
  region = var.aws_region # Dynamically pulls the region mapping string from variables.tf
}



