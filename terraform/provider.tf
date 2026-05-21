# ==============================================================================
# ENTERPRISE PROVIDER & BACKEND STATE DEFINITION (provider.tf)
# ==============================================================================
# PURPOSE: 
# 1. Configures required third-party API plugins (AWS Provider).
# 2. Migrates state tracking to an encrypted AWS S3 bucket.
# 3. Enforces strict team concurrency locking via native S3 conditional writes.
# ==============================================================================

terraform {
  # 1. THIRD-PARTY PROVIDER PLUGINS LOCKING
  # PURPOSE: Downloads and pins the exact vendor binaries needed to build your infrastructure.
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.28.0" # Ensures compatibility with modern AWS EKS API features
    }
  }

  # 2. REMOTE SECURE GITOPS STATE & ACCIDENTAL RACE-CONDITION LOCKING
  # PURPOSE: Centralizes your infrastructure mapping ledger and prevents team file collision.
  /*backend "s3" {
    bucket       = "shopflow-enterprise-tfstate-bucket" # MATCHES: Your created S3 Bucket name
    key          = "global/eks/terraform.tfstate"       # The persistent storage file path inside the bucket
    region       = "us-east-1"                          # Matches the deployment infrastructure region
    encrypt      = true                                 # Enforces mandatory AES-256 state encryption at rest
    use_lockfile = true                                 # Modern native S3 concurrency locking (Replaces DynamoDB)
  }*/
}

# ==============================================================================
# MAIN AWS DRIVER CONFIGURATION
# ==============================================================================
# PURPOSE: Authorizes Terraform to act, create, and destroy components in your account.
provider "aws" {
  region = var.aws_region # Dynamically pulls the region mapping string from variables.tf
}



