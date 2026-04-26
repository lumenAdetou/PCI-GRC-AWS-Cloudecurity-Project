variable "env" {}
variable "project" {}
variable "scope" { default = "REGIONAL" }

# PCI DSS Req 6.4 — web application firewall

resource "aws_wafv2_web_acl" "main" {
  name        = "${var.project}-${var.env}-waf"
  scope       = var.scope
  description = "PCI DSS compliant WAF for ${var.project} ${var.env}"

  default_action { allow {} }

  # AWS managed — common exploits (SQLi, XSS, etc.)
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1
    override_action { none {} }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project}-${var.env}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  # AWS managed — known bad inputs
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2
    override_action { none {} }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project}-${var.env}-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # AWS managed — SQL injection
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 3
    override_action { none {} }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project}-${var.env}-sqli"
      sampled_requests_enabled   = true
    }
  }

  # Rate limiting — PCI DSS Req 6.4
  rule {
    name     = "RateLimitRule"
    priority = 4
    action { block {} }
    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project}-${var.env}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project}-${var.env}-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Environment = var.env
    Compliance  = "PCI-DSS-v4"
  }
}

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  resource_arn            = aws_wafv2_web_acl.main.arn
}

resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${var.project}-${var.env}"
  retention_in_days = 365
}

output "web_acl_arn" { value = aws_wafv2_web_acl.main.arn }
output "web_acl_id"  { value = aws_wafv2_web_acl.main.id }
