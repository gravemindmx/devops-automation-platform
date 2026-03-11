# =========================================
# IAM Role for Jira Handler Lambda
# =========================================

resource "aws_iam_role" "jira_handler" {
  name_prefix = "jira-event-handler-"
  description = "IAM role for Jira event handler Lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.project_name}-jira-handler-role"
      Component = "iam"
    }
  )
}

# =========================================
# IAM Policy - CloudWatch Logs
# =========================================

resource "aws_iam_role_policy" "jira_handler_logs" {
  name_prefix = "jira-handler-logs-"
  role        = aws_iam_role.jira_handler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}
