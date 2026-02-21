# ------------------------------------------------------------------------------
# 1. Dedicated KMS Key for CloudTrail
# ------------------------------------------------------------------------------
resource "aws_kms_key" "cloudtrail_key" {
  description             = "CMK for encrypting CloudTrail logs"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.cloudtrail_kms_policy.json
}

resource "aws_kms_alias" "cloudtrail_key_alias" {
  name          = "alias/portfolio-cloudtrail-key"
  target_key_id = aws_kms_key.cloudtrail_key.key_id
}

data "aws_iam_policy_document" "cloudtrail_kms_policy" {
  # Allow the account root to manage the key
  statement {
    sid       = "Enable IAM User Permissions"
    effect    = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  # Allow CloudTrail to encrypt the logs
  statement {
    sid       = "Allow CloudTrail to encrypt logs"
    effect    = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["kms:GenerateDataKey*"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:cloudtrail:arn"
      values   = ["arn:aws:cloudtrail:*:${data.aws_caller_identity.current.account_id}:trail/*"]
    }
  }

  # Allow CloudTrail to describe the key
  statement {
    sid       = "Allow CloudTrail to describe key"
    effect    = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["kms:DescribeKey"]
    resources = ["*"]
  }
}

# ------------------------------------------------------------------------------
# 2. Enforce CMK Encryption on the S3 Bucket
# ------------------------------------------------------------------------------
# (Assuming your aws_s3_bucket "cloudtrail" is already defined above this)

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_encryption" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.cloudtrail_key.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# ------------------------------------------------------------------------------
# 3. Updated CloudTrail Resource
# ------------------------------------------------------------------------------
resource "aws_cloudtrail" "main" {
  name                          = "portfolio-audit-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  
  # Forward to CloudWatch
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_cloudwatch.arn

  # Explicitly tell CloudTrail to use your new CMK
  kms_key_id                    = aws_kms_key.cloudtrail_key.arn

  # Prevent infinite log loops for S3 Data Events (Best Practice)
  advanced_event_selector {
    name = "Log all management events"
    field_selector {
      field  = "eventCategory"
      equals = ["Management"]
    }
  }

  advanced_event_selector {
    name = "Log S3 data events but exclude the CloudTrail bucket"
    field_selector {
      field  = "eventCategory"
      equals = ["Data"]
    }
    field_selector {
      field  = "resources.type"
      equals = ["AWS::S3::Object"]
    }
    field_selector {
      field           = "resources.ARN"
      not_starts_with = ["${aws_s3_bucket.cloudtrail.arn}/"]
    }
  }

  depends_on = [
    aws_s3_bucket_policy.cloudtrail,
    aws_s3_bucket_server_side_encryption_configuration.cloudtrail_encryption
  ]
}

# ------------------------------------------------------------------------------
# 4. CloudWatch Log Group for EC2 Server Logs
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "ec2_cw_agent" {
  # This is the destination name your servers will look for
  name              = "/aws/ec2/cloudwatch-agent-logs"
  retention_in_days = 90
  
  # Optional but recommended for production: 
  # Encrypt these logs using the KMS key we created earlier
  kms_key_id        = aws_kms_key.cloudtrail_key.arn 
}