variable "jira_url" {
  description = "Jira base URL"
  type        = string
}

variable "jira_api_token" {
  description = "Jira API token for authentication"
  type        = string
  sensitive   = true
  default     = ""
}

variable "teams_webhook_url" {
  description = "Microsoft Teams webhook URL"
  type        = string
  sensitive   = true
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "devops-platform"
}

variable "function_name" {
  description = "Lambda function name"
  type        = string
  default     = "jira-event-handler"
}

variable "handler" {
  description = "Lambda handler path"
  type        = string
  default     = "handler.lambda_handler"
}

variable "runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.11"
}

variable "timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 30
}

variable "memory_size" {
  description = "Lambda memory size in MB"
  type        = number
  default     = 128
}

variable "lambda_zip_path" {
  description = "Path to Lambda function zip file"
  type        = string
  default     = "../../../../services/jira-event-handler/jira-handler.zip"
}

variable "environment_variables" {
  description = "Additional environment variables"
  type        = map(string)
  default     = {}
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
