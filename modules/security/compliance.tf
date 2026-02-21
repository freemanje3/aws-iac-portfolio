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
data "aws_caller_identity" "current" {}
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
  name            = "nist-800-53-rev-5-compliance"
  # This pulls the official AWS-managed template for NIST directly from their regional S3 buckets
  template_s3_uri = "s3://config-conforms-${data.aws_region.current.name}/Operational-Best-Practices-for-NIST-800-53-rev-5.yaml"

  # Config must be fully turned on before it will allow a conformance pack to be deployed
  depends_on = [aws_config_configuration_recorder_status.main]
}