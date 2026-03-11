# =========================================
# Jenkins Module Variables
# =========================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC ID where Jenkins and ALB resources will be created"
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

variable "public_subnet_ids" {
  description = "List of public subnet IDs where ALB will be deployed (multi-AZ)"
  type        = list(string)
}

# =========================================
# ALB Configuration
# =========================================

variable "enable_load_balancer" {
  description = "Enable Application Load Balancer for public access to Jenkins"
  type        = bool
  default     = true
}

variable "enable_https" {
  description = "Enable HTTPS listener (requires valid ACM certificate)"
  type        = bool
  default     = false
}

variable "alb_port" {
  description = "ALB listener port (HTTP)"
  type        = number
  default     = 80
}

variable "acm_certificate_arn" {
  description = "ARN of ACM certificate for HTTPS (optional)"
  type        = string
  default     = null
}

# =========================================
# Jenkins Configuration
# =========================================

variable "jenkins_port" {
  description = "Jenkins application port"
  type        = number
  default     = 8080
}

# =========================================
# Network & Security
# =========================================

variable "allow_ssh_from_cidrs" {
  description = "CIDR blocks allowed for SSH access to Jenkins"
  type        = list(string)
  default     = ["0.0.0.0/0"] # IMPORTANT: Change in production!
}

variable "allow_http_from_cidrs" {
  description = "CIDR blocks allowed for HTTP access to ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "alb_name" {
  description = "Name of the Application Load Balancer"
  type        = string
  default     = "" # Will use project_name-alb if empty
}

# =========================================
# Tagging & Naming
# =========================================

variable "project_name" {
  description = "Project name for resource naming and tagging"
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
