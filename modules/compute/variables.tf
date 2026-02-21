variable "storage_kms_key_arn" {
  description = "ARN of the KMS CMK for general storage"
  type        = string
}
variable "cloudwatch_kms_key_arn" {
  description = "ARN of the KMS CMK strictly for CloudWatch Logs"
  type        = string
}