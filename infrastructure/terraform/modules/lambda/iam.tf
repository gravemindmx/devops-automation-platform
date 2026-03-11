# =========================================
# IAM Role for Teams Notifier Lambda
# =========================================

resource "aws_iam_role" "teams_notifier_role" {
  name_prefix = "teams-notifier-role-"
  description = "IAM role for Teams Notifier Lambda function"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.project_name}-teams-notifier-role"
      Component = "iam"
    }
  )
}

# Basic Execution Role (CloudWatch Logs)
resource "aws_iam_role_policy_attachment" "teams_notifier_basic_execution" {
  role       = aws_iam_role.teams_notifier_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
