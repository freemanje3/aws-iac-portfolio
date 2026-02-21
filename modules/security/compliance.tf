# ------------------------------------------------------------------------------
# 1. GUARDDUTY ENABLEMENT
# ------------------------------------------------------------------------------
resource "aws_guardduty_detector" "primary" {
  enable = true
  
  tags = {
    Name = "portfolio-guardduty-detector"
  }
}

# ------------------------------------------------------------------------------
# 2. AWS CONFIG LOGGING BUCKET
# ------------------------------------------------------------------------------
# Note: aws_caller_identity is omitted here because it already exists in cw_ct.tf
data "aws_region" "current" {}

resource "aws_s3_bucket" "config_logs" {
  bucket        = "portfolio-config-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_policy" "config_logs_policy" {
  bucket = aws_s3_bucket.config_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowConfigGetBucketAcl"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.config_logs.arn
      },
      {
        Sid       = "AllowConfigPutObject"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.config_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# 2.5 AWS CONFIG KMS CMK & S3 ENCRYPTION
# ------------------------------------------------------------------------------
resource "aws_kms_key" "config_key" {
  description             = "KMS CMK for AWS Config S3 bucket encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "config-kms-policy"
    Statement = [
      {
        Sid       = "Enable IAM User Permissions"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "Allow Config Service to encrypt logs"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = [
          "kms:GenerateDataKey",
          "kms:Decrypt"
        ]
        Resource  = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "config_key_alias" {
  name          = "alias/portfolio-config-key"
  target_key_id = aws_kms_key.config_key.key_id
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config_encryption" {
  bucket = aws_s3_bucket.config_logs.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.config_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# ------------------------------------------------------------------------------
# 3. AWS CONFIG RECORDER & DELIVERY CHANNEL
# ------------------------------------------------------------------------------
resource "aws_iam_role" "config_role" {
  name = "portfolio-aws-config-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "config_policy" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_config_configuration_recorder" "main" {
  name     = "portfolio-config-recorder"
  role_arn = aws_iam_role.config_role.arn
  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "main" {
  name           = "portfolio-config-delivery-channel"
  s3_bucket_name = aws_s3_bucket.config_logs.bucket
  
  # The delivery channel will fail to build if the bucket policy isn't attached first
  depends_on = [
    aws_config_configuration_recorder.main,
    aws_s3_bucket_policy.config_logs_policy
  ]
}

resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.main]
}

# ------------------------------------------------------------------------------
# 4. NIST 800-53 REV 5 CONFORMANCE PACK
# ------------------------------------------------------------------------------
resource "aws_config_conformance_pack" "nist_800_53" {
  name          = "nist-800-53-rev-5-compliance"
  
  # Using the local file we downloaded to bypass the broken AWS S3 link!
  template_body = file("${path.module}/nist-800-53-rev-5.yaml")

  depends_on = [aws_config_configuration_recorder_status.main]
}