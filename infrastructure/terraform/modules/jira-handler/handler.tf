# =========================================
# Lambda Function - Jira Event Handler
# =========================================

resource "aws_lambda_function" "jira_event_handler" {
  function_name = "${var.project_name}-${var.function_name}"
  role          = aws_iam_role.jira_handler.arn
  handler       = var.handler
  runtime       = var.runtime
  timeout       = var.timeout
  memory_size   = var.memory_size
  filename      = var.lambda_zip_path

  environment {
    variables = merge(
      {
        TEAMS_WEBHOOK = var.teams_webhook_url
        JIRA_URL      = var.jira_url
      },
      var.environment_variables
    )
  }

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.project_name}-jira-event-handler"
      Component = "lambda"
    }
  )

  depends_on = [aws_iam_role_policy.jira_handler_logs]
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

# =========================================
# Lambda Permission - API Gateway Invoke
# =========================================

resource "aws_lambda_permission" "jira_event_handler_api" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.jira_event_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*/*/*/*"
}
