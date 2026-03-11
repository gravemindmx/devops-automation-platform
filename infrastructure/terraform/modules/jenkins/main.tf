# =========================================
# Jenkins Module - Main
# =========================================
# Gestiona infraestructura Jenkins en AWS:
# - EC2 instance reference (existente)
# - Application Load Balancer (ALB)
# - Security Groups (ALB + Jenkins)
# - IAM roles y policies
# - Data sources para obtener recursos existentes
#
# Archivos:
# - main.tf (este archivo)
# - variables.tf (input variables)
# - outputs.tf (outputs para integración)
# - iam.tf (IAM roles y policies)
# - alb_load_balancer.tf (ALB, target groups, listeners)
# - security_groups.tf (security groups para ALB y Jenkins)
# - data_sources.tf (data sources para recursos existentes)
