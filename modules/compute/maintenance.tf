# ------------------------------------------------------------------------------
# 1. DATA BLOCKS (Find the VPC and Subnets)
# ------------------------------------------------------------------------------
data "aws_vpc" "prod" {
  id = "vpc-085c6877b5bdac2f0"
}
 
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.prod.id]
  }
}

# ------------------------------------------------------------------------------
# 2. SECURITY GROUP (Outbound Only)
# ------------------------------------------------------------------------------
resource "aws_security_group" "maintenance_sg" {
  name        = "maintenance-server-sg"
  description = "Allow outbound for SSM and CloudWatch, strictly NO inbound"
  vpc_id      = data.aws_vpc.prod.id

  # Completely open outbound so the SSM/CW Agents can talk to AWS endpoints
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "maintenance-sg"
  }
}

# ------------------------------------------------------------------------------
# 3. IAM ROLE & INSTANCE PROFILE
# ------------------------------------------------------------------------------
resource "aws_iam_role" "maintenance_role" {
  name = "maintenance-server-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
      }
    ]
  })
}

# AWS Managed Policy for Systems Manager Session Manager
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.maintenance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# AWS Managed Policy for CloudWatch Agent
resource "aws_iam_role_policy_attachment" "cw_agent" {
  role       = aws_iam_role.maintenance_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "maintenance_profile" {
  name = "maintenance-server-profile"
  role = aws_iam_role.maintenance_role.name
}

resource "aws_iam_role_policy" "ssm_cw_logs" {
  name = "maintenance-ssm-cw-logs"
  role = aws_iam_role.maintenance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      },
      # Add this new block to grant KMS permissions
      {
        Effect = "Allow"
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt"
        ]
        Resource = var.cloudwatch_kms_key_arn 
      }
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# 4. EC2 INSTANCE (The Maintenance Server)
# ------------------------------------------------------------------------------
resource "aws_instance" "maintenance" {
  ami                    = "ami-0193a989c35eb8d11"
  instance_type          = "t3.medium"
  # Place it in the first available private subnet
  subnet_id              = tolist(data.aws_subnets.private.ids)[0] 
  iam_instance_profile   = aws_iam_instance_profile.maintenance_profile.name
  vpc_security_group_ids = [aws_security_group.maintenance_sg.id]

  # Enforce encrypted root volume using the general storage CMK
  root_block_device {
    encrypted   = true
    kms_key_id  = var.storage_kms_key_arn
    volume_type = "gp3"
    volume_size = 20
  }

  # Install and configure the CloudWatch Agent to push system logs
  user_data = <<-EOF
    #!/bin/bash
    dnf install -y amazon-cloudwatch-agent
    
    cat <<'CWCONFIG' > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
    {
      "agent": {
        "run_as_user": "root"
      },
      "logs": {
        "logs_collected": {
          "files": {
            "collect_list": [
              {
                "file_path": "/var/log/messages",
                "log_group_name": "/aws/ec2/cloudwatch-agent-logs",
                "log_stream_name": "{instance_id}/messages",
                "timezone": "UTC"
              },
              {
                "file_path": "/var/log/secure",
                "log_group_name": "/aws/ec2/cloudwatch-agent-logs",
                "log_stream_name": "{instance_id}/secure",
                "timezone": "UTC"
              }
            ]
          }
        }
      }
    }
    CWCONFIG
    
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
    systemctl enable amazon-cloudwatch-agent
    systemctl start amazon-cloudwatch-agent
  EOF

  tags = {
    Name = "maintenance_server"
  }
}