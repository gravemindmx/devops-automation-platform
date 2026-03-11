variable "lambda_invoke_arn" {
  description = "Invoke ARN of the teams-notifier Lambda (POST /notify)"
  type        = string
}

variable "jira_lambda_invoke_arn" {
  description = "Invoke ARN of the jira-event-handler Lambda (POST /jira)"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "devops-platform"
}

variable "api_name" {
  description = "API Gateway name"
  type        = string
  default     = "webhook-api"
}

variable "common_tags" {
  description = "Common tags for resources"
  type        = map(string)
  default = {
    Environment = "production"
    Project     = "devops-automation-platform"
    ManagedBy   = "terraform"
  }
}
