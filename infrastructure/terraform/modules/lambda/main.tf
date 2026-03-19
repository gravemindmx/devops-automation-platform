# =========================================
# Teams Notifier Lambda Function
# =========================================
# Lambda que recibe eventos de Jenkins CI/CD y envía notificaciones a Teams

resource "aws_lambda_function" "teams_notifier_function" {
  function_name = "${var.project_name}-teams-notifier"
  runtime       = "python3.11"
  handler       = "lambda.lambda_handler"
  filename      = var.lambda_zip_path

  role = aws_iam_role.teams_notifier_role.arn

  environment {
    variables = {
      TEAMS_WEBHOOK         = var.teams_webhook_url
      TEAMS_FAILURE_WEBHOOK = var.teams_failure_webhook_url
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.project_name}-teams-notifier"
      Component = "lambda"
    }
  )

  depends_on = [aws_iam_role_policy_attachment.teams_notifier_basic_execution]
}
