# ------------------------------------------------------------------------------
# KMS Customer Managed Key (CMK)
# ------------------------------------------------------------------------------
resource "aws_kms_key" "terraform_state" {
  description             = "CMK for encrypting Terraform remote state"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  # This protects the key from accidental deletion
  lifecycle {
    prevent_destroy = true 
  }
}

resource "aws_kms_alias" "terraform_state_alias" {
  name          = "alias/terraform-state-key"
  target_key_id = aws_kms_key.terraform_state.key_id
}
# ------------------------------------------------------------------------------
# S3 Bucket for Secure State Storage
# ------------------------------------------------------------------------------
resource "aws_s3_bucket" "secure_state" {
  # CRITICAL: Change this to a new unique name
  bucket = "jamesfreeman-cmk-secure-state-99999" 

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "secure_state" {
  bucket = aws_s3_bucket.secure_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Force CMK Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "secure_state" {
  bucket = aws_s3_bucket.secure_state.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.terraform_state.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "secure_state" {
  bucket                  = aws_s3_bucket.secure_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ------------------------------------------------------------------------------
# Strict S3 Bucket Policy (Enforce TLS)
# ------------------------------------------------------------------------------
resource "aws_s3_bucket_policy" "secure_state_policy" {
  bucket = aws_s3_bucket.secure_state.id
  policy = data.aws_iam_policy_document.secure_state_policy.json
}

data "aws_iam_policy_document" "secure_state_policy" {
  # Explicitly deny any request that does not use HTTPS/TLS
  statement {
    sid       = "EnforceSecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [
      aws_s3_bucket.secure_state.arn,
      "${aws_s3_bucket.secure_state.arn}/*"
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

# ------------------------------------------------------------------------------
# DynamoDB Table for State Locking
# ------------------------------------------------------------------------------
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-state-locks-secure"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# ------------------------------------------------------------------------------
# Outputs
# ------------------------------------------------------------------------------
output "kms_key_arn" {
  value = aws_kms_key.terraform_state.arn
}

output "s3_bucket_name" {
  value = aws_s3_bucket.secure_state.bucket
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.terraform_locks.name
}