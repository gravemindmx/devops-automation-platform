# =========================================
# Jenkins Infrastructure - Data Sources
# =========================================
# Referencias a recursos existentes (Jenkins EC2, VPC)
# Estos NO se crean por Terraform, solo se referencian

# Data source: Jenkins EC2 Instance (existente)
data "aws_instance" "jenkins_main" {
  instance_id = var.jenkins_instance_id
}

# Data source: VPC (existente)
data "aws_vpc" "jenkins_vpc" {
  id = var.vpc_id
}
