# ==============================================================================
# SECURE AWS S3 BUCKET FOR REMOTE STATE STORAGE
# ==============================================================================
# PURPOSE: Stores your encrypted terraform.tfstate file safely in the cloud.
resource "aws_s3_bucket" "terraform_state" {
  bucket        = "shopflow-enterprise-tfstate-bucket" # MUST BE GLOBALLY UNIQUE
  force_destroy = false                                # Prevents accidental deletion of your infrastructure logs

  lifecycle {
    prevent_destroy = true # Production safety gate: stops automated scripts from wiping this bucket
  }
}

# ENFORCE VERSIONING CONTROL ON STATE HISTORY
# PURPOSE: Keeps a complete history of every single infrastructure change.
# DETAIL: If a bad Terraform apply breaks your EKS cluster, you can rollback to an old state version.
resource "aws_s3_bucket_versioning" "state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# ENFORCE SERVER-SIDE ENCRYPTION (AES-256)
# PURPOSE: Encrypts your state file at rest. Your state file contains plaintext database passwords.
resource "aws_s3_bucket_server_side_encryption_configuration" "state_encryption" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ==============================================================================
# AWS DYNAMODB TABLE FOR CONCURRENCY LOCKING
# ==============================================================================
# PURPOSE: Prevents data race conditions. Freezes adjustments when a team member runs an apply.
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "shopflow-enterprise-tf-locks"
  billing_mode = "PAY_PER_REQUEST" # On-demand pricing: scales costs to zero when pipelines aren't active
  hash_key     = "LockID"          # MANDATORY: Terraform expects this exact attribute name (Case-Sensitive)

  attribute {
    name = "LockID"
    type = "S" # String type restriction
  }
}
