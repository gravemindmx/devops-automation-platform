output "webhook_url" {
  value = module.api.api_endpoint
}

# =========================================
# Network Module Outputs
# =========================================

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = module.network.internet_gateway_id
}

output "public_subnet_az1_id" {
  description = "Public subnet ID in AZ1"
  value       = module.network.public_subnet_az1_id
}

output "public_subnet_az2_id" {
  description = "Public subnet ID in AZ2"
  value       = module.network.public_subnet_az2_id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.network.public_subnet_ids
}

output "public_route_table_id" {
  description = "Public route table ID"
  value       = module.network.public_route_table_id
}

output "network_infrastructure" {
  description = "Network infrastructure summary"
  value       = module.network.public_subnets_info
}

# =========================================
# Jenkins Module Outputs
# =========================================

output "jenkins_instance_id" {
  description = "ID of existing Jenkins EC2 instance"
  value       = module.jenkins.jenkins_instance_id
}

output "jenkins_private_ip" {
  description = "Private IP address of Jenkins EC2"
  value       = module.jenkins.jenkins_instance_private_ip
}

output "jenkins_public_url" {
  description = "Public URL to access Jenkins via ALB"
  value       = module.jenkins.jenkins_public_url
}

output "jenkins_ssh_command" {
  description = "SSH command to connect to Jenkins"
  value       = module.jenkins.jenkins_ssh_command
}

output "alb_dns_name" {
  description = "DNS name of Application Load Balancer"
  value       = module.jenkins.alb_dns_name
}

output "alb_arn" {
  description = "ARN of Application Load Balancer"
  value       = module.jenkins.alb_arn
}

output "jenkins_security_group_id" {
  description = "ID of Jenkins internal security group"
  value       = module.jenkins.jenkins_security_group_id
}

output "alb_security_group_id" {
  description = "ID of ALB external security group"
  value       = module.jenkins.alb_security_group_id
}

# =========================================
# Lambda Module Outputs (Teams Notifier)
# =========================================

output "teams_notifier_function_name" {
  description = "Name of Teams Notifier Lambda function"
  value       = module.lambda.function_name
}

output "teams_notifier_arn" {
  description = "ARN of Teams Notifier Lambda function"
  value       = module.lambda.function_arn
}

output "teams_notifier_invoke_arn" {
  description = "Invoke ARN of Teams Notifier Lambda function"
  value       = module.lambda.invoke_arn
}

output "teams_notifier_role_arn" {
  description = "ARN of Lambda Teams Notifier IAM role"
  value       = module.lambda.role_arn
}

output "teams_notifier_role_name" {
  description = "Name of Lambda Teams Notifier IAM role"
  value       = module.lambda.role_name
}