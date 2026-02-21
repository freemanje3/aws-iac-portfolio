output "general_storage_kms_key_arn" {
  value       = aws_kms_key.general_storage.arn
  description = "ARN of the KMS CMK used for general data storage"
}

output "cloudwatch_kms_key_arn" {
  value       = aws_kms_key.cloudwatch_key.arn
  description = "ARN of the KMS CMK used strictly for CloudWatch Logs"
}

