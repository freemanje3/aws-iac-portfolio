# 1. READ the existing GitHub OIDC Provider
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# 2. Define the Trust Policy (AssumeRoleWithWebIdentity)
data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      # Notice this is now data.aws_iam...
      identifiers = [data.aws_iam_openid_connect_provider.github.arn] 
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Locked down to your specific repository and main branch
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:freemanje3/aws-iac-portfolio:ref:refs/heads/main"]
    }
  }
}

# 3. Create the IAM Role
resource "aws_iam_role" "github_actions_deploy_role" {
  name               = "github-actions-portfolio-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json
}

# 4. Attach Permissions 
# Note: Using AdministratorAccess for initial pipeline testing. 
# To maintain a secure architecture, you should eventually scope this down to least-privilege.
resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  role       = aws_iam_role.github_actions_deploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess" 
}

# 5. Output the Role ARN so you can easily copy it to your GitHub Actions workflow
output "github_actions_role_arn" {
  value = aws_iam_role.github_actions_deploy_role.arn
}