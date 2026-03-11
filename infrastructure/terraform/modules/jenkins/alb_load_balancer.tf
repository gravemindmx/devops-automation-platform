# =========================================
# Application Load Balancer (ALB) para Jenkins
# =========================================
# Sirve como frontend público a Jenkins privada
# - ALB (en subnets públicas)
# - Target Group (apunta a Jenkins privada)
# - Listeners (HTTP en puerto 80)
# - Health Checks (Jenkins /login endpoint)

resource "aws_lb" "jenkins_public_alb" {
  count              = var.enable_load_balancer ? 1 : 0
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_external.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection       = false
  enable_http2                     = true
  enable_cross_zone_load_balancing = true

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.project_name}-alb"
      Component = "load-balancer"
    }
  )
}

# =========================================
# Target Group
# =========================================

resource "aws_lb_target_group" "jenkins_targets" {
  count       = var.enable_load_balancer ? 1 : 0
  name_prefix = "jen-"
  port        = var.jenkins_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
    path                = "/login"
    matcher             = "200,401,403"
    port                = var.jenkins_port
  }

  deregistration_delay = 30

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.project_name}-jenkins-tg"
      Component = "target-group"
    }
  )
}

# =========================================
# Target Group Attachment (Jenkins EC2)
# =========================================

resource "aws_lb_target_group_attachment" "jenkins_instance" {
  count            = var.enable_load_balancer ? 1 : 0
  target_group_arn = aws_lb_target_group.jenkins_targets[0].arn
  target_id        = data.aws_instance.jenkins_main.id
  port             = var.jenkins_port
}

# =========================================
# ALB Listeners
# =========================================

# Listener HTTP (puerto 80 público)
resource "aws_lb_listener" "jenkins_http_public" {
  count             = var.enable_load_balancer ? 1 : 0
  load_balancer_arn = aws_lb.jenkins_public_alb[0].arn
  port              = var.alb_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins_targets[0].arn
  }

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.project_name}-listener-http"
      Component = "listener"
    }
  )
}

# =========================================
# HTTPS Support (Optional/Future)
# =========================================

# Uncomment para HTTPS si tienes certificado ACM
/*
resource "aws_lb_listener" "jenkins_https_public" {
  count              = var.enable_load_balancer && var.enable_https ? 1 : 0
  load_balancer_arn  = aws_lb.jenkins_public_alb[0].arn
  port               = 443
  protocol           = "HTTPS"
  ssl_policy         = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn    = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins_targets[0].arn
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-listener-https"
      Component = "listener"
    }
  )
}

# HTTP to HTTPS Redirect
resource "aws_lb_listener" "jenkins_http_redirect_to_https" {
  count             = var.enable_load_balancer && var.enable_https ? 1 : 0
  load_balancer_arn = aws_lb.jenkins_public_alb[0].arn
  port              = var.alb_port
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-http-redirect"
      Component = "listener"
    }
  )
}
*/
