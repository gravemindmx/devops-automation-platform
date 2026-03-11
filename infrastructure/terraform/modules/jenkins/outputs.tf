# =========================================
# Jenkins Module Outputs
# =========================================

# =========================================
# Jenkins Instance Information
# =========================================

output "jenkins_instance_id" {
  description = "ID of existing Jenkins EC2 instance"
  value       = data.aws_instance.jenkins_main.id
}

output "jenkins_instance_private_ip" {
  description = "Private IP address of Jenkins EC2"
  value       = data.aws_instance.jenkins_main.private_ip
}

output "jenkins_instance_availability_zone" {
  description = "Availability zone of Jenkins instance"
  value       = data.aws_instance.jenkins_main.availability_zone
}

# =========================================
# ALB Information
# =========================================

output "alb_id" {
  description = "ID of Application Load Balancer"
  value       = try(aws_lb.jenkins_public_alb[0].id, null)
}

output "alb_arn" {
  description = "ARN of Application Load Balancer"
  value       = try(aws_lb.jenkins_public_alb[0].arn, null)
}

output "alb_dns_name" {
  description = "DNS name of Application Load Balancer (public access to Jenkins)"
  value       = try(aws_lb.jenkins_public_alb[0].dns_name, null)
}

output "alb_zone_id" {
  description = "Zone ID of Application Load Balancer"
  value       = try(aws_lb.jenkins_public_alb[0].zone_id, null)
}

# =========================================
# Jenkins Access URL (via ALB)
# =========================================

output "jenkins_public_url" {
  description = "Public URL to access Jenkins through ALB"
  value       = var.enable_load_balancer ? "http://${aws_lb.jenkins_public_alb[0].dns_name}:${var.alb_port}" : "Jenkins is private only"
}

output "jenkins_ssh_command" {
  description = "SSH command to connect to Jenkins (requires bastion/VPN as Jenkins is private)"
  value       = "ssh -i /path/to/key.pem ec2-user@${data.aws_instance.jenkins_main.private_ip}"
}

# =========================================
# Target Group Information
# =========================================

output "target_group_id" {
  description = "ARN of Jenkins target group"
  value       = try(aws_lb_target_group.jenkins_targets[0].id, null)
}

output "target_group_arn" {
  description = "ARN of Jenkins target group"
  value       = try(aws_lb_target_group.jenkins_targets[0].arn, null)
}

# =========================================
# Security Group Information
# =========================================

output "jenkins_security_group_id" {
  description = "ID of security group for Jenkins private EC2"
  value       = aws_security_group.jenkins_internal.id
}

output "jenkins_security_group_name" {
  description = "Name of security group for Jenkins"
  value       = aws_security_group.jenkins_internal.name
}

output "alb_security_group_id" {
  description = "ID of security group for ALB (public-facing)"
  value       = aws_security_group.alb_external.id
}

output "alb_security_group_name" {
  description = "Name of security group for ALB"
  value       = aws_security_group.alb_external.name
}

# =========================================
# IAM Role Information
# =========================================

output "jenkins_iam_role_arn" {
  description = "ARN of Jenkins EC2 IAM role"
  value       = aws_iam_role.jenkins_instance_role.arn
}

output "jenkins_iam_role_name" {
  description = "Name of Jenkins EC2 IAM role"
  value       = aws_iam_role.jenkins_instance_role.name
}

output "jenkins_instance_profile_arn" {
  description = "ARN of Jenkins EC2 instance profile"
  value       = aws_iam_instance_profile.jenkins_instance_profile.arn
}

# =========================================
# Summary
# =========================================

output "jenkins_infrastructure_summary" {
  description = "Summary of Jenkins infrastructure"
  value = {
    jenkins_instance   = data.aws_instance.jenkins_main.id
    jenkins_private_ip = data.aws_instance.jenkins_main.private_ip
    alb_public_dns     = try(aws_lb.jenkins_public_alb[0].dns_name, null)
    jenkins_public_url = var.enable_load_balancer ? "http://${aws_lb.jenkins_public_alb[0].dns_name}:${var.alb_port}" : "Jenkins is private only"
    alb_id             = try(aws_lb.jenkins_public_alb[0].id, null)
    jenkins_sg_id      = aws_security_group.jenkins_internal.id
    alb_sg_id          = aws_security_group.alb_external.id
  }
}
