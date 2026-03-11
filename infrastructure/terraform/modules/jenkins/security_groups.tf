# =========================================
# Security Groups for Jenkins + ALB
# =========================================

# =========================================
# Security Group: Jenkins Private (Internal)
# =========================================
# Controla acceso a la EC2 Jenkins privada
# Solo permite tráfico desde ALB
resource "aws_security_group" "jenkins_internal" {
  name_prefix = "jenkins-internal-"
  description = "Security group for Jenkins private EC2 - ingress only from ALB"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.project_name}-jenkins-sg"
      Component = "security-group"
      Tier      = "Private"
    }
  )
}

# Jenkins SSH Access (para administración)
resource "aws_security_group_rule" "jenkins_ssh_admin" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.allow_ssh_from_cidrs
  security_group_id = aws_security_group.jenkins_internal.id
  description       = "SSH access from admin IPs (restrict in production)"
}

# Jenkins HTTP (8080) - SOLO desde ALB
resource "aws_security_group_rule" "jenkins_http_from_alb" {
  type                     = "ingress"
  from_port                = var.jenkins_port
  to_port                  = var.jenkins_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.jenkins_internal.id
  source_security_group_id = aws_security_group.alb_external.id
  description              = "HTTP access to Jenkins from ALB only"
}

# =========================================
# Security Group: ALB External (Public)
# =========================================
# Controla acceso público al ALB
# Permite tráfico desde internet, GitHub webhooks
resource "aws_security_group" "alb_external" {
  name_prefix = "jenkins-alb-"
  description = "Security group for Jenkins ALB - public-facing"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.project_name}-alb-sg"
      Component = "security-group"
      Tier      = "Public"
    }
  )
}

# ALB HTTP (80) - Acceso público
resource "aws_security_group_rule" "alb_http_from_public" {
  type              = "ingress"
  from_port         = var.alb_port
  to_port           = var.alb_port
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb_external.id
  description       = "HTTP access from internet to ALB"
}

# ALB HTTPS (443) - Acceso público
resource "aws_security_group_rule" "alb_https_from_public" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb_external.id
  description       = "HTTPS access from internet to ALB"
}

# GitHub Webhook IPs - Acceso al ALB
resource "aws_security_group_rule" "alb_github_webhooks_ips" {
  type              = "ingress"
  from_port         = var.alb_port
  to_port           = var.alb_port
  protocol          = "tcp"
  cidr_blocks       = ["140.82.112.0/20", "143.55.64.0/20"] # Official GitHub IP ranges
  security_group_id = aws_security_group.alb_external.id
  description       = "GitHub webhook delivery IPs"
}
