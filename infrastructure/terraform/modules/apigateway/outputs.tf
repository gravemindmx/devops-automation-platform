output "api_endpoint" {
  description = "API Gateway webhook endpoint for Jenkins"
  value       = "${aws_apigatewayv2_api.webhook_api.api_endpoint}/notify"
}

output "api_id" {
  description = "API Gateway API ID"
  value       = aws_apigatewayv2_api.webhook_api.id
}

output "api_arn" {
  description = "API Gateway execution ARN"
  value       = aws_apigatewayv2_api.webhook_api.execution_arn
}

output "stage_name" {
  description = "API Gateway stage name"
  value       = aws_apigatewayv2_stage.default.name
}
