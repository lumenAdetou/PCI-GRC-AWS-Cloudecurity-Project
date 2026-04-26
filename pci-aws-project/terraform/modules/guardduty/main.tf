variable "env" {}
variable "project" {}
variable "kms_key_arn" {}

# PCI DSS Req 5 & 11 — threat detection and vulnerability management

resource "aws_guardduty_detector" "main" {
  enable = true

  datasources {
    s3_logs { enable = true }
    kubernetes {
      audit_logs { enable = true }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes { enable = true }
      }
    }
  }

  tags = {
    Name        = "${var.project}-${var.env}-guardduty"
    Environment = var.env
    Compliance  = "PCI-DSS-v4"
  }
}

# SNS topic for GuardDuty findings alerts
resource "aws_sns_topic" "guardduty_alerts" {
  name              = "${var.project}-${var.env}-guardduty-alerts"
  kms_master_key_id = var.kms_key_arn
  tags              = { Compliance = "PCI-DSS-v4" }
}

# EventBridge rule to forward HIGH/CRITICAL findings to SNS
resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "${var.project}-${var.env}-guardduty-findings"
  description = "Capture GuardDuty HIGH and CRITICAL findings"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 7] }]
    }
  })
}

resource "aws_cloudwatch_event_target" "guardduty_sns" {
  rule      = aws_cloudwatch_event_rule.guardduty_findings.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.guardduty_alerts.arn
}

output "detector_id"        { value = aws_guardduty_detector.main.id }
output "alerts_topic_arn"   { value = aws_sns_topic.guardduty_alerts.arn }
