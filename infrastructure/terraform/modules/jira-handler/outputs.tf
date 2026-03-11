output "jira_handler_arn" {
  description = "ARN of Jira event handler Lambda function"
  value       = aws_lambda_function.jira_event_handler.arn
}

output "jira_handler_function_name" {
  description = "Name of Jira event handler Lambda function"
  value       = aws_lambda_function.jira_event_handler.function_name
}

output "jira_handler_invoke_arn" {
  description = "Invoke ARN of Jira event handler Lambda function"
  value       = aws_lambda_function.jira_event_handler.invoke_arn
}

output "role_arn" {
  description = "ARN of IAM role for Jira handler"
  value       = aws_iam_role.jira_handler.arn
}

output "role_name" {
  description = "Name of IAM role for Jira handler"
  value       = aws_iam_role.jira_handler.name
}
