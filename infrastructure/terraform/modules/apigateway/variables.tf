variable "lambda_invoke_arn" {
  description = "Lambda function invoke ARN for API Gateway integration"
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
