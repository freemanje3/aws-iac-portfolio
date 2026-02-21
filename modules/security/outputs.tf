output "general_storage_kms_key_arn" {
  value       = aws_kms_key.general_storage.arn
  description = "ARN of the KMS CMK used for general data storage"
}