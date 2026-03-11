# =========================================
# Global Variables
# =========================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for naming and tagging resources"
  type        = string
  default     = "devops-platform"
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "production"
    Project     = "devops-automation-platform"
    ManagedBy   = "terraform"
  }
}

# =========================================
# AWS Infrastructure (Existing) 
# =========================================

variable "vpc_id" {
  description = "ID of the VPC where Jenkins and infrastructure exist"
  type        = string
}

variable "jenkins_instance_id" {
  description = "ID of existing Jenkins EC2 instance (PRIVATE)"
  type        = string
}

variable "private_subnet_id" {
  description = "ID of private subnet where Jenkins EC2 is located"
  type        = string
}

# =========================================
# Load Balancer Configuration
# =========================================

variable "enable_load_balancer" {
  description = "Enable Application Load Balancer for public access to Jenkins"
  type        = bool
  default     = true
}

variable "alb_port" {
  description = "ALB listener port (HTTP)"
  type        = number
  default     = 80
}

# =========================================
# Jenkins Configuration
# =========================================

variable "jenkins_port" {
  description = "Jenkins application port"
  type        = number
  default     = 8080
}

variable "github_token" {
  description = "GitHub token for automation"
  type        = string
  sensitive   = true
}

variable "github_org" {
  description = "GitHub organization"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "jenkins_admin_user" {
  description = "Jenkins admin user"
  type        = string
  default     = "admin"
}

# =========================================
# Jira Configuration
# =========================================

variable "jira_url" {
  description = "Jira URL"
  type        = string
}

variable "jira_api_token" {
  description = "Jira API token"
  type        = string
  sensitive   = true
}

variable "jira_project_key" {
  description = "Jira project key"
  type        = string
  default     = "DEVOPS"
}

variable "jira_assignee_user" {
  description = "Default Jira assignee"
  type        = string
  default     = "qa-team"
}

# =========================================
# Teams Webhooks
# =========================================

variable "teams_webhook_url" {
  description = "Teams webhook URL (General channel)"
  type        = string
  sensitive   = true
}

variable "teams_qa_webhook_url" {
  description = "Teams webhook URL (QA channel)"
  type        = string
  sensitive   = true
}

# =========================================
# QA Environment
# =========================================

variable "qa_environment_url" {
  description = "QA environment URL"
  type        = string
  default     = "https://qa-api.example.com"
}