# modules/presentation/main.tf

# ------------------------------------------------------------------------------
# ALB SECURITY GROUP
# ------------------------------------------------------------------------------
resource "aws_security_group" "alb_sg" {
  name        = "${var.environment}-alb-sg"
  description = "Allow inbound HTTP/HTTPS traffic from the internet"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic to target groups"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-alb-sg"
  }
}

# ------------------------------------------------------------------------------
# APPLICATION LOAD BALANCER
# ------------------------------------------------------------------------------
resource "aws_lb" "portfolio_alb" {
  name               = "${var.environment}-portfolio-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnets

  enable_deletion_protection = false

  tags = {
    Name = "${var.environment}-portfolio-alb"
  }
}

# ------------------------------------------------------------------------------
# ACM CERTIFICATE & ROUTE 53 VALIDATION
# ------------------------------------------------------------------------------
data "aws_route53_zone" "portfolio" {
  name         = var.domain_name
  private_zone = false
}

resource "aws_acm_certificate" "portfolio_cert" {
  domain_name       = var.domain_name
  validation_method = "DNS"
  
  subject_alternative_names = ["www.${var.domain_name}"]

  tags = {
    Name = "${var.environment}-portfolio-cert"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.portfolio_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.portfolio.zone_id
}

resource "aws_acm_certificate_validation" "portfolio_cert" {
  certificate_arn         = aws_acm_certificate.portfolio_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# ------------------------------------------------------------------------------
# TARGET GROUP & LISTENERS
# ------------------------------------------------------------------------------
resource "aws_lb_target_group" "portfolio_tg" {
  name     = "${var.environment}-portfolio-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.portfolio_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.portfolio_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06" 
  certificate_arn   = aws_acm_certificate_validation.portfolio_cert.certificate_arn 

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.portfolio_tg.arn
  }
}

# ------------------------------------------------------------------------------
# AWS WAFv2 (Web Application Firewall)
# ------------------------------------------------------------------------------
resource "aws_wafv2_web_acl" "portfolio_waf" {
  name        = "${var.environment}-portfolio-waf"
  description = "WAF for the Portfolio ALB"
  scope       = "REGIONAL" 

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "portfolioWafMetric"
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_association" "waf_alb_assoc" {
  resource_arn = aws_lb.portfolio_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.portfolio_waf.arn
}