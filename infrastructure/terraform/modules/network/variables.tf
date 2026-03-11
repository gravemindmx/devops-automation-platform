variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC ID where public subnets will be created"
  type        = string
}

variable "project_name" {
  description = "Project name for tagging resources"
  type        = string
  default     = "devops-platform"
}

variable "public_subnet_1_cidr" {
  description = "CIDR block for public subnet in AZ1"
  type        = string
  default     = "10.30.0.0/24"
}

variable "public_subnet_2_cidr" {
  description = "CIDR block for public subnet in AZ2"
  type        = string
  default     = "10.30.1.0/24"
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
