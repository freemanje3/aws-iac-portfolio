# ------------------------------------------------------------------------------
# 1. CLOUDWATCH LOG GROUP FOR SSM SESSIONS
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "ssm_session_logs" {
  name              = "/aws/ssm/session-logs"
  retention_in_days = 90
  
  # Added the new CloudWatch CMK here!
  kms_key_id        = aws_kms_key.cloudwatch_key.arn
}

# ------------------------------------------------------------------------------
# 2. SESSION MANAGER PREFERENCES DOCUMENT
# ------------------------------------------------------------------------------
resource "aws_ssm_document" "session_manager_prefs" {
  name            = "SSM-SessionManagerRunShell"
  document_type   = "Session"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "1.0"
    description   = "Document to hold regional settings for Session Manager"
    sessionType   = "Standard_Stream"
    inputs = {
      cloudWatchLogGroupName      = aws_cloudwatch_log_group.ssm_session_logs.name
      
      # Flipped to true and passed the new key ARN!
      cloudWatchEncryptionEnabled = true 
      kmsKeyId                    = aws_kms_key.cloudwatch_key.arn
      
      cloudWatchStreamingEnabled  = true
      runAsEnabled                = true
      runAsDefaultUser            = "" 
      idleSessionTimeout          = "20"
    }
  })
}