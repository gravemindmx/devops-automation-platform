variable "teams_webhook_url" {
  description = "Teams Webhook URL for notifications"
  type        = string
  sensitive   = true
}

variable "lambda_zip_path" {
  description = "Path to Lambda function zip file"
  type        = string
  default     = "../../../services/teams-notifier/lambda.zip"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "devops-platform"
}

variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "teams-notifier"
}

variable "handler" {
  description = "Handler for the Lambda function"
  type        = string
  default     = "lambda.lambda_handler"
}

variable "runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.11"
}

variable "timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 60
}

variable "memory_size" {
  description = "Lambda memory size in MB"
  type        = number
  default     = 128
}

variable "environment_variables" {
  description = "Environment variables for Lambda function"
  type        = map(string)
  default     = {}
}

variable "ephemeral_storage" {
  description = "Ephemeral storage size in MB"
  type        = number
  default     = 512
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
