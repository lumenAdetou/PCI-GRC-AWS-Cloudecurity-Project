variable "env" {}
variable "project" {}

# PCI DSS Req 6 & 12 — compliance visibility dashboard

resource "aws_securityhub_account" "main" {}

# Enable PCI DSS v3.2.1 standard
resource "aws_securityhub_standards_subscription" "pci_dss" {
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/pci-dss/v/3.2.1"
  depends_on    = [aws_securityhub_account.main]
}

# Enable AWS Foundational Security Best Practices
resource "aws_securityhub_standards_subscription" "fsbp" {
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"
  depends_on    = [aws_securityhub_account.main]
}

# Enable CIS AWS Foundations Benchmark
resource "aws_securityhub_standards_subscription" "cis" {
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/cis-aws-foundations-benchmark/v/1.4.0"
  depends_on    = [aws_securityhub_account.main]
}

# GuardDuty integration
resource "aws_securityhub_product_subscription" "guardduty" {
  product_arn = "arn:aws:securityhub:${data.aws_region.current.name}::product/aws/guardduty"
  depends_on  = [aws_securityhub_account.main]
}

data "aws_region" "current" {}

output "securityhub_enabled" { value = true }
