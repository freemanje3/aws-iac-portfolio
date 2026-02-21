resource "aws_kms_key" "general_storage" {
  description             = "CMK for general portfolio data storage (EBS, RDS, App S3)"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  # Standard policy allowing the account (and IAM roles like GitHub Actions) to use the key
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "general-storage-key-policy"
    Statement = [
      {
        Sid    = "EnableIAMUserPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "portfolio-general-storage-key"
  }
}

resource "aws_kms_alias" "general_storage_alias" {
  name          = "alias/portfolio-storage-key"
  target_key_id = aws_kms_key.general_storage.key_id
}