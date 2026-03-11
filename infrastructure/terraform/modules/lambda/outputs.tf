output "function_name" {
  description = "Name of Teams Notifier Lambda function"
  value       = aws_lambda_function.teams_notifier_function.function_name
}

output "function_arn" {
  description = "ARN of Teams Notifier Lambda function"
  value       = aws_lambda_function.teams_notifier_function.arn
}

output "invoke_arn" {
  description = "Invoke ARN of Teams Notifier Lambda function"
  value       = aws_lambda_function.teams_notifier_function.invoke_arn
}

output "role_arn" {
  description = "ARN of IAM role for Teams Notifier Lambda"
  value       = aws_iam_role.teams_notifier_role.arn
}

output "role_name" {
  description = "Name of IAM role for Teams Notifier Lambda"
  value       = aws_iam_role.teams_notifier_role.name
}
