# =========================================
# API Gateway - REST API Definition
# =========================================

resource "aws_apigatewayv2_api" "webhook_api" {
  name          = "${var.project_name}-${var.api_name}"
  protocol_type = "HTTP"

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.project_name}-webhook-api"
      Component = "apigateway"
    }
  )
}

# =========================================
# Lambda Integration
# =========================================

resource "aws_apigatewayv2_integration" "lambda" {
  api_id           = aws_apigatewayv2_api.webhook_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = var.lambda_invoke_arn

  payload_format_version = "2.0"
}

# =========================================
# API Routes
# =========================================

resource "aws_apigatewayv2_route" "notify" {
  api_id    = aws_apigatewayv2_api.webhook_api.id
  route_key = "POST /notify"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# =========================================
# API Stage
# =========================================

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.webhook_api.id
  name        = "$default"
  auto_deploy = true

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.project_name}-default-stage"
      Component = "apigateway"
    }
  )
}

# =========================================
# Lambda Permission for API Gateway
# =========================================

resource "aws_lambda_permission" "apigateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.webhook_api.execution_arn}/*"
}

# =========================================
# Jira Webhook - Integration, Route & Permission
# =========================================

resource "aws_apigatewayv2_integration" "jira_lambda" {
  api_id           = aws_apigatewayv2_api.webhook_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = var.jira_lambda_invoke_arn

  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "jira_webhook" {
  api_id    = aws_apigatewayv2_api.webhook_api.id
  route_key = "POST /jira"
  target    = "integrations/${aws_apigatewayv2_integration.jira_lambda.id}"
}

resource "aws_lambda_permission" "jira_apigateway_invoke" {
  statement_id  = "AllowAPIGatewayInvokeJira"
  action        = "lambda:InvokeFunction"
  function_name = var.jira_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.webhook_api.execution_arn}/*"
}
